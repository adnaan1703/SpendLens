import { sha256Hex } from "../_shared/crypto.ts";
import {
  fetchGmailMessage,
  fetchGmailThread,
  type GmailMessageListOptions,
  type GmailMessageSummary,
  GoogleApiError,
  listGmailHistory,
  listRecentGmailMessages,
  refreshAccessToken,
} from "../_shared/google.ts";
import {
  compareIsoDates,
  isDateWithinRange,
  optionalIsoDate,
  parseBoundedInteger,
} from "../_shared/gmail_range.ts";
import { extractPlainText, messageMetadata } from "../_shared/gmail_message.ts";
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
import {
  normalizeFingerprintText,
  parseGmailTransaction,
} from "../_shared/parsers/gmail_parsers.mjs";

type JobRow = {
  id: string;
  household_id: string;
  linked_mailbox_id: string;
  job_type: "gmail_sync" | "gmail_backfill";
  attempts: number;
  max_attempts: number;
  payload: Record<string, unknown>;
};

type MailboxRow = {
  id: string;
  household_id: string;
  email: string;
  gmail_history_id?: string | null;
};

type ProcessCounts = {
  fetched: number;
  parsed: number;
  unsupported: number;
  outsideDateRange: number;
  inserted: number;
  updated: number;
  reviewItems: number;
};

type BackfillOptions = GmailMessageListOptions & {
  maxCandidates: number;
  transactionStartDate: string | null;
  transactionEndDateExclusive: string | null;
};

type GmailMessageCandidate = {
  messageId: string;
  threadId: string | null;
};

function emptyCounts(): ProcessCounts {
  return {
    fetched: 0,
    parsed: 0,
    unsupported: 0,
    outsideDateRange: 0,
    inserted: 0,
    updated: 0,
    reviewItems: 0,
  };
}

function mergeCounts(
  target: ProcessCounts,
  next: Partial<ProcessCounts>,
): void {
  for (const key of Object.keys(next) as Array<keyof ProcessCounts>) {
    target[key] += next[key] ?? 0;
  }
}

function addCandidate(
  candidates: Map<string, GmailMessageCandidate>,
  message: GmailMessageSummary | undefined,
): void {
  const messageId = message?.id?.trim();
  if (!messageId) {
    return;
  }

  const threadId = message?.threadId?.trim() || null;
  const existing = candidates.get(messageId);
  candidates.set(messageId, {
    messageId,
    threadId: existing?.threadId ?? threadId,
  });
}

async function collectHistoryMessageCandidates(
  accessToken: string,
  startHistoryId: string,
): Promise<{
  candidates: GmailMessageCandidate[];
  latestHistoryId?: string;
}> {
  const candidates = new Map<string, GmailMessageCandidate>();
  let pageToken: string | undefined;
  let latestHistoryId: string | undefined;

  do {
    const page = await listGmailHistory(accessToken, startHistoryId, pageToken);
    latestHistoryId = page.historyId ?? latestHistoryId;
    for (const history of page.history ?? []) {
      for (const added of history.messagesAdded ?? []) {
        addCandidate(candidates, added.message);
      }
    }
    pageToken = page.nextPageToken;
  } while (pageToken && candidates.size < 50);

  return { candidates: [...candidates.values()].slice(0, 50), latestHistoryId };
}

async function collectBackfillMessageCandidates(
  accessToken: string,
  options: BackfillOptions,
): Promise<GmailMessageCandidate[]> {
  const candidates = new Map<string, GmailMessageCandidate>();
  let pageToken: string | undefined;
  const maxCandidates = options.maxCandidates;

  do {
    const page = await listRecentGmailMessages(accessToken, pageToken, {
      query: options.query,
      searchStartDate: options.searchStartDate,
      searchEndDateExclusive: options.searchEndDateExclusive,
      maxResults: Math.min(100, maxCandidates - candidates.size),
    });
    for (const message of page.messages ?? []) {
      addCandidate(candidates, message);
    }
    pageToken = page.nextPageToken;
  } while (pageToken && candidates.size < maxCandidates);

  return [...candidates.values()].slice(0, maxCandidates);
}

