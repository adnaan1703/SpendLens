import {
  buildGmailIngestOutcome,
  collectBackfillMessageCandidates,
  collectHistoryMessageCandidates,
  messageHasGmailLabel,
  sourceFingerprint,
} from "../gmail-sync/index.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

Deno.test("Gmail sync treats tombstone suppression as handled work", () => {
  const outcome = buildGmailIngestOutcome(
    {
      gmail_transaction_id: null,
      inserted: false,
      review_item_id: null,
      matched_mapping: false,
      suppressed: true,
      suppression_reason: "deleted_transaction_source",
    },
    {
      ok: true,
      candidate_type: "credit_card",
      parser_name: "hdfc_credit_card_debit",
      parser_version: "1.0.0",
      diagnostics: { template: "hdfc_credit_card_debit_v1" },
    },
    "fingerprint-1",
  );

  assert(outcome.suppressed, "Suppressed result should be marked suppressed.");
  assert(
    outcome.transactionId === null,
    "Suppressed parse attempt should not link a transaction.",
  );
  assert(
    outcome.counts.suppressed === 1,
    "Suppressed result should increment suppressed count.",
  );
  assert(
    outcome.counts.inserted === 0,
    "Suppressed result should not count as inserted.",
  );
  assert(
    outcome.counts.updated === 0,
    "Suppressed result should not count as updated.",
  );
  assert(
    outcome.counts.reviewItems === 0,
    "Suppressed result should not count review work.",
  );

  const diagnostics = outcome.parsedRecord.diagnostics as Record<
    string,
    unknown
  >;
  assert(
    diagnostics.source_suppressed_by_deletion === true,
    "Parse diagnostics should record safe suppression state.",
  );
  assert(
    diagnostics.suppression_reason === "deleted_transaction_source",
    "Parse diagnostics should record the sanitized suppression reason.",
  );
  assert(
    diagnostics.source_fingerprint === "fingerprint-1",
    "Parse diagnostics should include the source fingerprint used for suppression.",
  );
});

Deno.test("Gmail sync keeps normal ingest count semantics", () => {
  const outcome = buildGmailIngestOutcome(
    {
      gmail_transaction_id: "txn-1",
      inserted: true,
      review_item_id: "review-1",
      matched_mapping: false,
      suppressed: false,
      suppression_reason: null,
    },
    {
      ok: true,
      candidate_type: "upi",
      parser_name: "hdfc_upi_debit",
      parser_version: "1.0.0",
      diagnostics: { template: "hdfc_upi_debit_v1" },
    },
    "fingerprint-2",
  );

  assert(!outcome.suppressed, "Inserted result should not be suppressed.");
  assert(
    outcome.transactionId === "txn-1",
    "Inserted parse attempt should link the transaction.",
  );
  assert(
    outcome.counts.inserted === 1,
    "Inserted result should increment inserted count.",
  );
  assert(
    outcome.counts.updated === 0,
    "Inserted result should not increment updated count.",
  );
  assert(
    outcome.counts.suppressed === 0,
    "Inserted result should not increment suppressed count.",
  );
  assert(
    outcome.counts.reviewItems === 1,
    "Inserted result should keep review item count.",
  );
});

Deno.test("Gmail sync fingerprints IMPS by source account and reference", async () => {
  const first = await sourceFingerprint(
    "household-1",
    "mailbox-1",
    "gmail-message-1",
    {
      source_reference: "616734130236",
      source_account_hint: {
        type: "netbanking_imps",
        masked_identifier: "0932",
      },
    },
  );
  const duplicateMessage = await sourceFingerprint(
    "household-1",
    "mailbox-1",
    "gmail-message-2",
    {
      source_reference: "616734130236",
      source_account_hint: {
        type: "netbanking_imps",
        masked_identifier: "0932",
      },
    },
  );
  const otherAccount = await sourceFingerprint(
    "household-1",
    "mailbox-1",
    "gmail-message-3",
    {
      source_reference: "616734130236",
      source_account_hint: {
        type: "netbanking_imps",
        masked_identifier: "9999",
      },
    },
  );

  assert(
    first === duplicateMessage,
    "IMPS duplicate messages should fingerprint by reference and source account.",
  );
  assert(
    first !== otherAccount,
    "IMPS source account identity should remain part of the fingerprint.",
  );
});

