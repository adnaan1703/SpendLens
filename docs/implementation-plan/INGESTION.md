# SpendLens Ingestion Design

## Goals

Ingestion must reliably convert historical workbook data and future Gmail
transaction emails into normalized transactions. It must be idempotent,
auditable, privacy-conscious, compatible with future merchant enrichment, and
after Milestones 52-55 must honor owner-created transaction deletion
tombstones.

## Source Types

### Workbook

Historical source:

- `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`

Workbook sheets used:

- `Transactions`: canonical transaction import.
- `Merchant Summary`: initial merchant and category mapping.
- `Category Summary`: validation and seed categories.
- `Monthly`: monthly validation.
- `Cardholders`: source account/cardholder seed data.
- `Needs Review`: initial review queue.
- `Validation`: statement reconciliation checks.
- `Sources & Notes`: merchant source URLs and assumptions.

### Gmail

Ongoing source:

- Credit-card transaction emails.
- UPI transaction emails.
- Future bank/wallet alerts.

Gmail ingestion uses:

- Gmail API read access.
- Gmail `watch`.
- Google Cloud Pub/Sub push subscription.
- Supabase Edge Function webhook.
- Scheduled watch renewal and periodic backfill.

## Workbook Import Contract

### Import Steps

1. Create an `import_batches` row with `source_type = 'workbook'`.
2. Read workbook sheets.
3. Seed categories and subcategories.
4. Seed merchants and merchant aliases from `Merchant Summary` and `Transactions`.
5. Create source accounts/cardholders from `Cardholders` and transaction rows.
6. Upsert transactions from `Transactions`.
7. Create review items from `Needs Review` and low-confidence transaction rows.
8. Validate transaction counts and totals.
9. Mark import batch completed only when validation passes.

### Required Validation

The importer must validate:

- Transaction count equals workbook `Transactions` data row count.
- Gross spend total matches workbook summary.
- Refund total matches workbook summary.
- Net expenditure total matches workbook summary.
- Monthly net totals match `Monthly`.
- Category net totals match `Category Summary`.
- Merchant net totals match `Merchant Summary`.
- Card bill payments remain excluded from net expense.

In the completed M52-M55 transaction deletion flow, validation must subtract
any workbook rows suppressed by
`deleted_transaction_sources` tombstones before comparing database totals. A
tombstoned source row is intentionally absent, not an import failure.

Milestone 75 added the backend Regex Backend Migration guardrails and the
read-only `classify_statement_merchant(...)` contract. Milestone 76 made the
workbook importer call that backend helper for merchant mapping rules instead
of evaluating exact, contains, prefix, suffix, or regex patterns in JavaScript.
Workbook parsing, deterministic fingerprints, tombstone suppression, upserts,
and validation totals remain importer responsibilities.

Milestones 82-85 plan the `Payments/Credits (not expense)` category semantics
as a database-owned invariant rather than workbook-only importer logic. After
M83 completes, any transaction stored with that exact household category name
should be forced to `bill_payment_credit` money shape by Postgres regardless of
whether it came from workbook, Gmail, manual metadata correction, or future
import paths. Until M83-M85 complete, this behavior remains planned only.

### Expected Initial Workbook Facts

Current workbook facts to use in tests:

- FY: 2025-04-01 through 2026-03-31.
- Uploaded transaction date range ends on 2026-03-23.
- Transactions analysed: 475.
- Net expenditure after refunds: 1,522,388.23.
- Gross spends/debits: 1,548,630.69.
- Refunds/merchant reversals: 26,242.46.
- Card bill payments/credits: 1,349,006.00.

If the workbook changes, update these expected values in the importer fixture tests.

## Gmail Ingestion Contract

### OAuth Setup

Gmail access is connected separately from app login.

Required behavior:

- User starts "Connect Gmail" from Settings.
- Edge Function creates OAuth authorization URL.
- User grants Gmail read access.
- OAuth callback exchanges code for tokens.
- Refresh token is stored securely.
- `linked_mailboxes` row stores Gmail email, history ID, watch expiry, watched
  Gmail label id/name, and status.

Prefer the narrowest Gmail scope that supports reading transaction emails.
Milestones 66-69 keep Gmail OAuth at
`https://www.googleapis.com/auth/gmail.readonly`.

### Watch Setup

