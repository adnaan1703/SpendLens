# Session Handoff

Use this file to coordinate work across multiple implementation sessions. Update it whenever a milestone starts, completes, or materially changes.

## Current Status

- Current milestone: Not started.
- Last completed milestone: Milestone 16, Merchant Research Retirement.
- Current implementation state: Flutter Android app scaffold exists in `apps/mobile` with SpendLens Google sign-in, route protection, authenticated shell, RLS-safe profile/default-household bootstrap, household loading/error states, sign-out, package `com.olympus.spendlens`, core packages, environment templates, tests, and Supabase folder structure. Supabase local config applies migrations for schema, RLS, views, workbook-derived default categories, merchant review corrections, piggy-bank entry validation, Gmail connector ingestion, production-readiness monitoring views, AI feature settings/usage/jobs/transaction metadata suggestions, pgTAP database tests, and the Android auth redirect URL. Milestone 3 adds a local workbook importer under `tools/workbook-import`, fixture tests, and rerun documentation in `docs/implementation-plan/WORKBOOK_IMPORT.md`. Milestone 5 adds Supabase-backed finance repository reads/writes, dashboard KPIs, reporting-month selection, monthly category cap setup/editing, category and merchant summaries, transaction search/filter pagination, and transaction detail panels. Milestone 6 adds merchant review queue UI, correction RPC/rule persistence, historical reclassification, review resolution, transaction classification audit metadata, and future-import rule application. Milestone 7 adds Supabase-backed piggy-bank list/detail UI, create/edit forms, ledger entry creation, ledger-derived balance/progress reads, no-overdraft withdrawal validation, and regression tests. Milestone 8 adds filtered monthly trend reports, gross/refund/net reporting, category trend tables, merchant summary tables, and filtered transaction CSV copy from the Trends screen. Milestone 9 adds Vault-backed Gmail OAuth connector state, Pub/Sub webhook job dedupe, Gmail sync/backfill/watch-renewal Edge Functions, HDFC credit-card debit parsing from anonymized fixtures, SQL ingestion RPCs, and Settings connector status/connect/disconnect UI. Milestone 10 adds HDFC Bank UPI debit parsing from anonymized fixtures, UPI-aware Gmail backfill search and fingerprinting, UPI ingestion pgTAP coverage, and source-type filters for credit card vs UPI on transaction/trend screens. Milestone 11 adds production-readiness runbooks, local smoke automation, service-role ingestion/parser health views, structured Edge Function operational logs, Android release signing/shrinking configuration, and staging/production Edge Function secret templates. Milestone 12 adds Gemini-backed expense Q&A, transaction metadata suggestions, AI usage/budget status, backend-only LLM calls, and free-tier-only dev/staging controls. Milestone 13 adds a service-only May 2026 Gmail range backfill function, range-aware Gmail sync search/date filtering, OAuth account selection for mailbox choice, deployment tooling updates, and a hosted dev/staging runbook. Milestone 14 adds authenticated in-app creation of a category plus first subcategory from Settings and Merchant Review through an RLS-safe `create_household_category` RPC. Milestone 15 adds authenticated transaction metadata editing from Review and Transactions through an RLS-safe `apply_transaction_metadata_correction` RPC, a shared Flutter metadata editor, confidence editing, exact normalized merchant reclassification, future mapping-rule updates, and regression coverage. Milestone 16 retires the legacy AI lookup path, keeps expense Q&A plus transaction metadata Suggest, renames Suggest budget/search flags, removes the obsolete Edge Function and Flutter models, and keeps historical AI audit rows.
- Remote deployment state: On 2026-06-08, user confirmed Supabase project `bslsitzdvrdosubbdxpd` as the intended dev/staging target. All local migrations through `20260607174515_ai_ready_layer_llm_features.sql` were pushed there, hosted expense Q&A and the now-retired legacy AI lookup function were active with JWT verification, and `GEMINI_API_KEY` was present in hosted Edge Function secrets by name. After the user signed in through the Android emulator, hosted profile/household bootstrap and authenticated Gemini Edge Function smoke passed. On 2026-06-08 for Milestone 13, `gmail-oauth-start` was deployed as version 2 with JWT verification, `gmail-sync` was deployed as version 2 without JWT verification, and new `gmail-backfill-range` was deployed as version 1 without JWT verification. Hosted `gmail-backfill-range` `OPTIONS` smoke returned 200, and an unauthenticated POST returned the expected service-key error. The live May Gmail backfill itself was not run because it requires the user to connect the target Gmail mailbox and invoke the runbook with a Supabase secret key from a local/platform secret store. On 2026-06-09, M16 deleted the hosted legacy AI lookup function from `bslsitzdvrdosubbdxpd` and a follow-up function list verified it absent. The M16 database migration and updated active Suggest function were verified locally but not pushed/deployed to hosted in this implementation session.
- Next recommended milestone: None currently active. If continuing hosted rollout, push the M16 migration and deploy `transaction-metadata-suggest`; iOS and web remain deferred future milestones unless explicitly resumed.

## Required Reading for New Threads

At the start of a new implementation thread, read:

1. `docs/implementation-plan/README.md`
2. `docs/implementation-plan/ARCHITECTURE.md`
3. `docs/implementation-plan/DATA_MODEL.md`
4. `docs/implementation-plan/INGESTION.md`
5. The target milestone section in `docs/implementation-plan/MILESTONES.md`
6. `docs/implementation-plan/TRANSACTION_METADATA_EDITING.md` when executing Milestone 15
7. This handoff file

## Current Assumptions

