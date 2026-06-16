import { sha256Hex } from "../_shared/crypto.ts";
import {
  exchangeCodeForTokens,
  fetchGmailProfile,
  resolveWatchedGmailLabel,
  tokenExpiryTimestamp,
  watchGmailMailbox,
} from "../_shared/google.ts";
import { handleOptions, htmlResponse } from "../_shared/http.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";
import { createServiceClient } from "../_shared/supabase.ts";

function page(title: string, message: string): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <style>
      body { font-family: system-ui, sans-serif; margin: 32px; line-height: 1.5; }
      main { max-width: 640px; }
    </style>
  </head>
  <body>
    <main>
      <h1>${title}</h1>
      <p>${message}</p>
    </main>
  </body>
</html>`;
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  const url = new URL(req.url);
  const code = url.searchParams.get("code") ?? "";
  const state = url.searchParams.get("state") ?? "";
  const oauthError = url.searchParams.get("error");

  if (oauthError) {
    logOperationalEvent(
      "gmail_oauth_callback_cancelled",
      { error: oauthError },
      "warn",
    );
    return htmlResponse(page("Gmail connection cancelled", oauthError), 400);
  }

  if (!code || !state) {
    logOperationalEvent(
      "gmail_oauth_callback_failed",
      { error: "Missing OAuth code or state." },
      "warn",
    );
    return htmlResponse(
      page("Gmail connection failed", "Missing OAuth code or state."),
      400,
    );
  }

  const serviceClient = createServiceClient();

  try {
    const stateHash = await sha256Hex(state);
    const { data: stateRow, error: stateError } = await serviceClient
      .from("gmail_oauth_states")
      .select("id, household_id, profile_id, expires_at, consumed_at")
      .eq("state_hash", stateHash)
      .is("consumed_at", null)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();

    if (stateError || !stateRow) {
      logOperationalEvent(
        "gmail_oauth_callback_failed",
        { error: "OAuth state expired or invalid." },
        "warn",
      );
      return htmlResponse(
        page("Gmail connection failed", "OAuth state expired or invalid."),
        400,
      );
    }

    const { error: consumeError } = await serviceClient
      .from("gmail_oauth_states")
      .update({ consumed_at: new Date().toISOString() })
      .eq("id", stateRow.id);

    if (consumeError) {
      throw consumeError;
    }

    const tokens = await exchangeCodeForTokens(code);
    const profile = await fetchGmailProfile(tokens.access_token);
    const watchedLabel = await resolveWatchedGmailLabel(tokens.access_token);
    const watchedLabelResolvedAt = new Date().toISOString();
    const watch = await watchGmailMailbox(
      tokens.access_token,
      watchedLabel.id,
    );

    const { data: mailboxData, error: mailboxError } = await serviceClient.rpc(
      "upsert_gmail_mailbox",
      {
        p_household_id: stateRow.household_id,
        p_profile_id: stateRow.profile_id,
        p_email: profile.emailAddress,
        p_refresh_token: tokens.refresh_token ?? null,
        p_provider_subject: profile.emailAddress,
        p_scope: tokens.scope ?? null,
        p_gmail_history_id: watch.historyId,
        p_watch_expires_at: watch.expirationDate ?? null,
        p_token_expires_at: tokenExpiryTimestamp(tokens.expires_in),
        p_watched_gmail_label_id: watchedLabel.id,
        p_watched_gmail_label_name: watchedLabel.name,
        p_watched_gmail_label_resolved_at: watchedLabelResolvedAt,
      },
    );

    if (mailboxError) {
      throw mailboxError;
    }

    const mailbox = Array.isArray(mailboxData) ? mailboxData[0] : mailboxData;
    logOperationalEvent("gmail_oauth_callback_completed", {
      mailboxId: mailbox?.id,
      householdId: stateRow.household_id,
      watchedGmailLabelId: watchedLabel.id,
      watchedGmailLabelName: watchedLabel.name,
      watchExpiresAt: watch.expirationDate ?? null,
      scope: tokens.scope ?? null,
    });
    return htmlResponse(page(
      "Gmail connected",
      "SpendLens can now ingest supported transaction emails from this mailbox. You can return to the app.",
    ));
  } catch (error) {
    const message = errorMessage(error, "Unknown Gmail OAuth callback error.");
    logOperationalEvent(
      "gmail_oauth_callback_failed",
      { error: message },
      "error",
    );
    return htmlResponse(page("Gmail connection failed", message), 400);
  }
});