Deno.test("Gmail history candidates include watched-label message and label additions", async () => {
  const originalFetch = globalThis.fetch;
  const requestedUrls: URL[] = [];

  globalThis.fetch = ((input: string | URL | Request) => {
    requestedUrls.push(new URL(input.toString()));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          historyId: "latest-history",
          history: [
            {
              messagesAdded: [{ message: { id: "m1", threadId: "t1" } }],
              labelsAdded: [
                {
                  message: { id: "m2", threadId: "t2" },
                  labelIds: ["Label_123"],
                },
                {
                  message: { id: "m3", threadId: "t3" },
                  labelIds: ["Other_Label"],
                },
              ],
            },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const result = await collectHistoryMessageCandidates(
      "access-token",
      "start-history",
      "Label_123",
    );

    assert(
      result.latestHistoryId === "latest-history",
      "Latest history id should be returned.",
    );
    assert(
      result.candidates.length === 2,
      `Expected watched-label candidates only: ${JSON.stringify(result)}`,
    );
    assert(
      result.candidates.some((candidate) => candidate.messageId === "m1"),
      "messagesAdded candidate was missing.",
    );
    assert(
      result.candidates.some((candidate) => candidate.messageId === "m2"),
      "labelsAdded candidate was missing.",
    );
    const observedUrl = requestedUrls[0];
    if (!observedUrl) {
      throw new Error("Gmail history URL was not requested.");
    }
    assert(
      observedUrl.searchParams.get("labelId") === "Label_123",
      `History should be filtered by watched label: ${observedUrl.toString()}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("Gmail backfill candidates request the watched label and date bounds", async () => {
  const originalFetch = globalThis.fetch;
  const requestedUrls: URL[] = [];

  globalThis.fetch = ((input: string | URL | Request) => {
    requestedUrls.push(new URL(input.toString()));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          messages: [{ id: "m1", threadId: "t1" }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  }) as typeof fetch;

  try {
    const candidates = await collectBackfillMessageCandidates(
      "access-token",
      {
        searchStartDate: "2026-06-15",
        searchEndDateExclusive: "2026-06-17",
        maxCandidates: 25,
        transactionStartDate: "2026-06-16",
        transactionEndDateExclusive: "2026-06-17",
      },
      "Label_123",
    );

    assert(candidates.length === 1, "Expected one backfill candidate.");
    const observedUrl = requestedUrls[0];
    if (!observedUrl) {
      throw new Error("Gmail message list URL was not requested.");
    }
    assert(
      observedUrl.searchParams.get("labelIds") === "Label_123",
      `Backfill should be filtered by watched label: ${observedUrl.toString()}`,
    );
    const query = observedUrl.searchParams.get("q") ?? "";
    assert(
      query.includes("after:2026/06/15") &&
        query.includes("before:2026/06/17"),
      `Backfill should keep date bounds: ${query}`,
    );
    assert(
      !query.includes("from:alerts@hdfcbank.bank.in"),
      `Backfill should not use sender fallback: ${query}`,
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("Gmail sync skips thread messages without the watched label", () => {
  assert(
    messageHasGmailLabel({ labelIds: ["Label_123", "INBOX"] }, "Label_123"),
    "Message with watched label should be accepted.",
  );
  assert(
    !messageHasGmailLabel({ labelIds: ["INBOX"] }, "Label_123"),
    "Thread message without watched label should be skipped.",
  );
  assert(
    !messageHasGmailLabel({}, "Label_123"),
    "Message without label metadata should be skipped.",
  );
});