- Flutter will be used for Android first.
- iOS app work is deferred and not part of the current implementation plan.
- Web interface work is deferred and not part of the current implementation plan.
- Supabase is the v1 backend platform.
- Architecture is serverless-first, not backend-less.
- Gmail ingestion starts with Gmail API watch plus Pub/Sub.
- Monthly category caps are the first budget model.
- Piggy banks are manual ledgers.
- Merchant corrections apply to past and future matching transactions.
- Transaction metadata edits should apply to matching past transactions and the
  future exact mapping rule for the edited normalized statement merchant; they
  are not merchant-group-wide alias merges unless the user explicitly expands
  scope.
- Raw email bodies are not retained by default.
- LLM features are backend-mediated through Supabase Edge Functions.
- In-app category creation creates a category plus its first subcategory together; broader taxonomy administration is deferred.

## Clarification Policy

Future Codex sessions must ask the user before making any undocumented product, architecture, schema, naming, deployment, billing, or external-service decision.

The session may recommend a default, but it must wait for explicit user confirmation before implementing that choice. Examples that require confirmation include app package name, bundle ID, production domain, Supabase project details, OAuth client choices, billing plan, AI provider, and monthly AI budget cap.

Facts that can be read from the repository should be discovered directly. Do not ask the user for information that is already present in files or configuration.

## External Setup Timeline

Do not ask the user to perform all setup at once. Ask only when the relevant milestone begins.

- Milestone 2: Supabase development project.
- Milestone 4: Supabase Google Auth configuration.
- Milestone 9: Google Cloud project, Gmail API, Pub/Sub, OAuth consent, OAuth clients.
- Milestone 10: Anonymized UPI email samples.
- Milestone 11: Production Supabase project and Google Play Console account if Android release is needed.
- Milestone 12: Gemini API key in Supabase Edge Function secrets before live AI calls.

## Milestone Status

- Milestone 1, Project Foundation: completed.
- Milestone 2, Supabase Schema, RLS, and Local Backend: completed.
- Milestone 3, Workbook Import and Historical Seed Data: completed.
- Milestone 4, App Shell, Authentication, and Household Context: completed.
- Milestone 5, Expense Dashboard, Transactions, and Monthly Caps: completed.
- Milestone 6, Merchant Mapping and Review Workflow: completed.
- Milestone 7, Piggy Banks: completed.
- Milestone 8, Trends and Reports: completed.
- Milestone 9, Gmail Connector and Credit-Card Email Ingestion: completed.
- Milestone 10, UPI Ingestion and Parser Expansion: completed.
- Milestone 11, Deployment, Security, and Production Readiness: completed.
- Milestone 12, AI-Ready Layer and LLM Features: completed.
- Milestone 13, May 2026 Gmail Backfill: completed.
- Milestone 14, In-App Category Creation: completed.
- Milestone 15, Transaction Metadata Editing: completed.

## Update Rules

When a milestone starts:

- Set `Current milestone`.
- Note any external setup requested from the user.
- Link to relevant implementation files once they exist.

When a milestone completes:

- Update `Last completed milestone`.
- Mark the milestone status as completed.
- Note tests/checks run.
- Note any known gaps or deferred items.

When an architecture decision changes:

- Update `ARCHITECTURE.md` or `DATA_MODEL.md`.
- Add a short note here explaining why the change was made.

## Milestone 1 Completion Notes

- Completed on 2026-06-04.
- User-confirmed app display name: `SpendLens`.
- User-confirmed Android package name: `com.olympus.spendlens`.
- User-confirmed package choices: `go_router`, `flutter_riverpod`, `fl_chart`, plus `supabase_flutter`.
- CI was skipped by user request.
- Added local/staging/production Flutter env templates under `apps/mobile/env`.
- Added Supabase backend folder documentation; Supabase CLI was not installed locally during this milestone.
- Verification run:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`

## Milestone 2 Completion Notes

- Completed on 2026-06-05.
- Added Supabase migrations for app identity, households, source accounts/mailboxes, imports, categories/caps, merchants/rules, transactions/sources, review queue, piggy banks, enums, constraints, indexes, RLS policies, grants, and summary views.
- Added workbook-derived default category and subcategory seed migration from `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`.
- Added pgTAP database tests for household RLS isolation, RLS/security-invoker posture, and key summary view calculations.
- Local Supabase stack was started; no duplicate sleep guard was started.
- Verification run:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema public --fail-on error`
  - `supabase db lint --local --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - Supabase MCP remote security and performance advisors
- Known gaps:
  - The Supabase CLI project is not linked locally, so migrations were not pushed to the remote project from this session.
  - Full workbook transaction import was deferred to Milestone 3 and is now complete.

## Milestone 3 Completion Notes

- Completed on 2026-06-05.
- Added a pinned local Node importer in `tools/workbook-import` for `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`.
- The importer creates a deterministic local seed auth user/profile/household, one deterministic workbook import batch, source accounts for the three cardholders, household categories/subcategories, merchants, merchant aliases, transactions, transaction source metadata, and review items.
- Stable fingerprints are derived from workbook source facts; running the import twice leaves 475 workbook transactions and reuses the same import batch.
- Imported workbook totals observed:
  - Transactions: 475.
  - Gross spend: 1,548,630.69.
  - Refunds: 26,242.46.
  - Net expense: 1,522,388.23.
  - Card bill payments: 1,349,006.00.
  - Review items: 29 open items.
- Local database counts after the second import: one import batch, 3 source accounts, 21 categories, 34 subcategories, 44 merchants, 171 merchant aliases, 475 transaction source rows, and 29 review items.
- Added `docs/implementation-plan/WORKBOOK_IMPORT.md` with safe local rerun steps and admin/credential boundaries.
- Verification run:
  - `pnpm --dir tools/workbook-import install --frozen-lockfile`
  - `pnpm --dir tools/workbook-import audit --audit-level=moderate`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `supabase db reset --local`
  - `pnpm --dir tools/workbook-import run import`
  - `pnpm --dir tools/workbook-import run import`
  - `supabase db query --local -o json "<validation count query>"`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema public --fail-on error`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `pnpm --dir tools/workbook-import install --frozen-lockfile`
