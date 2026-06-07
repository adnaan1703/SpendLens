import {
  GoogleApiError,
  refreshAccessToken,
  stopGmailMailbox,
} from "../_shared/google.ts";
import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";
import { createServiceClient, requireUser } from "../_shared/supabase.ts";

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    const { userClient } = await requireUser(req);
    const body = await readJsonBody(req);
    const mailboxId = String(body.mailbox_id ?? body.mailboxId ?? "").trim();

    if (!mailboxId) {
      return errorResponse("mailbox_id is required.", 400);
    }

    const { data: mailbox, error: mailboxError } = await userClient
      .from("v_linked_mailbox_status")
      .select("id, email, is_active")
      .eq("id", mailboxId)
      .maybeSingle();

    if (mailboxError || !mailbox) {
      return errorResponse(
        "Mailbox is not accessible to the signed-in user.",
        403,
      );
    }

    const serviceClient = createServiceClient();
    let stopWarning: string | null = null;

    try {
      const { data: refreshToken, error: tokenError } = await serviceClient.rpc(
        "get_gmail_refresh_token",
        { p_mailbox_id: mailboxId },
      );

      if (!tokenError && refreshToken) {
        const token = await refreshAccessToken(String(refreshToken));
        await stopGmailMailbox(token.access_token);
      }
    } catch (error) {
      if (
        error instanceof GoogleApiError &&
        [400, 401, 403].includes(error.status)
      ) {
        stopWarning =
          "Google token was already revoked or unavailable; local connector was disconnected.";
      } else {
        stopWarning = error instanceof Error
          ? error.message
          : "Unable to stop Gmail watch remotely.";
      }
    }

    const { data, error } = await serviceClient.rpc(
      "disconnect_gmail_mailbox",
      {
        p_mailbox_id: mailboxId,
      },
    );

    if (error) {
      throw error;
    }

    logOperationalEvent("gmail_disconnect_completed", {
      mailboxId,
      hadStopWarning: stopWarning !== null,
    }, stopWarning === null ? "info" : "warn");
    return jsonResponse({ mailbox: data?.[0] ?? null, warning: stopWarning });
  } catch (error) {
    logOperationalEvent(
      "gmail_disconnect_failed",
      { error: errorMessage(error, "Unable to disconnect Gmail.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to disconnect Gmail."),
      400,
    );
  }
});
