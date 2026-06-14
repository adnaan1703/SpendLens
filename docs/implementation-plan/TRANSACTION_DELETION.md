# Transaction Deletion Plan

Last updated: 2026-06-14

This document is the implementation plan for permanent transaction deletion in
SpendLens. Each milestone below is a standalone milestone intended to be
executed in a separate Codex thread. Stop after completing and documenting the
current milestone; do not automatically continue to the next milestone.

## Target Behavior

SpendLens owners can delete a faulty transaction from Activity. Deletion is a
hard delete of the `public.transactions` row, not an archive or hidden state.
After deletion:

- The transaction disappears from Activity list/detail.
- Monthly spend, merchant spend, trends, dashboard totals, and monthly cap
  progress no longer include the transaction amount.
- Transaction labels, transaction source rows, and transaction-scoped review
  items attached to that transaction are removed.
- Piggy-bank entries and service diagnostics that reference the transaction are
  preserved but unlinked from the deleted transaction.
- A minimal source tombstone prevents the same workbook row or Gmail email from
  recreating the deleted transaction during later imports, backfills, retries, or
  sync jobs.

Deletion is owner-only in v1. Other household roles may still view transactions
according to existing RLS, but they cannot delete transactions from the app or
through the app-facing deletion contract.

## Existing Foundation

- `public.transactions` is the canonical household-scoped transaction ledger.
  It has a unique `(household_id, source_fingerprint)` guard for idempotent
  imports.
- Direct transaction references already have useful foreign-key behavior:
  `transaction_labels`, `transaction_sources`, and transaction-scoped
  `review_items` cascade on transaction deletion. `piggy_bank_entries` and
  `gmail_parse_attempts` use `on delete set null`.
- Dashboard totals, merchant summaries, Activity Charts, and recurring monthly
  cap progress are computed from `public.transactions` and related labels, so
  deleting the row naturally removes its spend contribution.
- Workbook import code lives in `tools/workbook-import/src/workbook-importer.mjs`
  and currently upserts transactions by `(household_id, source_fingerprint)`.
- Gmail transaction ingestion lives in
  `supabase/migrations/20260607131628_gmail_connector_ingestion.sql` and
  `supabase/functions/gmail-sync/index.ts`; it also upserts by
  `(household_id, source_fingerprint)` and records service diagnostics in
  `gmail_parse_attempts`.
- Activity transaction list/detail UI lives in
  `apps/mobile/lib/src/features/transactions/transactions_screen.dart`.
- Flutter finance data flows through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`; focused
  tests live in `apps/mobile/test/finance_features_test.dart`.
- The repo standard for app-facing Supabase writes is authenticated,
  household-scoped, RLS-safe `security invoker` RPCs with explicit grants and
  tests.

## Global Rules For M52-M55

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, prepare, or jump ahead to later milestones
  unless the user explicitly asks to proceed.
- Keep Milestones 18-21 deferred unless the user explicitly resumes push
  notification work.
- Preserve Android-first scope. Do not add iOS, web, hosted rollout, or push
  notification behavior in this sequence.
- Treat transaction deletion as destructive and owner-only. Do not expose it to
  admins, members, or viewers unless the user explicitly changes the access
  decision.
- Do not store raw email bodies, full transaction payloads, merchant names,
  amounts, cardholder names, notes, or parsed email body snippets in deletion
  tombstones.
- A deleted source fingerprint must not recreate a transaction from workbook
  import, Gmail sync, Gmail backfill, parser retry, or repeated source messages.
- Use `net_expense` for all spend-impact assertions. Card bill payments still
  contribute zero spend; refunds reduce spend.
- Source tombstones must be household-scoped and RLS-safe. Use explicit table
  grants and policies; do not rely on `TO authenticated` without an ownership
  predicate.
- Use `security invoker` for app-facing RPCs unless the implementation uncovers
  a concrete blocker that is documented and explicitly approved.
- Create migrations with `supabase migration new <descriptive_name>` when
  implementation starts. Do not invent migration filenames.
- Before Supabase implementation, run `supabase --version`, discover relevant
  CLI help, and scan `https://supabase.com/changelog.md` for relevant breaking
  changes.
- Add focused pgTAP, importer, Edge Function/parser, and Flutter tests in the
  same milestone as the behavior they protect.
- At completion, update `SESSION_HANDOFF.md` and include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M52 - Transaction Delete Database Contract

Purpose: create the durable database contract for owner-only hard deletion and
source tombstones before changing ingestion or Flutter UI.