function sourceFingerprint(
  householdId: string,
  mailboxId: string,
  messageId: string,
  parsed: Record<string, unknown>,
): Promise<string> {
  const sourceHint = parsed.source_account_hint as
    | Record<string, unknown>
    | undefined;
  const sourceReference = String(parsed.source_reference ?? "").trim();

  if (sourceHint?.type === "upi" && sourceReference) {
    return sha256Hex([
      householdId,
      mailboxId,
      "upi",
      String(sourceHint.masked_identifier ?? ""),
      sourceReference,
    ].join("|"));
  }

  const amount = Number(parsed.amount ?? 0).toFixed(2);
  return sha256Hex([
    householdId,
    mailboxId,
    String(parsed.transaction_date ?? ""),
    String(parsed.transaction_time ?? ""),
    amount,
    normalizeFingerprintText(parsed.statement_merchant),
    String(parsed.source_reference ?? messageId),
  ].join("|"));
}

async function processMessage(
  serviceClient: ReturnType<typeof createServiceClient>,
  mailbox: MailboxRow,
  message: Record<string, unknown>,
  messageId: string,
  dateFilter: Pick<
    BackfillOptions,
    "transactionStartDate" | "transactionEndDateExclusive"
  >,
): Promise<Partial<ProcessCounts>> {
  const metadata = messageMetadata(message);
  const bodyText = extractPlainText(message);
  const parsed = parseGmailTransaction(metadata, bodyText);

  if (!parsed.ok) {
    return { fetched: 1, unsupported: 1 };
  }

  if (
    (dateFilter.transactionStartDate ||
      dateFilter.transactionEndDateExclusive) &&
    !isDateWithinRange(
      parsed.transaction_date,
      dateFilter.transactionStartDate,
      dateFilter.transactionEndDateExclusive,
    )
  ) {
    return { fetched: 1, parsed: 1, outsideDateRange: 1 };
  }

  const fingerprint = await sourceFingerprint(
    mailbox.household_id,
    mailbox.id,
    messageId,
    parsed,
  );
  const { data, error } = await serviceClient.rpc("ingest_gmail_transaction", {
    p_mailbox_id: mailbox.id,
    p_message_metadata: metadata,
    p_parsed_transaction: parsed,
    p_source_fingerprint: fingerprint,
  });

  if (error) {
    throw error;
  }

  const result = Array.isArray(data) ? data[0] : data;
  return {
    fetched: 1,
    parsed: 1,
    inserted: result?.inserted ? 1 : 0,
    updated: result?.inserted ? 0 : 1,
    reviewItems: result?.review_item_id ? 1 : 0,
  };
}

async function processMessageById(
  serviceClient: ReturnType<typeof createServiceClient>,
  mailbox: MailboxRow,
  accessToken: string,
  messageId: string,
  processedMessageIds: Set<string>,
  dateFilter: Pick<
    BackfillOptions,
    "transactionStartDate" | "transactionEndDateExclusive"
  >,
): Promise<Partial<ProcessCounts>> {
  if (processedMessageIds.has(messageId)) {
    return {};
  }

  const message = await fetchGmailMessage(accessToken, messageId);
  const metadata = messageMetadata(message);
  const fetchedMessageId = String(metadata.id ?? messageId);
  processedMessageIds.add(fetchedMessageId);

  return processMessage(
    serviceClient,
    mailbox,
    message,
    fetchedMessageId,
    dateFilter,
  );
}

async function processThread(
  serviceClient: ReturnType<typeof createServiceClient>,
  mailbox: MailboxRow,
  accessToken: string,
  threadId: string,
  processedMessageIds: Set<string>,
  dateFilter: Pick<
    BackfillOptions,
    "transactionStartDate" | "transactionEndDateExclusive"
  >,
): Promise<Partial<ProcessCounts>> {
  const thread = await fetchGmailThread(accessToken, threadId);
  const counts = emptyCounts();
  for (const message of thread.messages ?? []) {
    const metadata = messageMetadata(message);
    const messageId = String(metadata.id ?? "").trim();
    if (!messageId || processedMessageIds.has(messageId)) {
      continue;
    }

    processedMessageIds.add(messageId);
    mergeCounts(
      counts,
      await processMessage(
        serviceClient,
        mailbox,
        message,
        messageId,
        dateFilter,
      ),
    );
  }

  return counts;
}

function stringPayloadValue(
  payload: Record<string, unknown>,
  key: string,
): string | null {
  const value = payload[key];
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}