After OAuth:

1. Resolve the exact Gmail label `Banking/HDFC Transactions`.
2. Call Gmail `watch` with that label id and `labelFilterBehavior: "include"`.
3. Store the resolved label id/name, returned `history_id`, and watch
   expiration.
4. Schedule daily renewal.

Gmail watches must be renewed at least every 7 days. Use a daily scheduled function to renew active watches.

Do not silently fall back to `INBOX` when the watched label is missing.

### Pub/Sub Webhook

Webhook responsibilities:

- Accept Google Pub/Sub push messages.
- Validate message shape and optional verification headers/config.
- Decode message data.
- Find matching `linked_mailboxes` row.
- Persist the latest incoming Gmail `historyId`.
- Enqueue a sync job.
- Return HTTP 200 quickly so Pub/Sub can acknowledge.

The webhook should not do full email parsing inline.

### Sync Job

Sync job responsibilities:

1. Load mailbox connector and stored Gmail history ID.
2. Call Gmail `history.list` for the stored watched label id.
3. Fetch candidate message metadata from `messagesAdded` and `labelsAdded`, and
   expand each candidate Gmail thread.
4. Keep only messages that still carry the watched label.
5. Run body-first parser templates for supported transaction candidates.
6. Store a `gmail_parse_attempts` row for parsed, parse-failed, and
   outside-date-range candidates.
7. Generate a transaction fingerprint for parsed in-range transactions.
8. Upsert transaction idempotently.
9. Store `transaction_sources` metadata.
10. Apply merchant rules.
11. Create review items for low-confidence or unknown mappings.
12. Advance stored Gmail history ID after successful processing.

Milestone 66 completed the readonly label watch/backfill portion of this flow:
label resolution, watched-label storage, label-filtered watch/history/backfill
requests, and thread-message filtering. Milestone 67 completed body-first
parser routing, HDFC Netbanking IMPS parsing, IMPS source-reference
fingerprinting, and sanitized `other` parse-attempt rows for unmatched
watched-label mail. Milestone 68 added household-wide Review `Ignore for now`
for visible sanitized parse failures while preserving service-only diagnostics.
Milestone 71 added backend/repository pagination for unignored parse failures
and an authenticated row-scoped plain-text body fetch for one visible failure
row, fetched from Gmail without storing the body. Milestone 72 added visible
Review pagination, `Load more`/retry states, `View email`, and the transient
plain-text body dialog. Milestone 73 verified the completed workflow and folded
the final privacy/backfill behavior into durable docs.

### Backfill

Backfill is required because Gmail push notifications can be delayed or missed.

Backfill behavior:

- Scheduled function checks active mailboxes daily.
- If no sync has happened recently, enqueue a sync/backfill job.
- Initial connector setup may run a bounded backfill over recent emails.
- Large historical backfill should be explicit and progress-tracked.
- Label-based backfill must search the watched Gmail label id plus date bounds,
  including archived/non-Inbox mail, instead of sender-only candidate queries.
- Messages skipped before the watched-label parse-failure contract was in place
  will not appear in Review until a sync/backfill reprocesses the relevant
  Gmail window and records `gmail_parse_attempts` rows.

## Parser Contract

Each parser should expose:

- `parser_name`
- `parser_version`
- `candidate_type`
- `parse(messageMetadata, bodyText)`

For Milestones 66-69, the watched Gmail label identifies candidate mail and
body regex templates choose the parser. Sender and subject remain diagnostics;
they must not be required for parser routing.

Parser output:

- `transaction_date`
- `transaction_time`
- `amount`
- `currency_code`
- `statement_merchant`
- `transaction_type`
- `source_account_hint`
- `source_reference`
- `confidence`
- `diagnostics`

Parser rules:

- Return structured data only.
- Do not write to the database directly.
- Include diagnostics for failed or partial parses.
- Store parse-attempt diagnostics through the sync worker, not inside parser
  functions.
- Avoid retaining body text.
- Add fixture tests for every supported email template.
- Try supported body parsers in deterministic order and accept the first
  successful parse.
- Treat unmatched watched-label mail as a sanitized parse failure with
  `candidate_type` `other`.
- Supported Gmail source/candidate types are `credit_card`, `upi`, and
  `netbanking_imps`; unmatched watched-label mail uses candidate type `other`.