- Known gaps:
  - No remote Supabase import or remote advisors were run; Milestone 3 was verified locally only.
  - `supabase db lint --local --fail-on error` across all schemas fails on pgTAP helper functions in the Supabase `extensions` schema after database tests install pgTAP. Targeted app schemas (`app_private,public`) pass with no schema errors.

## Milestone 4 Completion Notes

- Completed on 2026-06-05.
- Added Supabase Auth session providers, Google OAuth sign-in, and Android callback handling with `com.olympus.spendlens://login-callback/`.
- Added route guards so unauthenticated users land on `/sign-in` and authenticated users are routed into the existing shell.
- Added RLS-safe app bootstrap that creates/loads the signed-in profile, creates a default household for first-time users, and inserts the first owner membership without service-role credentials in Flutter.
- Added household loading and error states around authenticated routes.
- Added account/household runtime details and sign-out flow in Settings.
- Updated environment templates, mobile setup docs, Supabase local redirect config, and external setup notes for Google Auth.
- Verification run:
  - `flutter pub get`
  - `dart format <Milestone 4 Dart files>`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase test db --local supabase/tests`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
- Known gaps:
  - Google Auth provider and Android OAuth client still require external Supabase/Google Console setup before live sign-in can be tested.
  - `flutter test integration_test` could not run because no supported Android device/emulator was connected.

## Milestone 5 Completion Notes

- Completed on 2026-06-05.
- Replaced the placeholder finance repository with Supabase-backed models/providers for monthly spend, category spend, budget progress, categories, source accounts, paginated transactions, and category cap upserts through authenticated RLS-protected client calls.
- Dashboard now shows the selected reporting month's net spend, month-over-month change, review count, cap count, top categories, top merchants, budget progress, uncapped categories, and cap add/edit dialog.
- Transactions now support merchant search, category filter, source-account filter, date-range filter, pagination, clear filters, and a detail bottom sheet with gross spend, refunds, net expense, source amount, category, type, confidence, cardholder, and notes.
- Added widget tests with a fake finance repository for dashboard KPI/cap behavior and transaction search/category filter behavior.
- Verification run:
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/dashboard/dashboard_screen.dart apps/mobile/lib/src/features/transactions/transactions_screen.dart apps/mobile/lib/src/shared/widgets/metric_card.dart apps/mobile/test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - No schema migration was needed for this milestone; existing M2 summary views and RLS/grants are used.
  - Live authenticated Supabase data and Android-device integration coverage were not exercised in this session.

## Milestone 6 Completion Notes

- Completed on 2026-06-05.
- Added a Supabase migration for merchant correction workflow support:
  - Transaction classification audit columns for applied rule, review item, correcting profile, correction timestamp, and note.
  - Manual mapping-rule notes, exact-match uniqueness, merchant display-name uniqueness, and helper indexes.
  - `normalize_merchant_name`, `merchant_rule_matches`, `match_merchant_mapping_rule`, and authenticated `apply_merchant_review_correction` RPC.
  - Expanded `v_review_queue` with current merchant/category/subcategory context.
- The correction RPC validates household write membership through existing app-private helpers, creates or updates a manual exact mapping rule, upserts the corrected merchant alias, reclassifies matching historical transactions, resolves related review items, and records audit metadata on changed transactions/review rows.
- The workbook importer now loads active durable mapping rules, applies them to matching future parsed rows, keeps non-matching rows unchanged, writes rule audit metadata, and validates database summaries against post-rule classifications while preserving workbook money reconciliation.
- The Flutter merchant review screen now shows open review items with date, amount, statement merchant, current mapping, confidence, and reason; users can submit merchant group/category/subcategory/notes corrections through the Supabase RPC.
- Added pgTAP coverage for historical reclassification, future rule matching, non-matching merchant preservation, durable rule creation, alias update, audit metadata, and queue-count decrease.
- Added importer fixture coverage for future parsed transaction rule application and widget coverage for resolving a review item.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for RPC/RLS/security-invoker guidance
  - `supabase migration --help`
  - `supabase db --help`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `pnpm --dir tools/workbook-import run import`
  - `pnpm --dir tools/workbook-import run import`
  - `dart format lib/src/data/repositories/finance_repository.dart lib/src/features/merchant_review/merchant_review_screen.dart test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - No Supabase remote migration push or remote advisors were run; verification was local only.
  - Live authenticated Android-device review workflow coverage was not exercised in this session.

## Milestone 7 Completion Notes