Status: completed on 2026-06-14. Next recommended implementation milestone is
M53, Import Resurrection Guard.

Instructions:

- Start by reading:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/INGESTION.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `supabase/migrations/20260604203957_create_spendlens_foundation.sql`
  - `supabase/migrations/20260607131628_gmail_connector_ingestion.sql`
  - `supabase/migrations/20260608121900_gmail_parse_attempt_diagnostics.sql`
  - `supabase/migrations/20260612130532_labels_foundation.sql`
  - `supabase/migrations/20260613124104_recurring_cap_series_foundation.sql`
  - `supabase/tests/rls_isolation.sql`
  - `supabase/tests/monthly_caps.sql`
  - `supabase/tests/transaction_labels.sql`
- Run Supabase setup discovery before editing:
  - `supabase --version`
  - `supabase migration --help`
  - `supabase db --help`
  - scan `https://supabase.com/changelog.md` for relevant breaking changes.
- Add a migration created by the Supabase CLI.
- Add `public.deleted_transaction_sources`:
  - `id uuid primary key default gen_random_uuid()`
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `source_type public.source_type not null`
  - `source_fingerprint text not null`
  - `deleted_transaction_id uuid not null`
  - `source_message_id text`
  - `source_reference text`
  - `deleted_by uuid references public.profiles(id) on delete set null`
  - `deleted_at timestamptz not null default now()`
  - `reason text`
  - unique `(household_id, source_fingerprint)`
  - nonblank `source_fingerprint` check
  - nonblank `reason` check when reason is present
- Add indexes for source suppression lookups:
  - `(household_id, source_type, source_fingerprint)`
  - `(household_id, source_message_id)` where `source_message_id is not null`
- Enable RLS on `public.deleted_transaction_sources`.
- Add explicit grants and policies:
  - Household owners can select tombstones for their household.
  - Household owners can insert tombstones for their household.
  - Do not grant authenticated delete access to tombstones in this sequence.
    Restore/undo is explicitly deferred.
  - `service_role` can select tombstones for ingestion suppression.
  - Do not grant `anon` access.
- Add a transaction-delete tombstone trigger:
  - Create an `app_private` trigger function that records a tombstone before a
    `public.transactions` row is deleted.
  - Copy only minimal source identity fields from the transaction and current
    `transaction_sources` rows while they still exist.
  - Use `coalesce`/`on conflict do nothing` so repeated or retried delete paths
    do not fail once a tombstone exists.
  - Do not store amount, merchant, category, labels, notes, raw email content, or
    parsed body data.
- Tighten direct authenticated transaction deletion:
  - Replace or adjust the existing `transactions_delete_admins` policy so
    app-user transaction deletion is owner-only.
  - Keep service-role ingestion/admin maintenance unaffected.
  - Ensure any direct owner delete still records a tombstone through the trigger.
- Add `public.delete_transaction(p_household_id uuid, p_transaction_id uuid, p_reason text default null)`:
  - `security invoker` and `set search_path = ''`.
  - Requires the signed-in profile to be an owner of `p_household_id`.
  - Validates the transaction belongs to the household.
  - Counts direct associations before deletion:
    labels, transaction source rows, transaction review items, linked piggy-bank
    entries, and linked Gmail parse attempts.
  - Deletes the `public.transactions` row and relies on FK/trigger behavior for
    cascade, unlink, and tombstone recording.
  - Returns one row with the deleted transaction id, source type,
    source fingerprint, deleted label count, deleted source row count, deleted
    review item count, unlinked piggy-bank entry count, unlinked Gmail parse
    attempt count, and `deleted_at`.
  - Raises clear errors for missing transaction, cross-household transaction,
    non-owner caller, or missing signed-in profile.
- Add `supabase/tests/transaction_deletion.sql` with pgTAP coverage for:
  - Owner can delete a household transaction.
  - Admin, member, viewer, non-member, and other-household owner cannot delete.
  - The transaction row is gone.
  - Labels, transaction source rows, and transaction review items are removed.
  - Piggy-bank entries and Gmail parse attempts remain but have null transaction
    links.
  - Monthly spend, merchant summary, trend-equivalent summary views, and monthly
    cap progress no longer count the deleted transaction.
  - Tombstone is recorded with minimal source identity.
  - Direct owner delete also records a tombstone; direct non-owner delete is
    blocked by RLS.

Expected code shape:

- One migration owns schema, RLS, trigger, RPC, grants, comments, and policy
  changes for the deletion contract.
