# SpendLens Ingestion Design

## Goals

Ingestion must reliably convert historical workbook data and future Gmail transaction emails into normalized transactions. It must be idempotent, auditable, privacy-conscious, and compatible with future merchant enrichment.

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
- `linked_mailboxes` row stores Gmail email, history ID, watch expiry, and status.

Prefer the narrowest Gmail scope that supports reading transaction emails.

### Watch Setup

After OAuth:

1. Call Gmail `watch`.
2. Store returned `history_id`.
3. Store watch expiration.
4. Schedule daily renewal.

Gmail watches must be renewed at least every 7 days. Use a daily scheduled function to renew active watches.

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
2. Call Gmail `history.list`.
3. Fetch candidate message metadata and expand each candidate Gmail thread.
4. Filter by supported senders, labels, and transaction-like content.
5. Run parser registry.
6. Generate a transaction fingerprint.
7. Upsert transaction idempotently.
8. Store `transaction_sources` metadata.
9. Apply merchant rules.
10. Create review items for low-confidence or unknown mappings.
11. Advance stored Gmail history ID after successful processing.

### Backfill

Backfill is required because Gmail push notifications can be delayed or missed.

Backfill behavior:

- Scheduled function checks active mailboxes daily.
- If no sync has happened recently, enqueue a sync/backfill job.
- Initial connector setup may run a bounded backfill over recent emails.
- Large historical backfill should be explicit and progress-tracked.

## Parser Contract

Each parser should expose:

- `parser_name`
- `parser_version`
- `matches(messageMetadata, bodyText)`
- `parse(messageMetadata, bodyText)`

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
- Avoid retaining body text.
- Add fixture tests for every supported email template.

## Supported Parser Order

Implement parsers in this order:

1. HDFC credit-card transaction email parser. Implemented for debit alerts.
2. HDFC credit-card refund/reversal parser. Pending matching fixtures.
3. UPI debit parser from user-provided anonymized samples. Implemented for HDFC Bank UPI debit alerts.
4. UPI credit/refund parser from user-provided anonymized samples. Pending matching fixtures.
5. Other banks/cards only after fixtures are provided.

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

## Privacy Rules

- Do not store raw email bodies by default.
- Store Gmail message ID, thread ID, received timestamp, parser name/version, parse status, and short diagnostics.
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