- Completed on 2026-06-05.
- Added a Supabase migration for `create_piggy_bank_entry`, an authenticated security-invoker RPC that inserts ledger entries, records the signed-in profile, supports optional linked transactions, serializes per-piggy-bank writes, and rejects withdrawals that exceed the current ledger-derived balance.
- Added pgTAP coverage for empty balances, target progress, deposits, withdrawals, adjustments, linked transactions, no-overdraft validation, and positive-amount validation.
- Expanded the Flutter finance repository with piggy-bank summaries, entry timelines, create/edit piggy-bank writes, and entry creation through the RPC.
- Replaced the placeholder Piggy Banks screen with active ledger cards, current balance/target progress detail, create/edit forms, deposit/withdrawal/adjustment entry dialogs, notes, and optional linked transaction selection.
- Added widget coverage for creating a piggy bank, adding deposit/withdrawal entries, and verifying balance plus target-progress updates.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for RLS/RPC/security-invoker guidance
  - `supabase migration --help`
  - `supabase db --help`
  - `supabase migration new piggy_bank_entry_validation`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `dart format lib/src/data/repositories/finance_repository.dart lib/src/features/piggy_banks/piggy_banks_screen.dart test/finance_features_test.dart`
  - `flutter test test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - No Supabase remote migration push or remote advisors were run; verification was local only.
  - Live authenticated Android-device piggy-bank workflow coverage was not exercised in this session.

## Milestone 8 Completion Notes

- Completed on 2026-06-05.
- Expanded the Flutter finance repository with `TrendQuery`, `TrendReport`, filtered transaction aggregation, category trend rows, merchant summaries, and CSV generation for filtered transactions.
- Replaced the Trends placeholder with an interactive report screen:
  - Monthly net spend line chart.
  - Gross, refunds, net, and bill-payment monthly table.
  - Category trend table across report months.
  - Merchant summary table with merchant group, category, subcategory, transaction count, gross spend, refunds, and net spend.
  - Shared transaction-style filters for date range, category, and source/cardholder.
  - Filtered transaction CSV copy action using the current Flutter stack without adding native file/share dependencies.
- Added model and widget coverage for trend aggregation, CSV escaping, report rendering, and category/source filter query refresh.
- Local imported workbook report check after reset/import:
  - Transactions: 475.
  - Gross spend: 1,548,630.69.
  - Refunds: 26,242.46.
  - Net expense: 1,522,388.23.
  - Monthly rows: 12, monthly net total: 1,522,388.23.
  - Category rows: 20, category net total: 1,522,388.23.
  - Merchant rows: 43, merchant net total: 1,522,388.23.
- Verification run:
  - Supabase changelog check via `curl https://supabase.com/changelog.md`.
  - Supabase MCP docs search for current filter/query guidance.
  - `dart format lib/src/data/repositories/finance_repository.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart`
  - `flutter test test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db reset --local`
  - `pnpm --dir tools/workbook-import run import`
  - `supabase db query --local -o json "<Milestone 8 imported reporting totals query>"`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
- Known gaps:
  - No schema migration was needed for this milestone; existing RLS-protected transaction reads and summary semantics are used.
  - No Supabase remote migration push or remote advisors were run; verification was local only.
  - Live authenticated Android-device trends workflow coverage was not exercised in this session.

## Milestone 9 Completion Notes

- Completed on 2026-06-07.
- Added a Supabase migration for Gmail connector ingestion:
  - Supabase Vault refresh-token references through `linked_mailboxes.oauth_secret_ref`.
  - Service-only OAuth state and ingestion job tables with RLS enabled and no authenticated direct grants.
  - Non-secret `v_linked_mailbox_status` security-invoker view for Flutter.
  - Service-only RPCs for mailbox upsert/disconnect, Vault token retrieval, Pub/Sub notification dedupe, mailbox error recording, and parsed Gmail transaction ingestion.
  - Idempotent Gmail transaction/source upserts and review-item creation for unknown or non-high-confidence classifications.
- Added Edge Functions:
  - `gmail-oauth-start`
  - `gmail-oauth-callback`
  - `gmail-connector-status`
  - `gmail-disconnect`
  - `gmail-pubsub-webhook`
  - `gmail-sync`
  - `gmail-watch-renewal`
  - `gmail-backfill-check`
- Added shared Gmail helpers for Google OAuth/token refresh, Gmail `watch`, history sync, bounded backfill, message text extraction, fingerprinting, and HDFC credit-card debit parsing.
- Added parser tests using the anonymized HDFC debit samples provided for Milestone 9.
- Added Settings connector UI for Gmail status, connect, refresh, queued job count, last sync/error, watch expiry, and disconnect.
- Added `docs/implementation-plan/GMAIL_CONNECTOR.md` with deploy order, secrets, push endpoint verification, schedule notes, and privacy boundaries.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for Edge Function secrets/auth, Vault, and Edge Function testing guidance
  - Google primary docs lookup for Gmail push notifications, Gmail sync, and Pub/Sub push message shape
  - `supabase --version`
  - `supabase migration --help`
  - `supabase db --help`
  - `supabase functions --help`
  - `supabase migration new gmail_connector_ingestion`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `flutter pub get`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/settings/settings_screen.dart apps/mobile/test/finance_features_test.dart`
  - `flutter test test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `supabase functions serve --no-verify-jwt` with dummy local Google/PubSub secrets
  - Edge Function local `OPTIONS` smoke for all Milestone 9 functions
  - Dummy Pub/Sub webhook POST with `PUBSUB_VERIFICATION_SECRET`
  - Local service-key smoke for `gmail-sync`, `gmail-backfill-check`, and `gmail-watch-renewal`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - No remote Supabase migration push, function deployment, hosted secret setup, or remote advisors were run.
  - Final live OAuth testing still requires adding/requesting `https://www.googleapis.com/auth/gmail.readonly` on the Google consent screen and adding the Edge Function callback URL to the Web OAuth client.
  - Final live Pub/Sub testing still requires deploying `gmail-pubsub-webhook`, setting `PUBSUB_VERIFICATION_SECRET`, and creating the push subscription. For the shared-secret path, use the endpoint with `?token=<PUBSUB_VERIFICATION_SECRET>` or provide the same value through a trusted proxy header.
  - Scheduled production invocation of `gmail-sync`, `gmail-watch-renewal`, and `gmail-backfill-check` is documented but not configured against the hosted project because the hosted secret key was not provided to this session.
  - Live authenticated Android-device connector coverage was not exercised in this session.