function backfillOptionsFromPayload(
  payload: Record<string, unknown>,
): BackfillOptions {
  const transactionStartDate = optionalIsoDate(
    payload.transactionStartDate,
    "transactionStartDate",
  );
  const transactionEndDateExclusive = optionalIsoDate(
    payload.transactionEndDateExclusive,
    "transactionEndDateExclusive",
  );

  if (
    transactionStartDate && transactionEndDateExclusive &&
    compareIsoDates(transactionStartDate, transactionEndDateExclusive) >= 0
  ) {
    throw new Error(
      "transactionStartDate must be before transactionEndDateExclusive.",
    );
  }

  return {
    query: stringPayloadValue(payload, "gmailSearchQuery") ??
      stringPayloadValue(payload, "query") ??
      undefined,
    searchStartDate: optionalIsoDate(
      payload.gmailSearchStartDate ?? payload.searchStartDate,
      "gmailSearchStartDate",
    ),
    searchEndDateExclusive: optionalIsoDate(
      payload.gmailSearchEndDateExclusive ?? payload.searchEndDateExclusive,
      "gmailSearchEndDateExclusive",
    ),
    maxCandidates: parseBoundedInteger(
      payload.maxCandidates ?? payload.maxCandidatesPerSlice,
      "maxCandidates",
      { defaultValue: 50, min: 1, max: 500 },
    ),
    transactionStartDate,
    transactionEndDateExclusive,
  };
}

async function processJob(
  serviceClient: ReturnType<typeof createServiceClient>,
  job: JobRow,
): Promise<
  { jobId: string; counts: ProcessCounts; fallbackBackfill: boolean }
> {
  const { data: mailbox, error: mailboxError } = await serviceClient
    .from("linked_mailboxes")
    .select("id, household_id, email, gmail_history_id")
    .eq("id", job.linked_mailbox_id)
    .eq("is_active", true)
    .maybeSingle();

  if (mailboxError || !mailbox) {
    throw new Error("Active mailbox for Gmail job was not found.");
  }

  const { data: refreshToken, error: tokenError } = await serviceClient.rpc(
    "get_gmail_refresh_token",
    { p_mailbox_id: mailbox.id },
  );
  if (tokenError || !refreshToken) {
    throw tokenError ?? new Error("Gmail refresh token unavailable.");
  }

  const token = await refreshAccessToken(String(refreshToken));
  const counts = emptyCounts();
  const startHistoryId = String(
    job.payload?.startHistoryId ?? mailbox.gmail_history_id ?? "",
  );
  const notificationHistoryId = String(
    job.payload?.notificationHistoryId ?? "",
  );
  let latestHistoryId: string | undefined;
  let fallbackBackfill = false;
  let candidates: GmailMessageCandidate[] = [];
  const defaultBackfillOptions = backfillOptionsFromPayload({});
  const backfillOptions = job.job_type === "gmail_backfill"
    ? backfillOptionsFromPayload(job.payload ?? {})
    : defaultBackfillOptions;
  const dateFilter = job.job_type === "gmail_backfill"
    ? {
      transactionStartDate: backfillOptions.transactionStartDate,
      transactionEndDateExclusive: backfillOptions.transactionEndDateExclusive,
    }
    : {
      transactionStartDate: null,
      transactionEndDateExclusive: null,
    };

  try {
    if (job.job_type === "gmail_sync" && startHistoryId) {
      const history = await collectHistoryMessageCandidates(
        token.access_token,
        startHistoryId,
      );
      candidates = history.candidates;
      latestHistoryId = notificationHistoryId || history.latestHistoryId;
    } else {
      candidates = await collectBackfillMessageCandidates(
        token.access_token,
        backfillOptions,
      );
    }
  } catch (error) {
    if (error instanceof GoogleApiError && error.status === 404) {
      fallbackBackfill = true;
      candidates = await collectBackfillMessageCandidates(
        token.access_token,
        backfillOptions,
      );
    } else {
      throw error;
    }
  }

  const processedThreadIds = new Set<string>();
  const processedMessageIds = new Set<string>();
  for (const candidate of candidates) {
    if (candidate.threadId && !processedThreadIds.has(candidate.threadId)) {
      processedThreadIds.add(candidate.threadId);
      mergeCounts(
        counts,
        await processThread(
          serviceClient,
          mailbox,
          token.access_token,
          candidate.threadId,
          processedMessageIds,
          dateFilter,
        ),
      );
      if (!processedMessageIds.has(candidate.messageId)) {
        mergeCounts(
          counts,
          await processMessageById(
            serviceClient,
            mailbox,
            token.access_token,
            candidate.messageId,
            processedMessageIds,
            dateFilter,
          ),
        );
      }
      continue;
    }

    mergeCounts(
      counts,
      await processMessageById(
        serviceClient,
        mailbox,
        token.access_token,
        candidate.messageId,
        processedMessageIds,
        dateFilter,
      ),
    );
  }

  const mailboxPatch: Record<string, unknown> = {
    last_sync_at: new Date().toISOString(),
    last_sync_status: "completed",
    last_error: null,
  };

  if (latestHistoryId) {
    mailboxPatch.gmail_history_id = latestHistoryId;
  }

  await serviceClient
    .from("linked_mailboxes")
    .update(mailboxPatch)
    .eq("id", mailbox.id);

  return { jobId: job.id, counts, fallbackBackfill };
}

