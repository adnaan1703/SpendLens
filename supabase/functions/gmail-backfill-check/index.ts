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
    const staleBefore = new Date(Date.now() - 24 * 60 * 60 * 1000)
      .toISOString();
    const today = new Date().toISOString().slice(0, 10);
    const serviceClient = createServiceClient();

    const { data: mailboxes, error: mailboxError } = await serviceClient
      .from("linked_mailboxes")
      .select("id, household_id, last_sync_at")
      .eq("provider", "gmail")
      .eq("is_active", true)
      .or(`last_sync_at.is.null,last_sync_at.lt.${staleBefore}`)
      .limit(limit);

    if (mailboxError) {
      throw mailboxError;
    }

    const queued: string[] = [];
    const skipped: string[] = [];

    for (const mailbox of mailboxes ?? []) {
      const idempotencyKey = `daily-backfill:${today}`;
      const { error } = await serviceClient.from("ingestion_jobs").insert({
        household_id: mailbox.household_id,
        linked_mailbox_id: mailbox.id,
        job_type: "gmail_backfill",
        idempotency_key: idempotencyKey,
        payload: {
          reason: "daily_backfill_check",
          date: today,
        },
      });

      if (error?.code === "23505") {
        skipped.push(mailbox.id);
      } else if (error) {
        throw error;
      } else {
        queued.push(mailbox.id);
      }
    }

    logOperationalEvent("gmail_backfill_check_completed", {
      limit,
      staleMailboxCount: mailboxes?.length ?? 0,
      queued: queued.length,
      skipped: skipped.length,
    });
    return jsonResponse({ queued, skipped });
  } catch (error) {
    logOperationalEvent(
      "gmail_backfill_check_failed",
      { error: errorMessage(error, "Unable to enqueue Gmail backfill.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to enqueue Gmail backfill."),
      400,
    );
  }
});
