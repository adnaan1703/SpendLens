# SpendLens Architecture

## Goal

Build a Flutter Android app backed by Supabase that can reliably collect, classify, review, and present personal and household expense data. The current client target is Android only. The architecture should leave room for later iOS, web, LLM-based expense Q&A, and merchant enrichment.

## High-Level System

```text
Flutter Android
        |
        | Supabase client SDK, authenticated user JWT
        v
Supabase Auth + Postgres + RLS
        |
        | privileged operations only
        v
Supabase Edge Functions
        |
        +--> Gmail API / Google Pub/Sub
        +--> Import parsers
        +--> Merchant reclassification
        +--> AI provider later
        +--> Firebase Cloud Messaging for Android push
        +--> External worker later, if needed
```

## Core Components

### Flutter Client

The Flutter Android app owns presentation and user workflows:

- Sign in and session handling.
- Dashboard, transaction list, trends, merchant review, budgets, and piggy banks.
- Android notification permission, FCM token registration, and notification tap
  routing after the push-notification milestones are implemented.
- Direct reads and safe writes through Supabase SDK where RLS is sufficient.
- Calls to Edge Functions for privileged operations such as Gmail OAuth, import execution, reclassification, and future AI.

The client must not:

- Store service-role keys.
- Call LLM providers directly.
- Read raw Gmail message bodies.
- Bypass backend validation for imported or classified transactions.

### Supabase Auth

Use Google sign-in for app authentication in v1. Gmail read access is requested during connector setup, not assumed merely because the user signed in.

Auth identities map to application profiles and household membership. Every user-visible finance row must be scoped through `household_id` and protected by RLS.

### Supabase Postgres

Postgres is the source of truth for:

- Transactions.
- Push device registrations and notification preferences after the
  push-notification milestones are implemented.
- Notification outbox and delivery state for transaction push notifications.
- Categories and monthly caps.
- Merchants, aliases, and mapping rules.
- Import batches and source records.
- Review queue.
- Piggy-bank accounts and ledger entries.
- AI usage and enrichment jobs later.

Use SQL views or RPCs for summary reads instead of duplicating summary state in the app.

### Row Level Security

RLS is mandatory for all app-accessible tables.

Baseline rule:

- A user may select/insert/update/delete rows only when they are an active member of the row's `household_id`.

Privileged ingestion and maintenance operations run from Edge Functions using server-side credentials. Those functions must still validate the target household explicitly.

### Edge Functions

Edge Functions are the v1 backend execution layer. Use them for:

- Gmail OAuth callback and token exchange.
- Gmail Pub/Sub webhook.
- Gmail history sync orchestration.
- Workbook import.
- Merchant rule application and reclassification.
- Scheduled watch renewal and backfill.
- Lightweight Gemini expense Q&A and transaction metadata suggestion calls.
- Service-key protected push notification dispatch to FCM.

Edge Functions should stay short, idempotent, and request-oriented. They should enqueue work when the operation may be slow or retried.

### Queues and Jobs

Use Supabase Queues if available in the project, otherwise use a normal `jobs` table with status fields.

Use queued jobs for:

- Email sync from Gmail history IDs.
- Workbook import batches.
- Merchant reclassification across historical transactions.
- Future async AI suggestion work if synchronous Edge Functions become too slow.
- Future expense Q&A audit logging and async answers.
- Transaction notification outbox dispatch and retry state.

### Dedicated Worker Escape Hatch

Do not start with a full backend server. Add a dedicated worker only when needed for:

- Long-running LLM jobs.
- Heavy web-search based merchant enrichment.
- Large batch embedding generation.
- High-volume email parsing.
- Workflows that exceed Edge Function runtime or memory limits.

The worker should consume jobs from Supabase and write results back to Postgres. The Flutter app should continue calling the same app-level functions/RPCs so the worker can be introduced without changing product workflows.

## Data Flows

### Historical Workbook Import

1. User triggers an import or an admin import script runs.
2. Importer reads `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`.
3. Importer creates an `import_batches` row.
4. Workbook rows are transformed into normalized transactions, merchants, categories, and review items.
5. Importer validates totals against workbook summary and validation sheets.
6. Import batch is marked `completed` only if validation passes.

### Gmail Transaction Ingestion

1. User connects Gmail and grants read-only transaction email access.
2. Backend stores OAuth refresh token securely.
3. Backend calls Gmail `watch` for the mailbox and stores the returned `history_id` and expiration.
4. Gmail sends mailbox-change notifications to Google Cloud Pub/Sub.
5. Pub/Sub calls a Supabase webhook.
6. Webhook validates the request, records the latest history ID, and enqueues a sync job.
7. Sync job calls Gmail `history.list`, fetches candidate messages, parses supported templates, and upserts transactions idempotently.
8. Low-confidence or unknown merchant/category mappings create `review_items`.

### Merchant Review

1. User opens the review queue.
2. User corrects merchant group, category, and subcategory.
3. Backend creates or updates a merchant mapping rule.
4. Matching past transactions are reclassified.
5. Future imports apply the same rule automatically.
6. Reclassified rows preserve audit metadata.

### Category Caps

1. User sets monthly cap per category.
2. Dashboard reads budget progress from a SQL view.
3. Refunds reduce net spend.
4. Card bill payments are excluded from spend.
5. Over-budget state is derived from net spend greater than cap.

### Piggy Banks

1. User creates a piggy bank with target amount and optional target date.
2. User records deposits, withdrawals, or adjustments.
3. Balance is ledger-derived, not editable directly.
4. Entries may optionally link to real transactions.