Deno.serve(async (req: Request) => {
  const options = handleOptions(req);
  if (options) return options;

  try {
    requireServiceRequest(req);
    const body = await readJsonBody(req);
    const limit = Math.min(Math.max(Number(body.limit ?? 5), 1), 20);
    const serviceClient = createServiceClient();

    const { data: jobs, error: jobsError } = await serviceClient
      .from("ingestion_jobs")
      .select(
        "id, household_id, linked_mailbox_id, job_type, attempts, max_attempts, payload",
      )
      .in("job_type", ["gmail_sync", "gmail_backfill"])
      .eq("status", "queued")
      .lte("run_after", new Date().toISOString())
      .order("priority", { ascending: true })
      .order("created_at", { ascending: true })
      .limit(limit);

    if (jobsError) {
      throw jobsError;
    }

    const completed: unknown[] = [];
    const failed: unknown[] = [];

    for (const job of (jobs ?? []) as JobRow[]) {
      const startedAt = new Date().toISOString();
      await serviceClient
        .from("ingestion_jobs")
        .update({
          status: "processing",
          attempts: job.attempts + 1,
          started_at: startedAt,
          error_message: null,
        })
        .eq("id", job.id);

      await serviceClient
        .from("linked_mailboxes")
        .update({
          last_sync_started_at: startedAt,
          last_sync_status: "processing",
          last_error: null,
        })
        .eq("id", job.linked_mailbox_id);

      try {
        const result = await processJob(serviceClient, job);
        completed.push(result);
        logOperationalEvent("gmail_sync_job_completed", {
          jobId: job.id,
          mailboxId: job.linked_mailbox_id,
          jobType: job.job_type,
          fallbackBackfill: result.fallbackBackfill,
          counts: result.counts,
        });
        await serviceClient
          .from("ingestion_jobs")
          .update({
            status: "completed",
            completed_at: new Date().toISOString(),
            payload: {
              ...job.payload,
              result,
            },
          })
          .eq("id", job.id);
      } catch (error) {
        const message = errorMessage(error, "Unknown Gmail sync error.");
        const attempts = job.attempts + 1;
        const finalAttempt = attempts >= job.max_attempts;
        failed.push({ jobId: job.id, error: message });
        logOperationalEvent(
          "gmail_sync_job_failed",
          {
            jobId: job.id,
            mailboxId: job.linked_mailbox_id,
            jobType: job.job_type,
            attempts,
            maxAttempts: job.max_attempts,
            finalAttempt,
            error: message,
          },
          finalAttempt ? "error" : "warn",
        );
        await serviceClient
          .from("ingestion_jobs")
          .update({
            status: finalAttempt ? "failed" : "queued",
            completed_at: finalAttempt ? new Date().toISOString() : null,
            error_message: message,
            run_after: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
          })
          .eq("id", job.id);
        await serviceClient.rpc("mark_gmail_mailbox_error", {
          p_mailbox_id: job.linked_mailbox_id,
          p_error: message,
          p_status: "failed",
        });
      }
    }

    logOperationalEvent(
      "gmail_sync_run_completed",
      {
        limit,
        selectedJobs: jobs?.length ?? 0,
        completed: completed.length,
        failed: failed.length,
      },
      failed.length > 0 ? "warn" : "info",
    );
    return jsonResponse({ completed, failed });
  } catch (error) {
    logOperationalEvent(
      "gmail_sync_run_failed",
      { error: errorMessage(error, "Unable to run Gmail sync.") },
      "error",
    );
    return errorResponse(
      errorMessage(error, "Unable to run Gmail sync."),
      400,
    );
  }
});