- One focused pgTAP file owns deletion behavior coverage.
- No Flutter repository, Activity UI, Gmail sync, Edge Function, or workbook
  importer changes in M52.

Acceptance criteria:

- Owner-only deletion is enforced in Postgres.
- Deleted transactions stop contributing to summary and cap reads.
- Tombstones are recorded for deleted transaction source fingerprints.
- Preserved rows are unlinked, not deleted, where the existing FK contract says
  `on delete set null`.
- Direct app-user transaction deletion cannot bypass tombstone recording.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/transaction_deletion.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --fail-on none
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added `20260614113615_transaction_delete_database_contract.sql` with
  `public.deleted_transaction_sources`, source lookup indexes, owner-only RLS,
  service-role read access, an internal delete tombstone trigger, an
  owner-only direct delete policy for authenticated users, and the app-facing
  `public.delete_transaction(...)` RPC.
- Kept the RPC `security invoker`. A small `app_private` owner-scoped helper
  counts linked `gmail_parse_attempts` without exposing the service-only
  diagnostics table to authenticated clients.
- Added `supabase/tests/transaction_deletion.sql` for owner RPC deletion,
  admin/member/viewer/non-member/other-household denial, cascade/unlink
  behavior, monthly spend/category/merchant/monthly-cap recalculation,
  minimal tombstone shape, direct owner delete trigger coverage, direct
  non-owner RLS blocking, and service-role tombstone reads.
- Updated `supabase/tests/rls_isolation.sql` so the tombstone table remains in
  the broad RLS audit.
- Verified with:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/transaction_deletion.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Deferred scope was not started: workbook importer suppression, Gmail sync
  suppression, Activity UI, restore, undo, bulk delete, push notifications,
  hosted rollout, iOS, web, M53, M54, and M55.
- Assumptions made:
  - `gmail_parse_attempts` remains service-only in M52.
  - Optional deletion reasons are app/user metadata and must not include raw
    transaction payloads or email body content.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M53 - Import Resurrection Guard

Purpose: make workbook and Gmail ingestion honor transaction deletion
tombstones so deleted transactions do not come back after source retries or
backfills.

Instructions:

- Start by reading:
  - M52 completion notes in `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `docs/implementation-plan/INGESTION.md`
  - `docs/implementation-plan/GMAIL_CONNECTOR.md`
  - `docs/implementation-plan/WORKBOOK_IMPORT.md`
  - `tools/workbook-import/src/workbook-importer.mjs`
  - `tools/workbook-import/test/workbook-fixture.test.mjs`
  - `supabase/functions/gmail-sync/index.ts`
  - `supabase/functions/tests/gmail_range.test.ts`
  - `supabase/functions/tests/gmail_message.test.ts`
  - `supabase/functions/tests/gmail_parsers.test.mjs`
  - `supabase/tests/gmail_ingestion.sql`
  - `supabase/tests/gmail_parse_failures.sql`
- Run Supabase and tooling discovery before editing:
  - `supabase --version`
  - `supabase functions --help`
  - scan `https://supabase.com/changelog.md` for relevant breaking changes.
- Update workbook import suppression:
  - Fetch tombstoned `source_fingerprint` values for the target household before
    transaction upsert.
  - Skip transaction upsert, transaction source upsert, and review item upsert
    for tombstoned workbook fingerprints.
  - Track a `suppressed_count` or similarly named value in import reporting.
  - Update validation so workbook expected totals subtract skipped tombstoned
    source rows instead of failing because the database intentionally excludes
    them.
  - Keep reruns idempotent for non-deleted rows.
- Update Gmail ingestion suppression:
  - Check `public.deleted_transaction_sources` inside the Gmail ingestion SQL
    path before inserting/upserting `public.transactions`.
  - Return a clear skipped/suppressed result shape from
    `public.ingest_gmail_transaction(...)` without creating a transaction row,
    transaction source row, or review item when the fingerprint is tombstoned.
  - Preserve or update `gmail_parse_attempts` diagnostics so operators can see
    that a parsed message was suppressed by prior user deletion.
  - Do not expose tombstone details through Flutter-facing diagnostics.
- Update `gmail-sync` result handling:
  - Treat a tombstone-suppressed parse as a successful handled message, not a
    retryable error.
  - Do not enqueue review work or create duplicate transaction source metadata
    for suppressed messages.
  - Include safe structured log metadata such as household id, mailbox id,
    source type, source message id, and suppression reason, without raw body
    content.
