import { refreshAccessToken, watchGmailMailbox } from "../_shared/google.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import {
  createServiceClient,
  requireServiceRequest,
} from "../_shared/supabase.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    requireServiceRequest(req);
    const body = await readJsonBody(req);
    const limit = Math.min(Math.max(Number(body.limit ?? 20), 1), 50);
    const threshold = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000)
      .toISOString();
    const serviceClient = createServiceClient();

    const { data: mailboxes, error: mailboxError } = await serviceClient
      .from("linked_mailboxes")
      .select("id, watch_expires_at")
      .eq("provider", "gmail")
      .eq("is_active", true)
      .or(`watch_expires_at.is.null,watch_expires_at.lt.${threshold}`)
      .limit(limit);

    if (mailboxError) {
      throw mailboxError;
    }

    const renewed: unknown[] = [];
    const failed: unknown[] = [];

    for (const mailbox of mailboxes ?? []) {
      try {
        const { data: refreshToken, error: tokenError } = await serviceClient
          .rpc(
            "get_gmail_refresh_token",
            { p_mailbox_id: mailbox.id },
          );
        if (tokenError || !refreshToken) {
          throw tokenError ?? new Error("Gmail refresh token unavailable.");
        }

        const token = await refreshAccessToken(String(refreshToken));
        const watch = await watchGmailMailbox(token.access_token);
        await serviceClient
          .from("linked_mailboxes")
          .update({
            gmail_history_id: watch.historyId,
            watch_expires_at: watch.expirationDate ?? null,
            last_watch_renewed_at: new Date().toISOString(),
            last_error: null,
          })
          .eq("id", mailbox.id);
        renewed.push({
          mailboxId: mailbox.id,
          watchExpiresAt: watch.expirationDate,
        });
      } catch (error) {
        const message = errorMessage(
          error,
          "Unknown Gmail watch renewal error.",
        );
        await serviceClient.rpc("mark_gmail_mailbox_error", {
          p_mailbox_id: mailbox.id,
          p_error: message,
          p_status: "failed",
        });
        failed.push({ mailboxId: mailbox.id, error: message });
        logOperationalEvent(
          "gmail_watch_renewal_mailbox_failed",
          { mailboxId: mailbox.id, error: message },
          "error",
        );
      }
    }

    logOperationalEvent(
      "gmail_watch_renewal_completed",
      {
        limit,
        selectedMailboxes: mailboxes?.length ?? 0,
        renewed: renewed.length,
        failed: failed.length,
      },
      failed.length > 0 ? "warn" : "info",
    );
    return jsonResponse({ renewed, failed });
  } catch (error) {
    logOperationalEvent(
      "gmail_watch_renewal_failed",
      { error: errorMessage(error, "Unable to renew Gmail watches.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to renew Gmail watches."),
      400,
    );
  }
});
