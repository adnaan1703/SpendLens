import { buildGmailIngestOutcome } from "../gmail-sync/index.ts";

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
