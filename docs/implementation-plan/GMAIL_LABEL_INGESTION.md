# Gmail Label Ingestion Plan

Last updated: 2026-06-16

This document is the implementation plan for label-based HDFC Gmail ingestion.
Each milestone below is a standalone milestone intended to be executed in a
separate Codex thread. Stop after completing and documenting the current
milestone; do not automatically continue to the next milestone.

## Target Behavior

SpendLens should ingest Gmail transaction emails from the nested Gmail label
`Banking/HDFC Transactions`, shown in the Gmail UI as `HDFC Transactions` under
`Banking`.

- Gmail OAuth remains read-only: `https://www.googleapis.com/auth/gmail.readonly`.
- Archived emails and emails outside Inbox are valid candidates when they carry
  the watched Gmail label.
- Sender and subject no longer choose the transaction parser. The watched label
  identifies candidate emails, and body regex templates choose the parser.
- Supported body templates create idempotent transactions using the existing
  Gmail ingestion path, source fingerprints, tombstone suppression, merchant
  mapping, and Review queue behavior.
- Unsupported watched-label emails create sanitized Gmail parse-failure rows so
  the Review screen can tell the household which mail failed parsing.
- Review shows one row per visible parse failure with an `Ignore for now` action.
  Ignoring one row hides that failure household-wide while preserving the
  service-only diagnostic row.
- Add `Netbanking :: IMPS` as a Gmail/source candidate type alongside `Credit
  card` and `UPI`. It is not a category/subcategory and does not replace the
  ledger `transaction_type` values such as `debit_spend`.

## Existing Foundation

- `gmail-oauth-start`, `gmail-oauth-callback`, `gmail-watch-renewal`,
  `gmail-pubsub-webhook`, `gmail-sync`, `gmail-backfill-check`,
  `gmail-backfill-range`, and `gmail-message-body` already implement the Gmail
  connector through Supabase Edge Functions.
- `linked_mailboxes` stores mailbox email, Vault refresh-token reference,
  Gmail history id, watch expiry, status, scope, and sync status.
- `gmail-sync` currently watches hardcoded `INBOX`, collects
  `messagesAdded`, fetches full messages/threads, and processes queued
  `gmail_sync` and `gmail_backfill` jobs.
- `gmail_parsers.mjs` currently chooses HDFC credit-card and UPI parsers from
  sender plus subject metadata before running body regexes.
- `gmail_parse_attempts` stores service-only parse diagnostics; the sanitized
  `list_gmail_parse_failures(...)` RPC exposes failed metadata to Review.
- The Review screen already renders a Gmail parse failures card with subject,
  reason, parser, received time, sender, message id, and thread id.
- Gmail ingestion already routes parsed transactions through source accounts,
  source fingerprints, merchant aliases, mapping rules, review items, and
  deleted-source tombstone suppression.

## Global Rules For M65-M69

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Keep Gmail OAuth read-only. Do not request `gmail.modify`, create Gmail
  labels, remove Gmail labels, mark messages read, archive mail, or otherwise
  mutate Gmail.
- Do not store raw email bodies, body snippets, service keys, OAuth refresh
  tokens, or Gmail message bodies in app-visible tables.
- Use `supabase migration new <name>` for every schema migration. Do not invent
  migration filenames by hand.
- Keep `gmail_parse_attempts` service-only. Expose parse failures only through
  sanitized, household-scoped RPCs.
- Treat `Netbanking :: IMPS` as a source/candidate type, not as category
  taxonomy. Ledger transaction types remain `debit_spend`,
  `refund_reversal`, `bill_payment_credit`, `adjustment`, or `unknown`.
- Preserve Gmail source tombstone suppression from Milestones 52-55.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M65 - Gmail Label Ingestion Planning and Reference Readiness

Status: Completed on 2026-06-16.

Purpose: Create this companion plan and wire M66-M69 into durable planning docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `DATA_MODEL.md`, `INGESTION.md`, `GMAIL_CONNECTOR.md`,
  `MILESTONES.md`, and `SESSION_HANDOFF.md` so a fresh session can start M66
  from docs alone.
- Preserve M18-M21 push-notification deferral.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, or web implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `GMAIL_LABEL_INGESTION.md` describes M65-M69 as serial standalone milestones.
- M66 is the next recommended non-deferred implementation milestone.
- The docs state that implementation remains planned only.

Verification:

```bash
rg -n "GMAIL_LABEL_INGESTION|Milestone 6[5-9]|Gmail Label Ingestion|Netbanking :: IMPS" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Gmail label ingestion companion plan and routed future
  implementation through M66-M69.
- Confirmed the user wants Gmail readonly scope preserved, the watched Gmail
  label to be `Banking/HDFC Transactions`, unmatched watched-label emails to
  appear as parse failures, and `Ignore for now` to be household-wide per
  failure row.
- Confirmed `Netbanking :: IMPS` is a new source/candidate type beside UPI and
  Credit card, not category taxonomy.
- Implementation remains planned only; M66 was not started.
- Assumptions made:
  - Gmail API reports the nested label name as `Banking/HDFC Transactions`.
  - Existing connected mailboxes can be migrated to label-based watch renewal
    without reconnecting because the Gmail scope stays readonly.
  - The IMPS sample represents a debit-spend transaction.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M66 - Gmail Label Watch and Backfill Contract

Status: Completed on 2026-06-16.

Purpose: Replace Inbox/sender-based Gmail candidate discovery with readonly
watch, history, and backfill selection for the `Banking/HDFC Transactions`
label.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `INGESTION.md`, `GMAIL_CONNECTOR.md`, `MILESTONES.md`,
  `SESSION_HANDOFF.md`, `supabase/functions/_shared/google.ts`,
  `gmail-oauth-callback`, `gmail-watch-renewal`, `gmail-sync`,
  `gmail-backfill-check`, `gmail-backfill-range`, current Gmail Edge Function
  tests, and Gmail ingestion pgTAP tests.
- Use the Supabase skill. Check relevant Supabase CLI help before migrations
  and use `supabase migration new gmail_label_ingestion_contract`.
- Add nullable `linked_mailboxes` columns for the watched Gmail label id, label
  name, and resolution timestamp. Use exact label name
  `Banking/HDFC Transactions`.
- Add Gmail helper support to list labels, resolve the exact watched label by
  name, and fail clearly when it is missing. Do not silently fall back to
  `INBOX`.
- Update Gmail watch setup and watch renewal to pass the resolved label id in
  `labelIds` with `labelFilterBehavior: "include"`.
- Update history listing to request the watched label id and collect both
  `messagesAdded` and `labelsAdded` candidates. Preserve job idempotency by
  message id and existing Gmail history id semantics.
- Update message/thread processing so only messages that still carry the
  watched label are parsed. Thread expansion must not process unrelated
  messages that lack the watched label.
- Update backfill listing to pass the watched label id plus date bounds. Remove
  the default `from:alerts@hdfcbank.bank.in` candidate search for the new
  label-based flow.
- Keep existing service-key protections, structured operational logging,
  mailbox error marking, and daily renewal/backfill scheduling.
- Do not add body-parser changes, `Netbanking :: IMPS`, Review ignore behavior,
  hosted rollout, iOS, web, or push-notification work in this milestone.

Expected code shape:

- Gmail helper APIs accept optional label ids for watch, history, and messages
  list calls.
- Label resolution is centralized and reused by OAuth callback and renewal.
- Existing connected mailboxes are reconfigured by renewal/sync once the
  watched label can be resolved; no new Gmail scope is required.

Acceptance criteria:

- OAuth callback and watch renewal store the watched label id/name and configure
  Gmail watch for `Banking/HDFC Transactions`.
- Archived/non-Inbox messages carrying that label can be found by backfill.
- History sync can enqueue/process candidates from watched-label message and
  label-added history.
- Missing label produces an operator-visible connector error.
- Existing Inbox-only behavior is no longer the default for active Gmail sync.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/production_readiness.sql
supabase db lint --local --schema app_private,public --fail-on error
deno test --allow-env --allow-net supabase/functions/tests/google.test.ts
deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added `20260616120838_gmail_label_ingestion_contract.sql` with watched Gmail
  label id/name/resolution fields on `linked_mailboxes`, status-view exposure,
  and the updated service-role `upsert_gmail_mailbox(...)` contract.
- Added shared Gmail label helpers to list labels, resolve the exact
  `Banking/HDFC Transactions` label, configure Gmail watch with that label id,
  request history for watched-label message and label-added changes, and list
  backfill candidates by label id plus date bounds.
- Updated OAuth callback, watch renewal, and sync processing so active Gmail sync
  no longer falls back to `INBOX` or sender-only candidate discovery. Existing
  connected mailboxes can resolve and store the watched label during sync, while
  renewal configures future watches with the watched label.
- Updated message/thread processing to skip messages that do not still carry the
  watched label, preventing unrelated messages in an expanded thread from being
  parsed.
- Added focused Edge Function and pgTAP coverage for label resolution,
  label-filtered watch/history/backfill requests, mailbox label persistence, and
  connector-status exposure.
- Deferred scope was not started: body-first parser registry, Netbanking IMPS,
  watched-label parse-failure Review ignore, hosted rollout, iOS, web, push
  notifications, M67, M68, and M69.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase test db --local supabase/tests`
  - `deno test --allow-env --allow-net supabase/functions/tests/google.test.ts`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Known gaps:
  - `supabase db advisors --local --fail-on none` reports pre-existing merchant
    RLS performance warnings for `public.merchants` delete policies; no M66 Gmail
    label migration warnings were reported.