### Transaction Deletion (M52 completed, M53-M55 planned)

1. A household owner deletes a faulty transaction from Activity.
2. Postgres records a minimal source tombstone keyed by household and
   source fingerprint.
3. The transaction row is hard-deleted, which removes its contribution from
   summary views, merchant summaries, trends, labels, review, and monthly cap
   progress.
4. Ledger and diagnostic rows that should survive deletion are preserved but
   unlinked.
5. Workbook and Gmail ingestion check tombstones before transaction upsert so
   reprocessing the same source does not recreate the deleted transaction.

Milestone 52 completed the Postgres deletion contract, tombstone table, trigger,
owner-only direct delete policy, and `delete_transaction` RPC. Milestone 53
still needs to wire workbook and Gmail ingestion to consult tombstones before
upsert; Milestone 54 still owns the Activity UI.

### LLM Q&A

1. User asks a question in the app.
2. Client calls an Edge Function.
3. Function validates membership and checks household AI budget settings.
4. Function retrieves only scoped, relevant finance data through safe SQL views.
5. Function calls Gemini through a backend-only API key.
6. Answer, citations/queries, token usage, and cost estimate are stored.
7. Client displays the answer.

For heavier work, the Edge Function creates an `ai_jobs` row and returns job status. A worker processes the job asynchronously.

### Transaction Push Notifications

1. The Android app asks for notification permission from Settings, obtains an
   FCM registration token, and registers the current app installation against
   the signed-in profile and household through an RLS-safe Supabase RPC.
2. The user can enable/disable transaction push notifications and choose whether
   merchant/amount details are shown in notification text. The default is to
   show full details.
3. Gmail sync and future batch processors collect only newly inserted
   transaction ids and enqueue one `transaction_batch` notification outbox row
   per completed processing batch.
4. Duplicate Gmail reprocessing does not enqueue a second notification because
   ingestion already reports `inserted = false` for existing
   `(household_id, source_fingerprint)` rows.
5. A service-key protected Edge Function claims queued outbox rows, fans out to
   active Android device tokens for eligible household members, sends through
   FCM HTTP v1, records per-device delivery state, and deactivates invalid
   tokens.
6. The app handles notification taps by opening Transactions and refreshing
   household finance providers. Exact transaction-detail deep links are deferred.

## Security Invariants

- Never put service-role keys in Flutter.
- Never put FCM service account JSON or Firebase private keys in Flutter.
- Never let the client call Gmail or LLM provider secrets directly.
- Never retain raw email bodies by default.
- Store Gmail tokens encrypted or in a protected secrets mechanism.
- Enforce RLS on every exposed table.
- Use `household_id` on every finance row.
- Record import and AI usage audit events.
- Record push notification queue and delivery state without logging raw FCM
  tokens.
- Deduplicate incoming transactions before inserting.
- Treat all email parser output as untrusted until validated.

## Financial Semantics

- `amount` is the signed source amount when available.
- `gross_spend` is positive purchase/debit amount.
- `refund_amount` is positive refund/reversal amount.
- `net_expense = gross_spend - refund_amount`.
- Card bill payments and account credits are not expenses and have `net_expense = 0`.
- Category summaries, budgets, and trends use `net_expense`.

## Mobile Deployment

- Android builds use the Supabase project with Android-specific OAuth client IDs.
- Use separate Supabase projects for staging and production once production data exists.

## Deferred iOS App

The iOS app is not part of the current implementation plan. When it is resumed later, it should reuse the same Supabase backend, RLS policies, summary views, Edge Functions, merchant rules, and ingestion pipeline. Do not add Xcode, CocoaPods, Apple Developer, iOS bundle identifier, iOS OAuth client, or iOS build requirements to current milestones unless the user explicitly reactivates iOS work.

## Deferred Web Interface

The web interface is not part of the current implementation plan. When it is resumed later, it should reuse the same Supabase backend, RLS policies, summary views, Edge Functions, merchant rules, and ingestion pipeline. Do not add web hosting, web OAuth clients, or web-specific UI requirements to current milestones unless the user explicitly reactivates web work.

## Cost Controls

Edge Function invocations are expected to be low for personal/household usage. The larger future cost risk is AI token usage and web search.

Required controls:

- Log every Edge Function category in operational logs.
- Log every AI call in `ai_usage_events`.
- Enforce monthly AI budget caps before model calls.
- Use deterministic merchant rules before LLM enrichment.
- Only run Suggest web search after the household flag is explicitly enabled.
- Keep Gmail sync idempotent to avoid retry loops and duplicate work.
- After Milestones 52-55, treat tombstoned source fingerprints as suppressed
  handled work so owner-deleted transactions do not reappear after retries.
- Keep push delivery asynchronous so FCM outages do not block ingestion.

## Architecture References

- Supabase Edge Functions: https://supabase.com/docs/guides/functions
- Supabase Edge Function pricing: https://supabase.com/docs/guides/functions/pricing
- Supabase RLS: https://supabase.com/docs/learn/auth-deep-dive/auth-row-level-security
- Supabase Vault: https://supabase.com/docs/guides/database/vault/
- Supabase Queues: https://supabase.com/docs/guides/queues/quickstart
- Gmail push notifications: https://developers.google.com/workspace/gmail/api/guides/push
- Google Pub/Sub pricing: https://cloud.google.com/pubsub/pricing
- Firebase Cloud Messaging for Flutter: https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- Firebase Cloud Messaging HTTP v1: https://firebase.google.com/docs/cloud-messaging/send/v1-api
