# Session Handoff

Use this file to coordinate work across multiple implementation sessions. Update it whenever a milestone starts, completes, or materially changes.

## Current Status

- Current milestone: Not started.
- Last completed milestone: Milestone 11, Deployment, Security, and Production Readiness.
- Current implementation state: Flutter Android app scaffold exists in `apps/mobile` with SpendLens Google sign-in, route protection, authenticated shell, RLS-safe profile/default-household bootstrap, household loading/error states, sign-out, package `com.olympus.spendlens`, core packages, environment templates, tests, and Supabase folder structure. Supabase local config applies migrations for schema, RLS, views, workbook-derived default categories, merchant review corrections, piggy-bank entry validation, Gmail connector ingestion, production-readiness monitoring views, pgTAP database tests, and the Android auth redirect URL. Milestone 3 adds a local workbook importer under `tools/workbook-import`, fixture tests, and rerun documentation in `docs/implementation-plan/WORKBOOK_IMPORT.md`. Milestone 5 adds Supabase-backed finance repository reads/writes, dashboard KPIs, reporting-month selection, monthly category cap setup/editing, category and merchant summaries, transaction search/filter pagination, and transaction detail panels. Milestone 6 adds merchant review queue UI, correction RPC/rule persistence, historical reclassification, review resolution, transaction classification audit metadata, and future-import rule application. Milestone 7 adds Supabase-backed piggy-bank list/detail UI, create/edit forms, ledger entry creation, ledger-derived balance/progress reads, no-overdraft withdrawal validation, and regression tests. Milestone 8 adds filtered monthly trend reports, gross/refund/net reporting, category trend tables, merchant summary tables, and filtered transaction CSV copy from the Trends screen. Milestone 9 adds Vault-backed Gmail OAuth connector state, Pub/Sub webhook job dedupe, Gmail sync/backfill/watch-renewal Edge Functions, HDFC credit-card debit parsing from anonymized fixtures, SQL ingestion RPCs, and Settings connector status/connect/disconnect UI. Milestone 10 adds HDFC Bank UPI debit parsing from anonymized fixtures, UPI-aware Gmail backfill search and fingerprinting, UPI ingestion pgTAP coverage, and source-type filters for credit card vs UPI on transaction/trend screens. Milestone 11 adds production-readiness runbooks, local smoke automation, service-role ingestion/parser health views, structured Edge Function operational logs, Android release signing/shrinking configuration, and staging/production Edge Function secret templates.
- Next recommended milestone: Milestone 12, AI-Ready Layer and LLM Features.

## Required Reading for New Threads

At the start of a new implementation thread, read:

1. `docs/implementation-plan/README.md`
2. `docs/implementation-plan/ARCHITECTURE.md`
3. `docs/implementation-plan/DATA_MODEL.md`
4. `docs/implementation-plan/INGESTION.md`
5. The target milestone section in `docs/implementation-plan/MILESTONES.md`
6. This handoff file

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
- Raw email bodies are not retained by default.
- LLM features are future milestones and must be backend-mediated.

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
- Milestone 12: LLM provider account, API key, and monthly AI budget cap.

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
- Milestone 12, AI-Ready Layer and LLM Features: pending.

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