- Add/extend tests:
  - Workbook fixture test proves a tombstoned workbook fingerprint is skipped,
    counts as suppressed, and does not break adjusted validation totals.
  - Gmail ingestion pgTAP proves a tombstoned fingerprint returns suppressed and
    creates no transaction, transaction source, or review item.
  - Edge Function/unit tests prove `gmail-sync` treats suppression as handled.
  - Existing idempotency tests still prove non-deleted repeated imports do not
    duplicate rows.

Expected code shape:

- Workbook suppression lives near existing fingerprint/idempotency lookup code.
- Gmail suppression lives at the database ingestion boundary so all Gmail sync
  and backfill callers get the same behavior.
- Function logs and diagnostics are sanitized and household-scoped.
- No Flutter Activity delete UI in M53.

Acceptance criteria:

- Re-importing a deleted workbook source row does not recreate the transaction.
- Reprocessing a deleted Gmail transaction email does not recreate the
  transaction.
- Non-deleted source rows retain existing idempotent upsert behavior.
- Operational diagnostics show suppression without storing sensitive source
  payloads.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/transaction_deletion.sql
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase test db --local supabase/tests
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
deno test --allow-env --allow-read supabase/functions/tests
supabase db lint --local --schema app_private,public --fail-on error
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added `20260614122706_import_resurrection_guard.sql`, replacing
  `public.ingest_gmail_transaction(...)` with a tombstone-aware contract that
  checks `public.deleted_transaction_sources` before source-account,
  transaction, source metadata, or review writes. Matching Gmail fingerprints
  return `suppressed = true` and sanitized reason `deleted_transaction_source`.
- Updated `supabase/functions/gmail-sync/index.ts` so a suppressed ingestion
  result is counted as handled work, logged with household/mailbox/source-message
  metadata only, and recorded in `gmail_parse_attempts` as a parsed candidate
  with null transaction id plus sanitized suppression diagnostics.
- Updated `tools/workbook-import/src/workbook-importer.mjs` so workbook imports
  fetch tombstoned workbook fingerprints, skip transaction/source/review writes
  for matching rows, report `suppressedCount`, and validate database totals
  against the adjusted imported source set.
- Added regression coverage:
  - `tools/workbook-import/test/workbook-fixture.test.mjs`
  - `supabase/tests/gmail_ingestion.sql`
  - `supabase/functions/tests/gmail_sync.test.ts`
- Verified with:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/transaction_deletion.sql`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `deno test --allow-env --allow-read supabase/functions/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Deferred scope was not started: Flutter Activity delete UI, restore, undo,
  bulk delete, push notifications, hosted rollout, iOS, web, M54, and M55.
- Assumptions made:
  - Suppressed Gmail parses should keep the existing `parsed` parse-attempt
    status and use diagnostics for the sanitized suppression reason.
  - Workbook reference seeding can still use the full workbook; M53 suppresses
    only transaction-bearing writes.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M54 - Activity Transaction Delete UX

Purpose: expose the owner-only transaction deletion contract from Activity while
keeping the destructive action explicit and recover-free.

Instructions:

- Start by reading:
  - M52 and M53 completion notes in `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `docs/implementation-plan/UI_REDESIGN.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `apps/mobile/lib/src/features/activity/activity_screen.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/lib/src/data/repositories/household_repository.dart`
  - `apps/mobile/lib/src/shared/widgets/app_primitives.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Extend repository contracts:
  - Add `TransactionDeleteRequest`.
  - Add `TransactionDeleteResult` matching the RPC result from M52.
  - Add `Future<TransactionDeleteResult> deleteTransaction(...)` to
    `FinanceRepository`.
  - Implement the Supabase RPC call in `SupabaseFinanceRepository`.
  - Add disabled and fake repository support.
- Add owner-only delete affordance:
  - Use `HouseholdContext.memberRole == 'owner'` to decide whether the delete
    action is available.
  - Add the action to the existing transaction detail surface, visually grouped
    with other detail actions and styled as destructive.
  - Do not show delete to admins, members, viewers, or unauthenticated states.
- Add confirmation:
  - Use existing `AppModalDialog` and `AppActionPill.destructive`.
  - The copy must state that the transaction will be removed from Activity,
    monthly spend, merchant spend, trends, labels, review, and monthly caps.
  - The copy must state that linked Vault entries and service diagnostics are
    preserved but unlinked.
  - The copy must state that the source will be blocked from future workbook or
    Gmail re-import.
  - Keep the action explicit; do not add swipe-to-delete or bulk delete in M54.
- Add mutation handling:
  - Call `deleteTransaction` with the household id and selected transaction id.
  - Close the detail sheet after successful deletion.
  - Show a success snackbar.
  - Show RPC errors without losing the user's current Activity state.
  - Refresh affected providers:
    `transactionsProvider`, `dashboardSnapshotProvider`, `trendReportProvider`,
    `merchantReviewQueueProvider`, `transactionLabelsProvider`,
    `labelManagerSnapshotProvider`, `availableMonthsProvider`,
    `piggyBanksProvider`, and `piggyBankEntriesProvider`.
  - Preserve active filters and pagination unless the current page becomes
    empty; if it becomes empty and page is greater than zero, move back one page.
- Add Flutter tests:
  - Owner sees the delete action in transaction detail.
  - Admin/member/viewer contexts do not show the delete action.
  - Canceling confirmation does not call the repository.
  - Confirming calls the repository with the selected transaction id and removes
    the transaction from the Activity list.
  - Provider refresh is observable through changed dashboard/trend/list fake
    data or fake repository request counts.
  - RPC error keeps the transaction visible and shows an error.
  - Narrow-width detail and confirmation layouts do not overflow.

Expected code shape:

- UI uses existing redesigned modal/dialog/action primitives from M38-M50.
- Repository method is the only Flutter write path for transaction deletion.
- No new Supabase migration, Gmail ingestion change, workbook importer change,
  or push-notification behavior in M54.

Acceptance criteria:

- Household owners can delete a transaction from Activity.
- Non-owner roles cannot access the delete action.
- Deleted transactions disappear from Activity after success.
- User-facing copy clearly explains spend impact, unlink behavior, and import
  suppression.
- Existing metadata edit and label edit actions still work.

Verification:

```bash
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter test test/finance_features_test.dart --name "transaction"
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M55 - Transaction Deletion Regression, Docs, And Cleanup

Purpose: prove the full deletion flow end to end and fold the final behavior
into durable docs.

Instructions:

- Start by reading:
  - M52-M54 completion notes in `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/INGESTION.md`
  - `docs/implementation-plan/GMAIL_CONNECTOR.md`
  - `docs/implementation-plan/WORKBOOK_IMPORT.md`
  - `docs/implementation-plan/MILESTONES.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
- Run the complete verification path after any cleanup fixes:
  - database reset/tests/lint/advisors
  - workbook importer tests and validation
  - Supabase function tests
  - Flutter analyze and tests
  - debug Android build if the local environment supports it
- Add or tighten regression tests only where gaps remain:
  - deleted transaction no longer affects monthly spend and cap progress
  - deleted Gmail/workbook source cannot resurrect
  - owner-only UI and RPC behavior
  - preserved/unlinked piggy-bank and diagnostics behavior
- Update durable docs with implemented behavior:
  - `README.md` scope defaults and new-session guidance.
  - `DATA_MODEL.md` transaction deletion and tombstone sections.
  - `INGESTION.md` idempotency and deleted-source suppression rules.
  - `GMAIL_CONNECTOR.md` reprocessing behavior.
  - `WORKBOOK_IMPORT.md` rerun behavior.
  - `MILESTONES.md` status and completion notes for M52-M55.
  - `SESSION_HANDOFF.md` current status, milestone status, and completion notes.
- Decide whether this companion plan should remain active:
  - If all M52-M55 behavior is fully folded into durable docs, mark
    `TRANSACTION_DELETION.md` as completed-only in handoff and leave removal to
    the same convention used for other completed companion plans.
  - Do not delete the plan unless the repository's current cleanup convention
    clearly calls for deletion in M55.

Expected code shape:

- Mostly verification, focused fixes, and documentation.
- No new product behavior beyond fixing gaps found during regression.

Acceptance criteria:

- Full deletion behavior is verified across database, ingestion, importer, and
  Flutter surfaces.
- Durable docs describe final implemented behavior without relying on this
  planning document.
- `SESSION_HANDOFF.md` clearly states that M52-M55 are complete and what remains
  deferred.
- No push-notification, iOS, web, hosted rollout, restore/undo, or bulk delete
  work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --fail-on none
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
deno test --allow-env --allow-read supabase/functions/tests
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug
git diff --check
rg -n "^(<<<<<<<|=======|>>>>>>>)" docs apps/mobile supabase tools
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