- Assumptions made:
  - Gmail API returns the nested label name exactly as
    `Banking/HDFC Transactions`.
  - Existing connected mailboxes can keep their readonly Gmail scope; sync can
    resolve the label id for label-based processing, and renewal configures the
    future watch with the same label id.
  - Missing watched label should surface as a connector/operator error instead of
    falling back to Inbox/sender discovery.
- Mocks created:
  - None.
- Mocks used:
  - Stubbed Gmail API responses in Edge Function unit tests for labels, watch,
    history, and message-list requests.

## M67 - Body-First Parser Registry and Netbanking IMPS Parser

Status: Planned.

Purpose: Route watched-label Gmail candidates by deterministic body regexes and
add the HDFC `Netbanking :: IMPS` debit template.

Instructions:

- Before editing, inspect this plan, `gmail_parsers.mjs`,
  `gmail_parsers.test.mjs`, `gmail-sync`, `ingest_gmail_transaction`, Gmail
  ingestion pgTAP tests, and the current source-account enum usages in SQL and
  Flutter.
- Use `supabase migration new gmail_netbanking_imps_candidate_type`.
- Add `netbanking_imps` to `public.source_account_type`.
- Update `gmail_parse_attempts` validation and health views/tests to allow
  `netbanking_imps` and `other` candidate types.
- Refactor the parser registry so `parseGmailTransaction(metadata, bodyText)`
  tries body parsers in order and returns the first successful parse. Sender and
  subject may remain diagnostic metadata but must not be required for parser
  routing.
- Preserve existing credit-card and UPI body regex support and fixture coverage.
- Add an `hdfc_netbanking_imps_debit` parser with `candidate_type:
  "netbanking_imps"`, parser version `1.0.0`, and a body regex for the sample
  format:
  - amount after `INR`
  - debited source account ending digits
  - `DD-MM-YY` transaction date
  - credited destination account ending digits
  - `via IMPS`
  - `IMPS Reference No`
- The sample email must parse to:
  - amount `33500.00`
  - transaction date `2026-06-16`
  - ledger `transaction_type` `debit_spend`
  - statement merchant `IMPS to ending 4428`
  - source reference `616734130236`
  - source account hint type `netbanking_imps`
  - display name `HDFC Netbanking IMPS account ending 0932`
  - institution `HDFC Bank`
  - masked identifier `0932`
  - diagnostics including destination account ending `4428` and template name
- Update source fingerprinting for `netbanking_imps` to prefer source reference
  plus source account identity so reprocessing is idempotent.
- Do not add Review ignore UI, Gmail label watch changes beyond what M66
  already did, hosted rollout, iOS, web, or push-notification work.

Expected code shape:

- Parser definitions remain deterministic JavaScript regex/code with fixture
  tests.
- `netbanking_imps` is a source/candidate type and display label only; it is not
  a category/subcategory and does not alter the ledger `transaction_type` enum.

Acceptance criteria:

- Existing HDFC credit-card and UPI samples still parse without subject-gated
  routing.
- The provided IMPS sample parses into a valid Gmail transaction payload.
- `gmail_parse_attempts` and Flutter candidate labels can represent
  `Netbanking :: IMPS`.
- Gmail ingestion can upsert an IMPS transaction through existing source-account,
  transaction-source, merchant mapping, review, and tombstone paths.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase db lint --local --schema app_private,public --fail-on error
node --test supabase/functions/tests/gmail_parsers.test.mjs
deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M68 - Watched-Label Parse Failures and Review Ignore

Status: Planned.

