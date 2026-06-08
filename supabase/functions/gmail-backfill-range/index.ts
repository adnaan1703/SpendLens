import {
  errorResponse,
  handleOptions,
  jsonResponse,
  readJsonBody,
} from "../_shared/http.ts";
import {
  addDays,
  buildDateSlices,
  parseBoundedInteger,
} from "../_shared/gmail_range.ts";
import {
  createServiceClient,
  requireServiceRequest,
} from "../_shared/supabase.ts";
import { errorMessage, logOperationalEvent } from "../_shared/observability.ts";

type MailboxRow = {
  id: string;
  household_id: string;
  has_oauth_secret: boolean;
};

type ExistingJobRow = {
  id: string;
  status: string;
};

type QueueResult = {
  sliceStartDate: string;
  sliceEndDateExclusive: string;
  jobId: string | null;
  status: "queued" | "requeued" | "skipped";
  existingStatus?: string;
};

function requiredString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${key} is required.`);
  }

  return value.trim();
}

async function queueSlice(
  serviceClient: ReturnType<typeof createServiceClient>,
  mailbox: MailboxRow,
  sliceStartDate: string,
  sliceEndDateExclusive: string,
  maxCandidates: number,
  requestedAt: string,
): Promise<QueueResult> {
  const idempotencyKey =
    `manual-range:${sliceStartDate}:${sliceEndDateExclusive}`;
  const payload = {
    reason: "manual_range_backfill",
    requestedAt,
    transactionStartDate: sliceStartDate,
    transactionEndDateExclusive: sliceEndDateExclusive,
    gmailSearchStartDate: addDays(sliceStartDate, -1),
    gmailSearchEndDateExclusive: addDays(sliceEndDateExclusive, 1),
    maxCandidates,
  };

  const { data: inserted, error } = await serviceClient
    .from("ingestion_jobs")
    .insert({
      household_id: mailbox.household_id,
      linked_mailbox_id: mailbox.id,
      job_type: "gmail_backfill",
      idempotency_key: idempotencyKey,
      payload,
    })
    .select("id")
    .single();

  if (!error) {
    return {
      sliceStartDate,
      sliceEndDateExclusive,
      jobId: inserted.id,
      status: "queued",
    };
  }

  if (error.code !== "23505") {
    throw error;
  }

  const { data: existing, error: existingError } = await serviceClient
    .from("ingestion_jobs")
    .select("id, status")
    .eq("linked_mailbox_id", mailbox.id)
    .eq("job_type", "gmail_backfill")
    .eq("idempotency_key", idempotencyKey)
    .maybeSingle();

  if (existingError || !existing) {
    throw existingError ?? new Error("Existing backfill job was not found.");
  }

  const existingJob = existing as ExistingJobRow;
  if (
    existingJob.status === "completed" || existingJob.status === "processing"
  ) {
    return {
      sliceStartDate,
      sliceEndDateExclusive,
      jobId: existingJob.id,
      status: "skipped",
      existingStatus: existingJob.status,
    };
  }

  const { error: updateError } = await serviceClient
    .from("ingestion_jobs")
    .update({
      status: "queued",
      attempts: 0,
      run_after: new Date().toISOString(),
      started_at: null,
      completed_at: null,
      error_message: null,
      payload,
    })
    .eq("id", existingJob.id);

  if (updateError) {
    throw updateError;
  }

  return {
    sliceStartDate,
    sliceEndDateExclusive,
    jobId: existingJob.id,
    status: "requeued",
    existingStatus: existingJob.status,
  };
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    requireServiceRequest(req);
    const body = await readJsonBody(req);
    const mailboxId = requiredString(body, "mailboxId");
    const transactionStartDate = requiredString(body, "transactionStartDate");
    const transactionEndDateExclusive = requiredString(
      body,
      "transactionEndDateExclusive",
    );
    const sliceDays = parseBoundedInteger(body.sliceDays, "sliceDays", {
      defaultValue: 1,
      min: 1,
      max: 31,
    });
    const maxCandidatesPerSlice = parseBoundedInteger(
      body.maxCandidatesPerSlice,
      "maxCandidatesPerSlice",
      { defaultValue: 200, min: 1, max: 500 },
    );
    const slices = buildDateSlices(
      transactionStartDate,
      transactionEndDateExclusive,
      sliceDays,
    );

    if (slices.length > 366) {
      throw new Error("Backfill range cannot create more than 366 slices.");
    }

    const serviceClient = createServiceClient();
    const { data: mailbox, error: mailboxError } = await serviceClient
      .from("linked_mailboxes")
      .select("id, household_id, has_oauth_secret")
      .eq("id", mailboxId)
      .eq("provider", "gmail")
      .eq("is_active", true)
      .maybeSingle();

    if (mailboxError || !mailbox) {
      throw mailboxError ?? new Error("Active Gmail mailbox was not found.");
    }

    const activeMailbox = mailbox as MailboxRow;
    if (!activeMailbox.has_oauth_secret) {
      throw new Error("Active Gmail mailbox is missing its OAuth secret.");
    }

    const requestedAt = new Date().toISOString();
    const results: QueueResult[] = [];
    for (const slice of slices) {
      results.push(
        await queueSlice(
          serviceClient,
          activeMailbox,
          slice.startDate,
          slice.endDateExclusive,
          maxCandidatesPerSlice,
          requestedAt,
        ),
      );
    }

    const queued = results.filter((result) => result.status === "queued");
    const requeued = results.filter((result) => result.status === "requeued");
    const skipped = results.filter((result) => result.status === "skipped");
    logOperationalEvent("gmail_backfill_range_completed", {
      mailboxId,
      transactionStartDate,
      transactionEndDateExclusive,
      sliceDays,
      maxCandidatesPerSlice,
      queued: queued.length,
      requeued: requeued.length,
      skipped: skipped.length,
    });

    return jsonResponse({
      mailboxId,
      transactionStartDate,
      transactionEndDateExclusive,
      sliceDays,
      maxCandidatesPerSlice,
      queued,
      requeued,
      skipped,
    });
  } catch (error) {
    logOperationalEvent(
      "gmail_backfill_range_failed",
      { error: errorMessage(error, "Unable to queue Gmail range backfill.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to queue Gmail range backfill."),
      400,
    );
  }
});