HDFC body templates and planned expansion:

- Credit-card debit from existing HDFC credit-card body fixtures.
- UPI debit from existing HDFC Bank UPI body fixtures.
- Netbanking IMPS debit was implemented in Milestone 67 from the sample
  `Netbanking :: IMPS` body format.

## Supported Parser Order

Implement parsers in this order:

1. HDFC credit-card transaction email parser. Implemented for debit alerts.
2. HDFC credit-card refund/reversal parser. Pending matching fixtures.
3. UPI debit parser from user-provided anonymized samples. Implemented for HDFC Bank UPI debit alerts.
4. HDFC Netbanking IMPS debit parser. Implemented in Milestone 67.
5. UPI credit/refund parser from user-provided anonymized samples. Pending matching fixtures.
6. Other banks/cards only after fixtures are provided.

## Deduplication

Every parsed transaction must produce `source_fingerprint`.

Recommended fingerprint inputs:

- `household_id`
- source account hint or mailbox ID
- transaction date
- transaction time when present
- amount
- normalized merchant text
- source reference when present
- source message ID when needed

Use `(household_id, source_fingerprint)` as the primary duplicate guard.

Ingestion must also check `deleted_transaction_sources` before inserting or
updating a transaction. A matching tombstone means the source was intentionally
deleted by the household owner and must be treated as suppressed handled work:

- Do not insert or update `transactions`.
- Do not recreate `transaction_sources`.
- Do not recreate transaction-scoped `review_items`.
- Preserve sanitized service diagnostics where the source path already records
  them, especially `gmail_parse_attempts`.
- Do not store raw email bodies or full transaction payloads in tombstones or
  suppression diagnostics.

When duplicates are plausible but not certain:

- Do not silently merge unrelated rows.
- Create a `review_items` row with duplicate-conflict reason.

## Merchant Mapping Pipeline

For each imported transaction:

1. Normalize statement merchant.
2. Attempt exact alias match.
3. Attempt manual mapping rule match.
4. Attempt seeded merchant rule match.
5. If matched, assign merchant, category, subcategory, and confidence.
6. If unknown or low confidence, create review item.

When the user corrects a mapping:

- Create a manual mapping rule.
- Apply it to future transactions.
- Reclassify matching historical transactions.
- Resolve related review items.

Milestones 74-77 made backend rule matching authoritative for both Gmail and
workbook import. Gmail calls `match_merchant_mapping_rule(...)` during
transaction insertion, while workbook import calls
`classify_statement_merchant(...)` after deterministic seed data exists. Exact,
prefix, suffix, contains, and regex precedence, normalized non-regex matching,
stored-pattern regex evaluation, and invalid-regex fail-closed behavior now live
in Postgres for both ingestion paths. Milestone 77 verified the focused local
regression path; hosted rollout remains a separate explicit operation.

The planned M82-M85 bill-payment category semantics sit after merchant/category
classification. They should not change rule matching confidence, create or
resolve Review rows, or alter Gmail parse-failure handling; they only normalize
the persisted transaction type and money columns for the exact
`Payments/Credits (not expense)` category.

## Privacy Rules

- Do not store raw email bodies by default.
- Store Gmail message ID, thread ID, received timestamp, parser name/version, parse status, and short diagnostics.
- Store service-only `gmail_parse_attempts` rows for supported Gmail candidates
  even when body parsing fails. Milestones 66-69 extend this to unsupported
  watched-label mail as sanitized parse failures.
- M71-M73 body viewing must fetch the current plain-text Gmail body on demand
  for one authorized visible parse failure only. Do not include body text in
  list responses, diagnostics, logs, or persisted tables.
- Log parser failures without sensitive full message content.
- Do not expose mailbox tokens to clients.
- Delete or rotate OAuth credentials when a mailbox is disconnected.

## Failure Handling

Use explicit statuses:

- `queued`
- `processing`
- `completed`
- `failed`
- `cancelled`

Retryable failures:

- Gmail rate limit.
- Transient network error.
- Pub/Sub duplicate delivery.
- Temporary Supabase function error.

Non-retryable failures:

- Revoked Gmail token.
- Invalid parser fixture.
- Unsupported email template.
- Missing household membership.

Failed jobs should keep enough diagnostics for debugging but not raw message content.