Purpose: Make every unsupported watched-label email visible as a sanitized
Review parse failure and let the household ignore individual failure rows.

Instructions:

- Before editing, inspect this plan, `gmail_parse_attempts`,
  `list_gmail_parse_failures`, `record_gmail_parse_attempt`, `gmail-sync`,
  `finance_repository.dart`, `merchant_review_screen.dart`, and
  `finance_features_test.dart`.
- Use `supabase migration new gmail_parse_failure_ignore`.
- Add `ignored_at timestamptz` and `ignored_by uuid references profiles(id)` to
  `gmail_parse_attempts`.
- Update `record_gmail_parse_attempt(...)` and sync behavior so any watched-label
  email with no matching body parser records one `parse_failed` row with:
  - `candidate_type` `other`
  - `parser_name` `unsupported_labeled_gmail_message`
  - `parser_version` `1.0.0`
  - reason `no_supported_body_template_matched`
  - sender, subject, received timestamp, message id, and thread id
- Update `list_gmail_parse_failures(...)` to return only unignored
  `parse_failed` rows and keep raw bodies/snippets out of the response.
- Add `ignore_gmail_parse_failure(p_failure_id uuid)` as an authenticated,
  household-scoped RPC. It must validate active household membership and mark
  exactly one parse failure ignored household-wide.
- Add repository model/method support for ignoring one Gmail parse failure and
  invalidate the parse-failure provider after success.
- Add one `Ignore for now` action to each Gmail parse failure row in Review.
  Ignoring one row hides that row; when all visible rows are ignored, the card
  disappears.
- Add labels for `netbanking_imps`, `hdfc_upi_debit_pattern_not_matched`,
  `hdfc_imps_debit_pattern_not_matched`, and
  `no_supported_body_template_matched`.
- Do not add Gmail mutation, bulk ignore, hosted rollout, iOS, web, or push
  notifications in this milestone.

Expected code shape:

- Parse failure ignore is an app-facing RPC; the Flutter app does not receive
  direct table privileges on `gmail_parse_attempts`.
- Ignore state is persistent and household-wide, not local-only UI state.

Acceptance criteria:

- Unsupported watched-label emails appear in Review with sender, subject,
  received time, reason, message id, and thread id.
- The user can ignore one failure row without hiding other failures.
- Ignored rows stay hidden across refresh/app restart for the household.
- `gmail_parse_attempts` remains service-only and sanitized.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase test db --local supabase/tests/rls_isolation.sql
supabase db lint --local --schema app_private,public --fail-on error
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Ignore for now|Netbanking"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M69 - Gmail Label Ingestion Regression, Docs, and Cleanup

Status: Planned.

Purpose: Verify the complete label-based Gmail ingestion workflow and fold final
behavior into durable docs.

Instructions:

- Before editing, inspect this plan, `README.md`, `ARCHITECTURE.md`,
  `DATA_MODEL.md`, `INGESTION.md`, `GMAIL_CONNECTOR.md`, `PRODUCTION_READINESS.md`,
  `MILESTONES.md`, `SESSION_HANDOFF.md`, all Gmail Edge Functions, Gmail parser
  tests, Gmail pgTAP tests, and Review widget tests.
- Run the full local regression path or document any environment limitation.
- Update durable docs with the final behavior: readonly label-based watch,
  watched-label backfill, body-first parser routing, `Netbanking :: IMPS`,
  parse-failure ignore, privacy rules, and operational runbook changes.
- Mark this companion plan completed-only after M69 is complete.
- Confirm M18-M21 remain deferred unless the user explicitly resumes push
  notifications.
- Do not perform hosted Supabase migration push, Edge Function deployment,
  iOS, web, or push notification work unless explicitly requested.

Expected code shape:

- This milestone should mostly be verification, cleanup, and documentation.
  Runtime changes should be limited to fixing regressions found during
  verification.

Acceptance criteria:

- The full local Gmail label ingestion regression path passes or any local
  service limitation is documented with compensating test evidence.
- Durable docs describe final Gmail selection, parser, diagnostics, and Review
  ignore behavior.
- `GMAIL_LABEL_INGESTION.md` is marked completed-only.
- No unrelated deferred work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase test db --local supabase/tests/production_readiness.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
node --test supabase/functions/tests/gmail_parsers.test.mjs
deno test --allow-env --allow-net supabase/functions/tests/google.test.ts
deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Settings|Activity"
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