## Milestone 10 Completion Notes

- Completed on 2026-06-07.
- Added HDFC Bank UPI debit parser support from the anonymized samples provided for Milestone 10:
  - Parses amount, date, account-ending hint, payee label, UPI reference number, and source-account metadata.
  - Creates `source_account_hint.type = 'upi'` with the HDFC Bank account-ending identifier.
  - Avoids storing raw message bodies or full payee VPA values in parser diagnostics.
- Expanded Gmail bounded-backfill search to include HDFC UPI alert wording.
- Updated Gmail sync fingerprinting so UPI alerts with the same reference number dedupe across parser/template variants.
- Added Deno-local verification for Edge Functions after Deno was installed, including `fmt`, `lint`, `check`, and parser tests.
- Kept the shared Supabase Edge Function client on a temporary loose database type until generated Supabase database types are added.
- Added pgTAP coverage for UPI ingestion through `ingest_gmail_transaction`, including one UPI source account, fingerprint idempotency, and review-item creation for unknown UPI payees.
- Added mobile source-type filters for `credit_card` vs `upi` on Transactions and Trends while preserving specific source-account filters.
- Updated ingestion/Gmail connector docs with current parser coverage and the remaining sample-gated credit/refund templates.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for Edge Function testing/local development guidance
  - `supabase --version`
  - `supabase test db --help`
  - `supabase db lint --help`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `node --check supabase/functions/_shared/parsers/gmail_parsers.mjs`
  - `deno --version`
  - `deno fmt supabase/functions`
  - `deno lint supabase/functions`
  - `deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts`
  - `deno test supabase/functions/tests/gmail_parsers.test.mjs`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/transactions/transactions_screen.dart apps/mobile/lib/src/features/trends/trends_screen.dart apps/mobile/test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test test/finance_features_test.dart`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `supabase functions serve gmail-sync --no-verify-jwt` with dummy local Google/PubSub env values
  - `curl -i -X OPTIONS http://127.0.0.1:54321/functions/v1/gmail-sync`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - UPI credit/refund parsing remains deferred until anonymized matching samples are provided.
  - No remote Supabase migration push, function deployment, hosted secret setup, or remote advisors were run.
  - Live authenticated Android-device UPI ingestion/filter coverage was not exercised in this session.

## Milestone 11 Completion Notes

- Completed on 2026-06-07.
- Added production-readiness documentation in `docs/implementation-plan/PRODUCTION_READINESS.md` covering environment split, local readiness gates, Supabase deployment order, Google production setup, scheduling, monitoring, Android release builds, billing alerts, backups, and hosted smoke tests.
- Added service-role-only operational views:
  - `public.v_ingestion_operational_health` for active mailboxes, missing OAuth secrets, expiring watches, stale syncs, queued/retrying/failed jobs, and latest non-secret errors.
  - `public.v_parser_operational_health` for Gmail parser/version/status counts.
- Added pgTAP production-readiness coverage proving the operational views are `security_invoker`, not granted to `anon`/`authenticated`, readable by `service_role`, and summarize retry/parser state correctly.
- Added structured JSON Edge Function logs for Gmail OAuth, Pub/Sub, sync, watch renewal, backfill, disconnect, and connector-status failures without logging raw Gmail bodies or OAuth codes.
- Added `tools/production-readiness/local-smoke.sh` for repo secret checks, service-only view checks, Supabase test/lint/advisor checks, Edge Function checks, parser tests, and optional mobile release smoke via `RUN_MOBILE=1`.
- Added `tools/production-readiness/deploy-edge-functions.sh` for deploying JWT-protected and service/public Gmail Edge Functions to a confirmed Supabase project ref.
- Added staging/production Edge Function secret templates under `supabase/functions/env`, tightened `.gitignore` for local env files, and documented production values as placeholders only.
- Added Android release signing configuration through ignored `apps/mobile/android/key.properties`, release shrinking, `proguard-rules.pro`, and `key.properties.example`; local release builds fall back to debug signing when no upload key exists.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for Edge Function secrets, deployment, scheduling, publishable/secret keys, and production monitoring guidance
  - `supabase --version`
  - `supabase functions --help`
  - `supabase functions deploy --help`
  - `supabase secrets --help`
  - `supabase db --help`
  - `supabase db push --help`
  - `supabase db advisors --help`
  - `supabase migration new production_readiness_monitoring`
  - `deno fmt supabase/functions`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase test db --local supabase/tests`
  - `tools/production-readiness/local-smoke.sh`
  - `flutter analyze`
  - `flutter test`
  - `flutter pub get`
  - `flutter build apk --release --no-pub --dart-define=APP_ENV=production --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_example --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/`
  - `RUN_MOBILE=1 tools/production-readiness/local-smoke.sh`
- Known gaps:
  - No production Supabase project was created or linked, and no remote migrations/functions/secrets/advisors were applied.
  - No production Google Cloud OAuth/Pub/Sub setup or hosted Gmail connector smoke was performed.
  - No Google Play Console/internal-test release was created.
  - The release APK smoke used placeholder Supabase values and debug signing fallback because real production project values and Android upload-key material were not provided.

## Milestone 12 Completion Notes

- Completed on 2026-06-07.
- User-confirmed AI choices:
  - Provider: `gemini`.
  - Model: `gemini-3.5-flash`.
  - Dev/staging budget posture: free-tier-only with zero paid spend cap.
  - Transaction metadata Suggest search: disabled for development, with the schema/function setting in place for later enablement.
- Added Supabase AI foundation:
  - `ai_feature_settings` for household AI provider/model/cap/feature flags.
  - `ai_usage_events` for token/cost/status logging.
  - `ai_jobs` for expense Q&A and transaction metadata suggestion job records.
  - RLS policies, explicit grants/revokes, security-invoker budget views, budget checks, and usage logging RPC.
- Added Gemini Edge Function support:
  - Shared `gemini.ts` REST helper using `generateContent`, usage metadata parsing, zero paid-cost default in free-tier mode, and optional `google_search` tool wiring.
  - `expense-qa` authenticated Edge Function that validates household budget access through RLS, retrieves scoped finance context, calls Gemini backend-only, records jobs/usage, and returns answer metadata.
  - `transaction-metadata-suggest` authenticated Edge Function that validates budget access, retrieves scoped transaction/review/taxonomy context, calls Gemini backend-only, and returns structured suggestions for explicit user save.
- Added Flutter AI UI:
  - Ask Expenses route in the authenticated shell.
  - AI budget/provider/status panel in Settings.
  - Metadata Suggest action in Review and Transactions; suggestions do not mutate transaction metadata automatically.
- Updated production/readiness tooling:
  - Edge Function secret templates include `GEMINI_API_KEY`, preflight cost, and optional paid-rate values.
  - Deployment script includes `expense-qa` and `transaction-metadata-suggest`.
  - Local smoke checks include Gemini helper tests and client-secret scans for `GEMINI_API_KEY`.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for Edge Function auth/RLS and API grants guidance
  - Google AI docs lookup for Gemini `generateContent`, usage metadata, pricing/free tier, and Google Search grounding
  - `supabase migration new ai_ready_layer_llm_features`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/ai_ready_layer.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `deno fmt --check supabase/functions`
  - `deno lint supabase/functions`
  - `deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts supabase/functions/tests/*.ts`
  - `deno test supabase/functions/tests/gemini.test.ts`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/ai/ai_screen.dart apps/mobile/lib/src/app/app_shell.dart apps/mobile/lib/src/app/router.dart apps/mobile/lib/src/features/settings/settings_screen.dart apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart apps/mobile/test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test test/finance_features_test.dart`
  - `flutter test`
- Known gaps:
  - Hosted dev/staging migrations were applied after milestone completion on 2026-06-08 to project `bslsitzdvrdosubbdxpd`.
  - `GEMINI_API_KEY` is present in hosted Edge Function secrets by name, and a local Gemini API smoke against `gemini-3.5-flash` passed using ignored `supabase/functions/env/staging.env`.
  - Hosted expense Q&A and the now-retired legacy AI lookup function were active, enforced JWT, and returned HTTP 200 in authenticated hosted smoke calls using the emulator app session.
  - The fake legacy AI lookup smoke suggestion was removed after validation. One zero-cost hosted expense Q&A usage/job record remains from the successful smoke.
  - Remote schema lint and performance advisor passed after the hosted migration push. Security advisor reports `auth_leaked_password_protection` as a warning; this is an Auth configuration hardening item, not an app schema or AI smoke failure.
  - Transaction metadata Suggest search remains disabled by default; enabling it later requires explicitly setting `transaction_metadata_suggestion_web_search_enabled = true` and confirming the current Gemini/Search billing posture.
  - No Android-device live AI smoke was exercised in this session.

## Milestone 13 Completion Notes

- Completed on 2026-06-08.
- Added `gmail-backfill-range`, a service-only Edge Function that validates one active Gmail mailbox with an OAuth secret and queues deterministic `gmail_backfill` jobs for explicit transaction-date slices.
- The May 2026 runbook body is:
  - `mailboxId`
  - `transactionStartDate = 2026-05-01`
  - `transactionEndDateExclusive = 2026-06-01`
  - `sliceDays = 1`
  - `maxCandidatesPerSlice = 200`
- Range jobs use idempotency keys like `manual-range:2026-05-01:2026-05-02`, store buffered Gmail search dates in payload, and do not duplicate completed or in-flight work.
- Updated `gmail-sync` so `gmail_backfill` jobs can pass Gmail search date bounds, optional query text, max candidate limits, and strict parsed transaction-date filters before calling `ingest_gmail_transaction`.
- Updated Gmail OAuth URL generation from `prompt=consent` to `prompt=consent select_account` so the user can choose a Gmail mailbox different from the app login account.
- Updated deployment tooling and local smoke coverage for `gmail-backfill-range`.
- Updated `docs/implementation-plan/GMAIL_CONNECTOR.md` and `docs/implementation-plan/MILESTONES.md` with the M13 runbook and completion scope.
- Hosted deployment:
  - `gmail-oauth-start` version 2, JWT verification enabled.
  - `gmail-sync` version 2, JWT verification disabled and service-key protected in code.
  - `gmail-backfill-range` version 1, JWT verification disabled and service-key protected in code.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md`
  - Supabase MCP docs search for Edge Function auth/testing/current secret-key behavior.
  - Google Gmail API docs lookup for `users.messages.list` query behavior and Gmail API search date syntax.
  - `supabase --version`
  - `supabase functions --help`
  - `supabase functions deploy --help`
  - `supabase db --help`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `node --check supabase/functions/_shared/parsers/gmail_parsers.mjs`
  - `deno fmt --check supabase/functions`
  - `deno lint supabase/functions`
  - `deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts`
  - `deno test supabase/functions/tests/*.ts`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - Local `supabase functions serve gmail-backfill-range --no-verify-jwt` smoke with a synthetic active mailbox.
  - Local `gmail-backfill-range` POST queued three one-day jobs for `2026-05-01` through `2026-05-04`; duplicate POST left three range jobs.
  - `tools/production-readiness/local-smoke.sh`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
  - `supabase functions deploy --project-ref bslsitzdvrdosubbdxpd gmail-oauth-start`
  - `supabase functions deploy --project-ref bslsitzdvrdosubbdxpd --no-verify-jwt gmail-sync gmail-backfill-range`
  - Supabase MCP `list_edge_functions`
  - Hosted `curl -i -X OPTIONS https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-backfill-range`
  - Hosted no-secret POST to `gmail-backfill-range` returned the expected Supabase secret-key error.
- Known gaps:
  - The live May 2026 Gmail backfill was not invoked in this implementation session because it requires the user to connect the target Gmail mailbox and use a Supabase secret key from a local or platform secret store.
  - No new parser templates were added. HDFC credit-card debit and HDFC Bank UPI debit remain the only supported M13 templates.
  - No iOS, web, production rollout, scheduling, or new parser expansion work was started.
- Assumptions made:
  - The handoff's 2026-06-08 confirmation of `bslsitzdvrdosubbdxpd` as dev/staging remains current for M13 deployment.
  - May means May 2026, with `2026-05-01 <= transaction_date < 2026-06-01`.
- Mocks created:
  - Synthetic local-only mailbox/profile/household rows for the `gmail-backfill-range` function smoke; cleaned up after the smoke.
- Mocks used:
  - Existing anonymized Gmail parser fixtures.
  - Synthetic local-only mailbox rows for function enqueue verification.

## Milestone 14 Completion Notes

- Completed on 2026-06-08.
- Added `create_household_category`, an authenticated `security invoker` RPC that creates a household category plus its first subcategory in one transaction.
- The RPC:
  - Requires the signed-in profile to have household write access.
  - Trims category and subcategory names.
  - Rejects blank category or subcategory names.
  - Rejects case-insensitive duplicate category names within the household.
  - Returns the created category and subcategory IDs/names for immediate Flutter selection.
- Added pgTAP coverage for successful creation, duplicate-name rejection, blank-name rejection, viewer rejection, and non-member rejection.
- Updated existing database tests whose fixtures assumed newly inserted households had no default taxonomy rows; they now account for automatic default-taxonomy hydration.
- Extended the Flutter finance repository with `CategoryCreationRequest`, `CategoryCreationResult`, and `createCategory`.
- Added a reusable category creation dialog and lookup-refresh helper.
- Added a Settings category manager card that lists categories/subcategories and creates new category/subcategory pairs.
- Added inline category creation from Merchant Review correction dialogs; newly created pairs are auto-selected for the correction.
- Added widget coverage for Settings category creation and Merchant Review inline category creation.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | sed -n '1,220p'`
  - Supabase MCP docs search for RPC/function grants and security-invoker guidance.
  - `supabase --version`
  - `supabase migration --help`
  - `supabase migration new create_household_category_rpc`
  - `dart format lib/src/data/repositories/finance_repository.dart lib/src/features/categories/category_creation_dialog.dart lib/src/features/merchant_review/merchant_review_screen.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart`
  - `flutter test test/finance_features_test.dart`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
  - `supabase migration list --local`
- Known gaps:
  - Hosted dev/staging migration push was not performed in this session.
  - No Android-emulator manual smoke was run.
  - Category rename, delete, reorder, merge, historical reclassification, and standalone subcategory management remain deferred taxonomy-admin work.
- Assumptions made:
  - The first in-app creation slice should create a category plus one initial subcategory together.
  - The creation entry points should be Settings and Merchant Review.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data.

## Milestone 15 Completion Notes

- Completed on 2026-06-09.
- Added `apply_transaction_metadata_correction`, an authenticated
  `security invoker` RPC for editing transaction classification metadata from
  both Review and Transactions.
- The RPC:
  - Requires the signed-in profile to have household write access.
  - Locks and validates the selected transaction in the target household.
  - Optionally validates an open review item for the selected transaction.
  - Trims and rejects blank merchant groups.
  - Validates category/subcategory ownership and relationship.
  - Upserts the canonical merchant and exact merchant alias for the selected
    normalized statement merchant.
  - Creates or updates the future exact merchant mapping rule with selected
    merchant/category/subcategory/confidence and notes.
  - Updates matching historical transactions for the same normalized statement
    merchant, including confidence, notes, and classification audit fields.
  - Resolves matching open review items and returns updated/resolved counts.
- Replaced the old SQL implementation of `apply_merchant_review_correction`
  with a compatibility wrapper around the new RPC.
- Extended Flutter transaction models with merchant and subcategory fields so
  transaction detail editing can prefill accurately.
- Added `TransactionMetadataCorrectionRequest` and
  `TransactionMetadataCorrectionResult` as the shared Flutter write contract.
- Added a shared transaction metadata editor used by Merchant Review and
  Transactions. It supports merchant group, category, subcategory, confidence,
  notes, inline category creation, save-disabled state, RPC errors through
  SnackBars, and a concise normalized-statement-merchant scope hint.
- Updated Merchant Review to save through the shared metadata editor and refresh
  review queue, dashboard, transactions, and trends.
- Updated Transactions detail bottom sheets with an Edit action that opens the
  shared editor and refreshes transactions, dashboard, trends, and review queue
  after success.
- Added pgTAP coverage for matching-row updates, future rule matching,
  confidence persistence, review resolution, invalid category/subcategory and
  blank merchant rejection, viewer rejection, and non-member rejection.
- Added Flutter widget coverage for Review edits, Review inline category
  creation through the shared editor, and Transactions detail edits.
- Verification run:
  - `curl -fsSL https://supabase.com/changelog.md | rg -n "breaking|RLS|Postgres|Edge Functions|Auth|Database|REST|RPC|security_invoker" -i | head -80`
  - Supabase MCP docs search for Postgres functions, security invoker, RLS, and
    RPC exposure guidance.
  - `supabase migration new transaction_metadata_editing`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `dart format apps/mobile/lib/src/features/transaction_metadata/transaction_metadata_editor.dart apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart apps/mobile/lib/src/features/transactions/transactions_screen.dart apps/mobile/test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test test/finance_features_test.dart`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `pnpm --dir tools/workbook-import test`
  - `flutter test`
  - `flutter build apk --debug --no-pub`
- Known gaps:
  - Hosted dev/staging migration push was not performed in this session.
  - No Android-emulator manual smoke was run.
  - Amount/date/source-account/raw-statement-merchant/source-fingerprint/Gmail
    metadata editing remains deferred.
  - Merchant-group-wide alias merging remains deferred; M15 applies only to the
    exact normalized statement merchant.
  - No iOS or web work was started.
- Assumptions made:
  - The existing `confidence` enum values are the editable confidence values:
    `manual`, `high`, `medium`, and `low`.
  - Notes entered in the editor should apply to matching transaction rows and
    the future mapping rule; existing canonical merchant notes are preserved
    when no new note is provided.
  - Review edits should continue to use the selected review item as the
    classification audit pointer for all matching rows resolved by that save.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data.
  - Local pgTAP fixture rows in `supabase/tests/transaction_metadata_editing.sql`.

## Milestone 16 Completion Notes

- Completed on 2026-06-09.
- Added `20260609093751_remove_merchant_research.sql`:
  - Renames `ai_feature_settings.merchant_research_enabled` to
    `transaction_metadata_suggestion_enabled`.
  - Renames `ai_feature_settings.merchant_research_web_search_enabled` to
    `transaction_metadata_suggestion_web_search_enabled`.
  - Recreates `v_ai_budget_status`, `ensure_ai_feature_settings`, and
    `check_ai_budget` with transaction metadata Suggest naming.
  - Rejects `merchant_research` through `check_ai_budget`.
  - Replaces the `ai_jobs` type check with a non-valid constraint that blocks
    new rows while preserving any historical audit rows.
  - Drops the old suggestion cache view, RPC, and table.
- Removed the obsolete `supabase/functions/merchant-research` Edge Function.
- Kept `transaction-metadata-suggest` and wired
  `webSearchEnabled: budget.web_search_enabled` into the Gemini call.
- Removed Flutter merchant research request/suggestion models, providers,
  repository methods, fake repository fields, and stale test hooks.
- Renamed app AI labels to metadata Suggest/search wording.
- Updated deployment tooling:
  - `deploy-edge-functions.sh` no longer deploys the retired function.
  - The script idempotently deletes the retired hosted function when present.
- Hosted dev/staging state:
  - Deleted the retired hosted function from project `bslsitzdvrdosubbdxpd`.
  - Verified with `supabase functions list --project-ref bslsitzdvrdosubbdxpd`
    that the function is absent and `transaction-metadata-suggest` remains
    active.
- Verification run:
  - Supabase changelog/docs check for current CLI migration/function-delete
    behavior.
  - `supabase --version`
  - `supabase functions delete --help`
  - `supabase migration new remove_merchant_research`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/ai/ai_screen.dart apps/mobile/lib/src/features/settings/settings_screen.dart apps/mobile/test/finance_features_test.dart`
  - `deno fmt supabase/functions/transaction-metadata-suggest/index.ts supabase/functions/tests/gemini.test.ts supabase/functions/tests/transaction_metadata_suggest.test.ts`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/ai_ready_layer.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `deno fmt --check supabase/functions`
  - `deno lint supabase/functions`
  - `deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts supabase/functions/tests/*.ts`
  - `deno test supabase/functions/tests/gemini.test.ts supabase/functions/tests/transaction_metadata_suggest.test.ts`
  - `flutter analyze`
  - `flutter test test/finance_features_test.dart`
  - `flutter test`
  - `bash -n tools/production-readiness/deploy-edge-functions.sh`
  - `rg -n "merchant-research|merchant_research|merchantResearch|MerchantResearch|merchant research" .`
  - `supabase functions delete --project-ref bslsitzdvrdosubbdxpd merchant-research`
  - `supabase functions list --project-ref bslsitzdvrdosubbdxpd`
- Known gaps:
  - The M16 database migration was not pushed to hosted dev/staging in this
    session.
  - The updated active `transaction-metadata-suggest` function was not deployed
    to hosted dev/staging in this session.
  - No Android-emulator manual smoke was run.
  - Cleanup `rg` still reports expected references in historical migrations,
    the retirement migration, explicit negative tests, the hosted delete step,
    and the audit-history data-model note.
- Assumptions made:
  - Historical `merchant_research` `ai_jobs` and `ai_usage_events` rows should
    remain as audit logs.
  - Transaction metadata Suggest is the active replacement path.
  - Suggest web search remains opt-in and disabled by default.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data.
