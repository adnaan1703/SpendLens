# Session Handoff

Use this file to coordinate work across multiple implementation sessions. Update it whenever a milestone starts, completes, or materially changes.

## Current Status

- Current milestone: None. Milestone 69 was completed on 2026-06-16 as the
  Gmail Label Ingestion Regression, Docs, and Cleanup closeout. Milestones
  18-21 remain deferred by user request.
- Last completed milestone: Milestone 69, Gmail Label Ingestion Regression,
  Docs, and Cleanup.
- Current implementation state: Flutter Android app scaffold exists in
  `apps/mobile` with redesigned SpendLens Google sign-in, route protection,
  authenticated shell, RLS-safe profile/default-household bootstrap,
  redesigned household loading/error states, sign-out, package
  `com.olympus.spendlens`, core
  packages, environment templates, tests, and Supabase folder structure.
  Supabase local config applies migrations for schema, RLS, views,
  workbook-derived default categories, merchant review corrections,
  piggy-bank entry validation, Gmail connector ingestion, production-readiness
  monitoring views, AI feature settings/usage/jobs/transaction metadata
  suggestions, pgTAP database tests, and the Android auth redirect URL.
  Milestone 3 adds a local workbook importer under `tools/workbook-import`,
  fixture tests, and rerun documentation in
  `docs/implementation-plan/WORKBOOK_IMPORT.md`. Milestone 5 adds
  Supabase-backed finance repository reads/writes, dashboard KPIs,
  reporting-month selection, monthly category cap setup/editing, category and
  merchant summaries, transaction search/filter pagination, and transaction
  detail panels. Milestone 6 adds merchant review queue UI, correction
  RPC/rule persistence, historical reclassification, review resolution,
  transaction classification audit metadata, and future-import rule
  application. Milestone 7 adds Supabase-backed piggy-bank list/detail UI,
  create/edit forms, ledger entry creation, ledger-derived balance/progress
  reads, no-overdraft withdrawal validation, and regression tests. Milestone 8
  adds filtered monthly trend reports, gross/refund/net reporting, category
  trend tables, merchant summary tables, and filtered transaction CSV copy from
  the Trends screen. Milestone 9 adds Vault-backed Gmail OAuth connector state,
  Pub/Sub webhook job dedupe, Gmail sync/backfill/watch-renewal Edge Functions,
  HDFC credit-card debit parsing from anonymized fixtures, SQL ingestion RPCs,
  and Settings connector status/connect/disconnect UI. Milestone 10 adds HDFC
  Bank UPI debit parsing from anonymized fixtures, UPI-aware Gmail backfill
  search and fingerprinting, UPI ingestion pgTAP coverage, and source-type
  filters for credit card vs UPI on transaction/trend screens. Milestone 11
  adds production-readiness runbooks, local smoke automation, service-role
  ingestion/parser health views, structured Edge Function operational logs,
  Android release signing/shrinking configuration, and staging/production Edge
  Function secret templates. Milestone 12 adds Gemini-backed expense Q&A,
  transaction metadata suggestions, AI usage/budget status, backend-only LLM
  calls, and free-tier-only dev/staging controls. Milestone 13 adds a
  service-only May 2026 Gmail range backfill function, range-aware Gmail sync
  search/date filtering, OAuth account selection for mailbox choice,
  deployment tooling updates, and a hosted dev/staging runbook. Milestone 14
  adds authenticated in-app creation of a category plus first subcategory from
  Settings and Merchant Review through an RLS-safe `create_household_category`
  RPC. Milestone 15 adds authenticated transaction metadata editing from Review
  and Transactions through an RLS-safe `apply_transaction_metadata_correction`
  RPC, a shared Flutter metadata editor, confidence editing, exact normalized
  merchant reclassification, future mapping-rule updates, and regression
  coverage. Milestone 16 retires the legacy AI lookup path, keeps expense Q&A
  plus transaction metadata Suggest, renames Suggest budget/search flags,
  removes the obsolete Edge Function and Flutter models, and keeps historical
  AI audit rows. Milestone 17 adds shared All dates/month/custom period filters
  to Transactions and Trends, backed by available reporting months from
  `v_monthly_spend` and mapped onto the existing `startDate`/`endDate` query
  fields. Milestone 22 replaces the compact Settings category list with a
  grouped category manager, category/subcategory usage snapshots, selected
  recent transaction previews, and rename/add taxonomy editing through an
  RLS-safe `update_household_category_taxonomy` RPC. Milestone 23 adds RLS-safe
  category/subcategory deletion with Review requeue, guarded direct DELETE
  policies for already-unused taxonomy only, delete confirmation impact
  previews, and regression coverage. Milestone 24 adds RLS-safe category merge
  with explicit source subcategory mapping, destination subcategory creation,
  taxonomy reference repointing, cap merging, Settings merge UI, and regression
  coverage. Milestone 25 adds category-management regression/docs cleanup with
  Settings category-detail transaction drilldown, empty/error/narrow viewport
  polish, focused Settings tests, and durable final behavior docs. Milestone 26
  adds household-scoped label tables, RLS, authenticated grants, a label usage
  view, app-facing label RPCs, repository label models/methods, transaction
  label hydration/filter support, and focused pgTAP/Flutter repository
  contract tests. Milestone 27 adds transaction-list/detail label chips,
  one-transaction label editing, inline label creation/removal, provider refresh
  after saves, and a single-label Transactions filter. Milestone 28 adds
  Settings label vocabulary management with create, rename, delete, usage
  counts, delete impact confirmation, active deleted-label filter clearing, and
  regression coverage. Milestone 29 adds named monthly-cap tables with
  category/label targets, RLS, RPC-backed upsert/delete, progress views,
  category/label dependency cleanup, repository contracts, and regression
  tests. Milestone 30 adds Dashboard multi-target cap create/edit/delete UX for
  category-only, label-only, and mixed caps, progress rows with target chips,
  and regression coverage while preserving top category/merchant drilldowns.
  Milestone 31 hardens monthly-cap regression coverage, removes remaining active
  category-only Dashboard copy/helpers, and folds final cap behavior into
  durable docs. Milestone 32 adds stable recurring cap series,
  month-effective versions, versioned category/label targets, exact-month
  recurring progress, cap-driven available months, and selected-month-forward
  edit/delete semantics. Milestone 33 adds Postgres-derived positive/negative
  carry-forward progress semantics for recurring caps, including chained months,
  disabled carry-forward resets, selected-month amount/target edits, refunds,
  bill payments, and Flutter model parsing coverage. Milestone 34 adds visible
  Dashboard carry-forward treatment with create/edit toggles,
  selected-month-forward copy, base/carried/available cap progress rows,
  focused widget coverage, and preserved cap workflows/drilldowns. Milestone 35
  hardens recurring-cap regression coverage, removes remaining active
  one-month-only Dashboard copy, and folds final recurring/carry-forward
  behavior into durable docs. Milestone 36 adds the UI redesign companion plan,
  records the Stitch reference bundle, and plans Milestones 37-51 for
  DESIGN.md-based theming, four-tab navigation, Activity consolidation, Vaults,
  focused Settings, and full UI regression. Milestone 37 replaces the seed
  theme with centralized DESIGN.md tokens, explicit light/dark `ThemeData`,
  local system/light/dark theme-mode persistence through shared preferences,
  `MaterialApp.router` theme wiring, and focused theme regression tests.
  Milestone 38 adds DESIGN.md-aware shared responsive UI primitives, including
  breakpoint helpers, responsive page scaffolding, display and section
  headings, content/feature/modal card shells, metric cards, filter/status/icon
  chips, large amount text, action pills, loading/error states, a shared
  primitive barrel export, and focused primitive tests. Milestone 39 adds the
  authenticated Activity route at `/activity`, replaces primary shell
  destinations with Dashboard, Activity, Review, and Vaults, moves Settings to
  a global shell gear action, removes active `/transactions` and `/trends` app
  routes, and retargets Dashboard and Settings drilldowns to Activity while
  preserving existing transaction query semantics. Milestone 40 rebuilds
  Dashboard around the Stitch hierarchy with a compact month pill, Spending net
  and month-change cards, Review queue card, compact Monthly caps progress
  rows, and top category/merchant cards while preserving cap workflows,
  carry-forward display, and Activity drilldowns. Milestone 41 adds Activity's
  List/Charts mode selector with List as the default, moves the existing
  transaction search/filter/pagination behavior under Activity List, restyles
  filters as pill-like responsive controls, and presents transactions as large
  rounded cards with icon chips, metadata, amounts, labels, and preserved detail
  edit entry points. Milestone 42 replaces the Activity Charts placeholder with
  the existing Trends report behavior inside Activity, preserving trend filters
  and CSV copy while reshaping the visible report into gross/refunds/net cards,
  a Monthly Net Spend chart, a Gross/Refunds/Net monthly table, and a Category
  Trend card. Milestone 43 restyles transaction details as a focused
  M38-modal-based surface with close affordance, centered merchant/date/amount,
  transaction type/status pill, responsive divider rows, and preserved
  metadata and label edit entry points. Milestone 44 restyles the shared
  transaction metadata editor as a constrained modal card with outlined
  merchant/category/subcategory/confidence/notes controls, inline category
  creation, explanatory copy, responsive actions, preserved Suggest/Save
  behavior, and focused Activity/Review/narrow-viewport regression coverage.
  Milestone 45 rebuilds Review around the Stitch queue-card hierarchy with
  redesigned metric cards, Gmail parse failure diagnostics, warning-rail queue
  cards, classification/confidence chips, full-width Resolve actions, lazy
  queue rendering, loading/error/caught-up states, and preserved metadata
  editor correction behavior. Milestone 46 restyles the existing Piggy Banks
  route as the visible Vaults destination with Vaults copy, New Vault action,
  active-ledger and total-balance summary cards, selected-vault hero card,
  compact deposit, withdraw, and adjust actions, current-balance,
  target-progress, and remaining cards, redesigned empty/timeline entry states,
  and preserved piggy-bank repository and ledger behavior.
  Milestone 47 rebuilds Settings as a focused non-tab route with Back
  affordance, focused Account & Runtime, Theme, Categories, Labels, Gmail
  Importer, AI Core, and System Environment cards, hides primary shell
  navigation while Settings is active, wires System default/Light/Dark theme
  selection to the local M37 theme-mode controller, and preserves existing
  Settings management flows and Activity drilldowns.
  Milestone 48 restyles sign-in as a DESIGN.md auth card on the sage canvas,
  restyles household loading and error gates as responsive redesigned entry
  states, preserves Supabase readiness messaging, Google sign-in, route guards,
  retry, and sign-out behavior, and adds focused light/dark/system gate
  coverage.
  Milestone 49 restyles the non-primary Ask route with DESIGN.md card, input,
  action, status, loading, error, and result primitives while preserving prompt
  input, backend-mediated expense Q&A, AI budget semantics, provider
  invalidation after calls, and direct `/ask` route reachability outside the
  four primary tabs.
  Milestone 50 normalizes remaining redesigned shared surfaces by adding
  reduced-motion-aware modal, entrance, and press-scale primitives, restyling
  category, label, cap, transaction-label, taxonomy, merge/delete, and vault
  forms/dialogs/sheets, theming floating snackbars, adding low-cost segmented
  and empty/loading-state motion, and fixing long-modal action layout while
  preserving existing product and repository behavior.
  Milestone 51 adds final responsive/theme regression coverage across the
  redesigned shell, core authenticated surfaces, sign-in, household gates,
  transaction details, and metadata editor; fixes a Dashboard desktop
  spending-card layout regression; and folds final UI behavior into durable
  docs. Milestone 52 added the owner-only Postgres transaction deletion
  contract: `public.deleted_transaction_sources`, a delete tombstone trigger,
  owner-only authenticated direct delete policy, the `delete_transaction` RPC,
  and focused pgTAP coverage for cascade/unlink, spend-summary, monthly-cap,
  tombstone, and direct-delete RLS behavior. Milestone 53 adds workbook/Gmail
  resurrection suppression by consulting source tombstones before transaction
  upserts, adjusting workbook importer validation/reporting for suppressed rows,
  returning sanitized suppressed Gmail ingestion results, and treating those
  Gmail parses as handled work. Milestone 54 adds owner-only Activity
  transaction delete UX through the existing `delete_transaction` RPC,
  destructive confirmation copy, successful provider refreshes, in-place RPC
  error handling, page-back behavior for empty pages, and focused Flutter
  coverage for owner/non-owner visibility, cancel/confirm/error, list removal,
  and narrow layout behavior. Milestone 55 completed the final local deletion
  regression pass across Supabase, workbook importer, Edge Functions, Flutter
  tests, and Android debug build, then folded the final behavior into durable
  docs. Milestone 56 added the merchant autocomplete companion plan and queued
  Milestones 57-60. Milestone 57 added Activity canonical merchant filtering
  with one visible merchant search/autocomplete control, repository
  `merchantId` filtering precedence, and preserved free-text statement merchant
  route/search behavior. Milestone 58 added shared transaction metadata editor
  autocomplete for Activity detail edit and Review resolve flows, including
  compatible category/subcategory selection from existing merchant options while
  preserving freeform merchant names and Suggest behavior. Milestone 59 added a
  deterministic client-side close-match guard for metadata editor saves,
  canonicalizes exact existing names, prompts on clear typo-level matches, and
  preserves freeform new merchant entry. Milestone 60 verified the final
  Activity, Review, transaction detail edit, close-match, existing-search, and
  narrow-layout behavior through focused and full Flutter checks, found no
  regressions, required no schema or RPC migration, and folded the completed
  behavior into durable docs. Milestone 61 added the merchant group management
  companion plan and queued Milestones 62-64 for Settings-based canonical
  merchant group rename, merge, category strategy selection, provider refresh,
  regression, and docs cleanup. Milestone 62 added the RLS-safe merchant group
  usage view, rename RPC, merge RPC, pgTAP coverage, Flutter repository
  contract/models/provider, fake repository hooks, and canonical Dashboard
  top-merchant grouping. Milestone 63 added the visible Settings Merchant groups
  section with rename, merge, explicit category strategy selection, impact
  summaries, provider refreshes, and narrow/long-name widget coverage.
  Milestone 64 completed the final local merchant group regression pass, folded
  final behavior into durable docs, confirmed Settings rename/merge writes stay
  RPC-backed, and marked the companion plan completed-only. Milestone 65 added
  the Gmail label ingestion companion plan. Milestone 66 completed readonly
  `Banking/HDFC Transactions` label watch/backfill discovery, watched-label
  mailbox storage, and label-filtered history/backfill/thread processing.
  Milestone 67 added body-first Gmail parser routing, HDFC Netbanking IMPS
  parsing, `netbanking_imps` source/candidate support, sanitized `other`
  watched-label parse failures, and IMPS source-reference fingerprinting.
  Milestone 68 added persistent household-wide `Ignore for now` handling for
  visible sanitized Review parse failures while preserving service-only
  diagnostics. Milestone 69 verified the complete local Gmail label ingestion
  regression path, folded final runbook/privacy behavior into durable docs, and
  marked the companion plan completed-only.
  Milestones 18-21 remain planned and deferred by user request.
- Remote deployment state: On 2026-06-08, user confirmed Supabase project `bslsitzdvrdosubbdxpd` as the intended dev/staging target. All local migrations through `20260607174515_ai_ready_layer_llm_features.sql` were pushed there, hosted expense Q&A and the now-retired legacy AI lookup function were active with JWT verification, and `GEMINI_API_KEY` was present in hosted Edge Function secrets by name. After the user signed in through the Android emulator, hosted profile/household bootstrap and authenticated Gemini Edge Function smoke passed. On 2026-06-08 for Milestone 13, `gmail-oauth-start` was deployed as version 2 with JWT verification, `gmail-sync` was deployed as version 2 without JWT verification, and new `gmail-backfill-range` was deployed as version 1 without JWT verification. Hosted `gmail-backfill-range` `OPTIONS` smoke returned 200, and an unauthenticated POST returned the expected service-key error. The live May Gmail backfill itself was not run because it requires the user to connect the target Gmail mailbox and invoke the runbook with a Supabase secret key from a local/platform secret store. On 2026-06-09, M16 deleted the hosted legacy AI lookup function from `bslsitzdvrdosubbdxpd` and a follow-up function list verified it absent. The M16 database migration and updated active Suggest function were verified locally but not pushed/deployed to hosted in this implementation session.
- Next recommended milestone: None in the active non-deferred plan. Milestones
  18-21 remain deferred unless the user resumes push notifications; iOS and web
  remain deferred future milestones unless explicitly resumed. If continuing
  hosted rollout separately, push currently local-only migrations and deploy the
  relevant updated Edge Functions in a separate hosted rollout.
- Documentation state: completed-only companion execution plans for transaction
  metadata editing and category management were retired from `docs/` on
  2026-06-12. `docs/implementation-plan/MONTHLY_CAPS.md` remains active as the
  companion plan for completed Milestones 29-35.
  `docs/implementation-plan/UI_REDESIGN.md` is the active companion plan for
  completed Milestones 37-51.
  `docs/implementation-plan/TRANSACTION_DELETION.md` is completed-only after
  completed Milestones 52-55 and can be removed in a later cleanup if the
  repository's completed-plan convention calls for it.
  `docs/implementation-plan/MERCHANT_AUTOCOMPLETE.md` is completed-only after
  completed Milestones 56-60 and can be removed in a later cleanup if the
  repository's completed-plan convention calls for it.
  `docs/implementation-plan/MERCHANT_GROUP_MANAGEMENT.md` is completed-only
  after completed Milestones 61-64 and can be removed in a later cleanup if the
  repository's completed-plan convention calls for it.
  `docs/implementation-plan/GMAIL_LABEL_INGESTION.md` is completed-only after
  completed Milestones 65-69 and can be removed in a later cleanup if the
  repository's completed-plan convention calls for it.

## Required Reading for New Threads

At the start of a new implementation thread, read:

1. `docs/implementation-plan/README.md`
2. `docs/implementation-plan/ARCHITECTURE.md`
3. `docs/implementation-plan/DATA_MODEL.md`
4. `docs/implementation-plan/INGESTION.md`
5. The target milestone section in `docs/implementation-plan/MILESTONES.md`
6. `docs/implementation-plan/GMAIL_LABEL_INGESTION.md` as completed reference
   material when touching label-based Gmail ingestion behavior
7. `docs/implementation-plan/PUSH_NOTIFICATIONS.md` when executing Milestone 18, 19, 20, or 21
8. `docs/implementation-plan/TRANSACTION_LABELS.md` when executing Milestone 26, 27, or 28
9. `docs/implementation-plan/MONTHLY_CAPS.md` when executing Milestone 29, 30, 31, 32, 33, 34, or 35
10. `docs/implementation-plan/UI_REDESIGN.md` when executing Milestone 37 through 51
11. `docs/implementation-plan/TRANSACTION_DELETION.md` when executing Milestone 52 through 55
12. `docs/implementation-plan/MERCHANT_AUTOCOMPLETE.md` when touching merchant
    search/autocomplete or metadata-editor duplicate guarding
13. `docs/implementation-plan/MERCHANT_GROUP_MANAGEMENT.md` when touching
    merchant group rename/merge behavior
14. `DESIGN.md` when executing Milestone 37 through 51
15. `docs/design-references/stitch/themed-dashboard-ui-redesign/README.md` when executing Milestone 37 through 51
16. This handoff file

## Current Assumptions

- Flutter will be used for Android first.
- iOS app work is deferred and not part of the current implementation plan.
- Web interface work is deferred and not part of the current implementation plan.
- Supabase is the v1 backend platform.
- Architecture is serverless-first, not backend-less.
- Gmail ingestion starts with Gmail API watch plus Pub/Sub.
- Gmail label ingestion for Milestones 66-69 must keep the
  `https://www.googleapis.com/auth/gmail.readonly` scope. The watched Gmail
  label is `Banking/HDFC Transactions`, shown in the Gmail UI as `HDFC
  Transactions` under `Banking`; archived/non-Inbox mail with that label is in
  scope. Milestone 66 stores the resolved label id/name on `linked_mailboxes` and
  active sync/backfill uses that label id rather than `INBOX`.
- Gmail parser routing is body-first as of Milestone 67. Sender and subject are
  diagnostics, not parser selectors. Unmatched watched-label mail is recorded as
  sanitized candidate type `other`; Milestone 68 added household-wide
  `Ignore for now` behavior while preserving service-only diagnostics.
- `Netbanking :: IMPS` is implemented as Gmail/source candidate type
  `netbanking_imps`; it is not category taxonomy and does not replace ledger
  `transaction_type` values such as `debit_spend`.
- Monthly caps use required named cap rows with category and/or label targets.
  A transaction matches a cap when any selected category or label target matches,
  counts once within that cap, and may count toward other overlapping caps.
  Legacy `category_caps` remains as migrated history only, and
  `v_budget_progress` remains as a category-only compatibility view.
- Piggy banks are manual ledgers.
- Merchant corrections apply to past and future matching transactions.
- Transaction metadata edits should apply to matching past transactions and the
  future exact mapping rule for the edited normalized statement merchant; they
  are not merchant-group-wide alias merges unless the user explicitly expands
  scope.
- Merchant autocomplete should use existing canonical household merchant
  display names for suggestions. Activity suggestion selection should filter by
  `merchant_id`; free typing should preserve existing statement merchant text
  search. Save-time close-match confirmation should compare merchant group
  display names only, not aliases or raw statement merchant strings.
- Settings merchant group management is implemented through Milestone 64 and
  uses existing `public.merchants` rows as canonical merchant groups. Rename
  preserves merchant ids. Merge moves aliases, mapping rules, transactions, and
  open review suggested merchant references to one destination merchant. Merge
  category handling is explicit: preserve current category fields or apply the
  destination merchant category/subcategory. Statement-merchant-level
  reassignment, alias editing, merchant deletion, hosted rollout, iOS, web, and
  push notifications are out of scope unless the user expands scope.
- Raw email bodies are not retained by default.
- LLM features are backend-mediated through Supabase Edge Functions.
- In-app category creation creates a category plus its first subcategory
  together. Category management is implemented through M25: rename/add
  preserves IDs, deletion requeues affected transactions for Review, merge
  requires explicit subcategory mapping, and Settings category detail can open
  Transactions with the selected category filter applied.
- Transaction labels are implemented through M28 as household-shared reusable
  labels attached to individual transaction rows. Labels are separate from
  category taxonomy and merchant mappings; label edits do not reclassify
  transactions, affect future imports, or send transactions to Review. Settings
  manages the shared label vocabulary with usage counts and delete-with-detach
  confirmation.
- Transaction deletion is implemented through M55 as an owner-only hard delete
  from Activity. Deleted transaction rows stop contributing to monthly spend,
  merchant spend, trends, labels, review, and monthly caps. A minimal source
  tombstone prevents the same workbook row or Gmail email from recreating the
  deleted transaction, while linked Vault entries and service diagnostics remain
  preserved but unlinked.
- Multi-target monthly caps require names. Caps may target categories, labels,
  or both; a transaction matches a cap when any selected category or label
  matches; one transaction counts once inside one cap; overlapping caps are
  allowed. Recurring cap series are implemented: edits and deletes apply from
  the selected month forward, and optional carry-forward can move a
  positive or negative prior-month remainder into the next month.
- Android push notifications use Firebase Cloud Messaging for delivery and
  Supabase for device registration, preferences, outbox state, delivery state,
  and service-key protected dispatch.
- Push notifications default to showing merchant and amount details, with an
  in-app preference to hide those details.
- UI redesign uses `DESIGN.md` as the design-system source of truth and the
  stored Stitch export as reference material only. The planned primary
  navigation is Dashboard, Activity, Review, and Vaults. Activity replaces
  separate Transactions and Trends routes. Settings becomes a focused non-tab
  route opened from a global settings action. Theme mode supports System
  default, Light, and Dark, defaults to System default, and persists locally on
  device.

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
- Milestone 18: Firebase project and Android app configuration for package
  `com.olympus.spendlens`; user must confirm whether the generated Android
  Firebase config may be committed.
- Milestone 20: FCM service account JSON stored only in Supabase Edge Function
  secrets or an ignored local env file as `FCM_SERVICE_ACCOUNT_JSON`.
- Milestone 66: The connected Gmail mailbox must have the nested Gmail label
  `Banking/HDFC Transactions` before label watch/backfill setup can succeed.

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
- Milestone 16, Merchant Research Retirement: completed.
- Milestone 17, Transaction and Trend Month Filter: completed.
- Milestone 18, Firebase Client and Device Registration: planned; deferred by
  user request on 2026-06-11.
- Milestone 19, Notification Outbox and Transaction Enqueue Contract: planned;
  deferred by user request on 2026-06-11.
- Milestone 20, FCM Dispatcher Edge Function: planned; deferred by user request
  on 2026-06-11.
- Milestone 21, End-to-End UX, Observability, and Runbooks: planned; deferred
  by user request on 2026-06-11.
- Milestone 22, Category Manager Foundation and Usage Preview: completed.
- Milestone 23, Taxonomy Delete and Review Requeue: completed.
- Milestone 24, Category Merge with Explicit Subcategory Mapping: completed.
- Milestone 25, Category Management Regression, Docs, and Cleanup: completed.
- Milestone 26, Labels Data Model and Repository Foundation: completed.
- Milestone 27, Transaction Labeling UX: completed.
- Milestone 28, Settings Label Manager and Regression: completed.
- Milestone 29, Monthly Cap Data Model and Repository Foundation: completed.
- Milestone 30, Dashboard Multi-Target Cap UX: completed.
- Milestone 31, Monthly Caps Regression, Docs, and Cleanup: completed.
- Milestone 32, Recurring Cap Series Foundation: completed.
- Milestone 33, Carry-Forward Progress Semantics: completed.
- Milestone 34, Dashboard Carry-Forward UX: completed.
- Milestone 35, Recurring Caps Regression, Docs, and Cleanup: completed.
- Milestone 36, UI Redesign Planning and Reference Readiness: completed.
- Milestone 37, UI Design Tokens, Themes, and Theme Preference: completed.
- Milestone 38, Shared Responsive UI Primitives: completed.
- Milestone 39, App Shell, Navigation IA, and Routes: completed.
- Milestone 40, Dashboard Redesign: completed.
- Milestone 41, Activity List Mode: completed.
- Milestone 42, Activity Charts Mode: completed.
- Milestone 43, Transaction Details Redesign: completed.
- Milestone 44, Transaction Metadata Editor Redesign: completed.
- Milestone 45, Review Redesign: completed.
- Milestone 46, Vaults Redesign: completed.
- Milestone 47, Settings Focused Screen and Theme Selector: completed.
- Milestone 48, Sign-In and Household Gate Redesign: completed.
- Milestone 49, Ask / AI Redesign: completed.
- Milestone 50, Dialogs, Forms, Empty States, and Motion Pass: completed.
- Milestone 51, UI Redesign Final Regression, Responsive QA, and Docs Closeout:
  completed.
- Milestone 52, Transaction Delete Database Contract: completed.
- Milestone 53, Import Resurrection Guard: completed.
- Milestone 54, Activity Transaction Delete UX: completed.
- Milestone 55, Transaction Deletion Regression, Docs, and Cleanup: completed.
- Milestone 56, Merchant Autocomplete Planning and Reference Readiness:
  completed.
- Milestone 57, Merchant Repository and Activity Filter Foundation: completed.
- Milestone 58, Shared Merchant Autocomplete in Metadata Editor: completed.
- Milestone 59, Close-Match Merchant Save Confirmation: completed.
- Milestone 60, Merchant Autocomplete Regression, Docs, and Cleanup: completed.
- Milestone 61, Merchant Group Management Planning and Reference Readiness:
  completed.
- Milestone 62, Merchant Group Data and Repository Contract: completed.
- Milestone 63, Settings Merchant Group Manager UX: completed.
- Milestone 64, Merchant Group Management Regression, Docs, and Cleanup:
  completed.
- Milestone 65, Gmail Label Ingestion Planning and Reference Readiness:
  completed.
- Milestone 66, Gmail Label Watch and Backfill Contract: completed.
- Milestone 67, Body-First Parser Registry and Netbanking IMPS Parser:
  completed.
- Milestone 68, Watched-Label Parse Failures and Review Ignore: completed.
- Milestone 69, Gmail Label Ingestion Regression, Docs, and Cleanup:
  completed.

## Gmail Label Ingestion M69 Notes

- Completed on 2026-06-16. Milestones 18-21 remained deferred and were not
  started. No later milestone work was started.
- Ran the full local Gmail label ingestion regression path. No runtime code,
  Supabase migration, SQL test, importer, Edge Function, hosted rollout, iOS,
  web, or push notification changes were required.
- Confirmed final behavior is durable in docs: readonly
  `Banking/HDFC Transactions` label watch/backfill, body-first parser routing,
  `Netbanking :: IMPS`, sanitized watched-label parse failures, Review
  `Ignore for now`, service-only diagnostics, no raw body retention, and
  production runbook expectations.
- Marked `docs/implementation-plan/GMAIL_LABEL_INGESTION.md` completed-only
  after completed Milestones 65-69.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `deno test --allow-env --allow-net supabase/functions/tests/google.test.ts`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Settings|Activity"`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - M66-M68 already implemented the intended runtime behavior; M69 only needed
    verification and documentation closeout after regression passed.
  - The watched Gmail label remains exactly `Banking/HDFC Transactions`, and
    Gmail OAuth remains readonly.
  - Hosted rollout remains a separate explicit operation.
- Mocks created:
  - None.
- Mocks used:
  - Existing Gmail API stubs in Edge Function tests and existing fake Flutter
    finance repository hooks for Review parse-failure coverage.

## Gmail Label Ingestion M66 Notes

- Completed on 2026-06-16. Milestones 18-21 remained deferred and were not
  started. Milestones 67-69 were not started.
- Added `20260616120838_gmail_label_ingestion_contract.sql` with watched Gmail
  label id/name/resolution fields on `linked_mailboxes`, connector status view
  exposure, and a service-role `upsert_gmail_mailbox(...)` contract that requires
  the resolved `Banking/HDFC Transactions` label.
- Updated Gmail Edge Function helpers to list Gmail labels, resolve the exact
  watched label, configure Gmail watch with that label id, request watched-label
  history for both message and label-added changes, and list backfill candidates
  by watched label plus date bounds.
- Updated OAuth callback and watch renewal to store the watched label metadata.
  Existing connected mailboxes can resolve/store the watched label during sync
  without a new Gmail scope, while renewal configures future watches with that
  label id.
- Updated sync thread expansion so only messages that still carry the watched
  label are parsed; unrelated messages in a Gmail thread are skipped.
- Deferred by scope: watched-label parse-failure Review ignore, hosted rollout,
  iOS, web, push notifications, and M68-M69.
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
  - Gmail API reports the nested label name exactly as
    `Banking/HDFC Transactions`.
  - Missing watched label should surface as a connector/operator error rather than
    silently falling back to Inbox/sender discovery.
  - Gmail OAuth remains readonly; no new Gmail scope is required for existing or
    newly connected mailboxes.
- Mocks created:
  - None.
- Mocks used:
  - Stubbed Gmail API responses in Edge Function tests for labels, watch, history,
    and message-list requests.

## Gmail Label Ingestion M67 Notes

- Completed on 2026-06-16. Milestones 18-21 remained deferred and were not
  started. Milestones 68-69 were not started.
- Added `20260616123612_gmail_netbanking_imps_candidate_type.sql` with
  `netbanking_imps` in `public.source_account_type`, updated Gmail parse-attempt
  validation for `credit_card`, `upi`, `netbanking_imps`, and `other`, and kept
  `record_gmail_parse_attempt(...)` service-role only.
- Refactored `parseGmailTransaction(metadata, bodyText)` to try deterministic
  body parsers in order and return the first successful parse; sender and subject
  remain diagnostics only.
- Added `hdfc_netbanking_imps_debit` with candidate type `netbanking_imps`,
  parser version `1.0.0`, IMPS reference `616734130236`, source account ending
  `0932`, destination account ending `4428`, and statement merchant
  `IMPS to ending 4428`.
- Updated Gmail sync fingerprinting so IMPS reprocessing keys on mailbox, source
  account identity, and source reference; unmatched watched-label messages now
  return candidate type `other` for sanitized parse-attempt recording.
- Updated Flutter labels and source-type dropdowns to show `Netbanking :: IMPS`.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures"`
  - `cd apps/mobile && flutter analyze`
  - `git diff --check`
- Assumptions made:
  - The IMPS sample is a debit-spend template for HDFC account ending `0932`.
  - IMPS duplicate suppression should key on source reference plus source account
    identity.
  - Candidate type `other` remains for sanitized watched-label parse failures.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake Flutter finance repository hooks for parse-failure label
    coverage.

## Gmail Label Ingestion M68 Notes

- Completed on 2026-06-16. Milestones 18-21 remained deferred and were not
  started. Milestone 69 was not started.
- Added `20260616130706_gmail_parse_failure_ignore.sql` with `ignored_at` and
  `ignored_by` on `gmail_parse_attempts`, an unignored parse-failure index, and
  sanitized `list_gmail_parse_failures(...)` filtering so ignored rows no longer
  appear in Review.
- Added `ignore_gmail_parse_failure(p_failure_id uuid)` as an authenticated,
  household-scoped RPC that validates active household membership and marks one
  visible parse failure ignored while keeping `gmail_parse_attempts`
  service-only.
- Confirmed M67 already records unmatched watched-label mail as
  `candidate_type` `other`, parser `unsupported_labeled_gmail_message` version
  `1.0.0`, and reason `no_supported_body_template_matched`; no Edge Function
  changes were needed during M68.
- Added Flutter repository support and a row-level Review `Ignore for now`
  action. Successful ignore invalidates the Gmail parse-failure provider, hides
  one row without hiding other failures, and removes the Gmail parse failures
  card when no visible failures remain.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/rls_isolation.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Ignore for now|Netbanking"`
  - `git diff --check`
- Assumptions made:
  - Active household membership is sufficient for hiding a visible parse
    failure; the action is not writer-only.
  - Re-recording the same parser failure should preserve that row's ignore
    state.
  - Existing M67 unsupported watched-label parse-attempt recording satisfies the
    M68 parse-failure creation contract.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake Flutter finance repository hooks, extended with Gmail
    parse-failure ignore tracking and in-memory row removal.

## Gmail Label Ingestion M65 Notes

- Completed on 2026-06-16.
- Added `docs/implementation-plan/GMAIL_LABEL_INGESTION.md` as the active
  companion plan for Milestones 65-69.
- Split implementation into M66 label watch/backfill contract, M67 body-first
  parser registry plus Netbanking IMPS parser, M68 watched-label parse failures
  plus Review ignore, and M69 final regression/docs cleanup.
- Updated `README.md`, `DATA_MODEL.md`, `INGESTION.md`,
  `GMAIL_CONNECTOR.md`, `MILESTONES.md`, and this handoff so a fresh session
  can start at M66 from repository docs alone.
- No Flutter, Supabase migration, SQL test, importer, Edge Function, hosted
  rollout, iOS, web, or push notification implementation was started.
- Verification:
  - `rg -n "GMAIL_LABEL_INGESTION|Milestone 6[5-9]|Gmail Label Ingestion|Netbanking :: IMPS" docs/implementation-plan`
  - `git diff --check`
- Assumptions made:
  - Gmail API reports the nested label name as `Banking/HDFC Transactions`.
  - Existing connected mailboxes can be migrated to label-based watch renewal
    without reconnecting because the Gmail scope stays readonly.
  - The provided IMPS sample represents a debit-spend transaction.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Merchant Group Management M61 Notes

- Completed on 2026-06-15.
- Added `docs/implementation-plan/MERCHANT_GROUP_MANAGEMENT.md` as the active
  companion plan for Milestones 61-64.
- Split implementation into M62 data/repository contract, M63 Settings UX, and
  M64 final regression/docs cleanup because the feature changes persisted
  merchant contracts, Flutter repository APIs, Settings UI, dashboard grouping,
  provider refreshes, and regression docs.
- Updated `README.md`, `DATA_MODEL.md`, `MILESTONES.md`, and this handoff so a
  fresh session can start at M62 from repository docs alone.
- No Flutter, Supabase, importer, Edge Function, hosted rollout, iOS, web, or
  push notification implementation was started.
- Verification:
  - `rg -n "MERCHANT_GROUP_MANAGEMENT|Milestone 6[1-4]|Merchant Group Management|merchant group management" docs/implementation-plan`
  - `git diff --check`
- Assumptions made:
  - A "merchant group" is the existing canonical `public.merchants` row.
  - Rename is a global canonical display-name update that preserves merchant
    ids.
  - Merge supports user-selected category strategy, with Preserve categories as
    the default and Destination category available when the destination merchant
    has category/subcategory values.
  - Statement-merchant-level reassignment, alias editing, deletion, hosted
    rollout, iOS, web, and push notifications are out of scope.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Merchant Group Management M62 Notes

- Completed on 2026-06-15. Milestones 18-21 remained deferred and were not
  started. Milestone 63 was not started.
- Added `public.v_merchant_group_usage` as a security-invoker Settings-ready
  usage view with merchant identity, category/subcategory names, transaction
  count, net spend, alias count, active mapping-rule count, open review
  suggestion count, and last transaction date.
- Added `public.rename_household_merchant(...)` and
  `public.merge_household_merchants(...)` as app-facing `security invoker` RPCs
  for household writers. Rename preserves merchant ids. Merge moves source
  aliases, mapping rules, transaction merchant references, and open review
  suggestions to the destination; supports Preserve categories or Destination
  category; stamps transaction audit fields for destination taxonomy updates;
  and deletes source merchant rows after references move.
- Extended `FinanceRepository` and `SupabaseFinanceRepository` with merchant
  group snapshot, rename, and merge methods; added request/result models,
  `merchantGroupManagerSnapshotProvider`, fake repository hooks, and canonical
  Dashboard top-merchant grouping by `merchant_id` when available.
- Added focused pgTAP and Flutter coverage for rename, duplicate/blank
  rejection, merge preserve, merge destination, household isolation,
  viewer/non-member denial, result parsing, fake request capture, and canonical
  Dashboard grouping.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/merchant_group_management.sql`
  - `supabase test db --local supabase/tests/merchant_review_corrections.sql`
  - `supabase test db --local supabase/tests/transaction_metadata_editing.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|dashboard|repository"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Destination-strategy merge requires destination category and subcategory
    values before taxonomy is applied to moved source references.
  - Direct merchant deletion remains out of scope; source merchant deletes are
    opened only inside the merge RPC through a transaction-local RLS guard.
  - Closed historical review suggestions can keep existing FK behavior; M62
    explicitly moves open review suggestions.
  - Hosted Supabase migration push was not run.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository data, extended for merchant group snapshot,
    rename, merge, alias counts, and canonical Dashboard grouping.

## Merchant Group Management M63 Notes

- Completed on 2026-06-15. Milestones 18-21 remained deferred and were not
  started. Milestone 64 was not started.
- Added the visible Settings `Merchant groups` card after Categories and before
  Labels. The card uses `merchantGroupManagerSnapshotProvider`, shows canonical
  merchant names, category/subcategory context, transaction/net-spend usage,
  alias counts, active mapping-rule counts, and open Review impact, with refresh
  and rename icon actions plus a merge action disabled until at least two
  merchant groups exist.
- Added a compact rename dialog backed by `renameMerchantGroup`.
- Added a merge dialog backed by `mergeMerchantGroups` with destination
  selection, surviving-name editing, multi-source selection, aggregate source
  impact chips, explicit Preserve categories vs Destination category strategy,
  Destination category disabled when the destination lacks taxonomy, validation,
  and concise success snackbars.
- Rename and merge saves invalidate merchant group manager data, merchant
  options, transactions, trend reports, Dashboard snapshots, and Review queue
  providers.
- Added focused widget coverage for render state, rename save, merge validation,
  preserve-strategy submission, destination-strategy disabling, provider refresh
  effects, and narrow/long-name layout behavior.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Settings|merchant group|merchant|dashboard|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `git diff --check`
- Assumptions made:
  - The existing M62 repository/RPC contract is sufficient for M63; no Supabase
    migration, RPC, or repository API addition was needed.
  - Destination category strategy requires both destination category and
    subcategory values.
  - Alias editing, statement-merchant reassignment, merchant deletion, hosted
    rollout, iOS, web, and push notifications remain out of scope.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository data and M62 merchant-group hooks, extended
    with a merchant-options fetch counter, provider refresh probe, and long-name
    merchant fixture for M63 widget coverage.

## Merchant Group Management M64 Notes

- Completed on 2026-06-15. Milestones 18-21 remained deferred and were not
  started. No later milestone work was started.
- Verified the full merchant group workflow across local Supabase reset,
  focused merchant-group pgTAP, full pgTAP, schema lint, focused Flutter
  coverage for merchant, metadata, Activity, Review, Settings, Dashboard, and
  narrow-layout paths, Flutter analysis, and the full Flutter test suite.
- Confirmed Settings merchant group rename and merge use
  `rename_household_merchant(...)` and `merge_household_merchants(...)`; no
  stale direct client writes bypass the Settings manager RPC contract.
- Folded final merchant group rename/merge behavior, explicit merge category
  strategy, provider refresh expectations, deferred scope, and verification
  results into `README.md`, `DATA_MODEL.md`, `MILESTONES.md`,
  `MERCHANT_GROUP_MANAGEMENT.md`, and this handoff.
- Marked `MERCHANT_GROUP_MANAGEMENT.md` completed-only after M61-M64. The file
  was not removed because the M64 plan says not to remove completed-only
  companion plans without an explicit cleanup request.
- No app code, Supabase migration, RPC, importer, Edge Function, hosted rollout,
  iOS, web, or push notification changes were required during M64.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/merchant_group_management.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|Review|Settings|dashboard|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `rg -n "\\.from\\('merchants'\\)|\\.from\\(\\\"merchants\\\"\\)|rename_household_merchant|merge_household_merchants|rpc\\('rename_household_merchant'\\)|rpc\\('merge_household_merchants'\\)|update\\(|delete\\(" apps/mobile/lib/src apps/mobile/test supabase/functions tools/workbook-import/src`
  - `git diff --check`
- Assumptions made:
  - M62-M63 already implemented the intended merchant group product behavior;
    M64 did not need additional runtime changes after regression passed.
  - Direct `merchants` reads for autocomplete and metadata suggestion context
    remain valid; Settings rename/merge writes stay RPC-backed.
  - Hosted Supabase migration push, alias editing, statement-merchant
    reassignment, merchant deletion outside merge, iOS, web, and push
    notifications remain out of scope.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository merchant group, merchant option, metadata
    correction, Activity query, Dashboard summary, Review queue, and provider
    refresh test hooks.

## Transaction Deletion M52 Notes

- Completed on 2026-06-14.
- Added migration
  `supabase/migrations/20260614113615_transaction_delete_database_contract.sql`
  with `public.deleted_transaction_sources`, source suppression lookup indexes,
  owner select/insert tombstone RLS, service-role tombstone read access, an
  internal transaction-delete tombstone trigger, and an owner-only direct delete
  policy for authenticated users.
- Added `public.delete_transaction(p_household_id, p_transaction_id, p_reason)`
  as the app-facing `security invoker` RPC. It requires the signed-in profile
  to be an owner, rejects missing and cross-household transaction ids, deletes
  the `public.transactions` row, relies on existing FK behavior for cascade and
  unlink semantics, and returns source identity plus deleted/unlinked
  association counts.
- Kept `public.gmail_parse_attempts` service-only. A private owner-scoped helper
  lets the RPC count linked Gmail parse attempts without granting authenticated
  table reads.
- Added `supabase/tests/transaction_deletion.sql` with 43 pgTAP checks for
  owner deletion, role denial, direct non-owner RLS blocking, cascade/unlink
  behavior, monthly spend/category/merchant/monthly-cap recalculation, minimal
  tombstone shape, direct owner delete trigger coverage, and service-role
  tombstone reads. Added `deleted_transaction_sources` to the broad
  `supabase/tests/rls_isolation.sql` table audit.
- No Flutter repository, Activity UI, workbook importer, Gmail sync, Edge
  Function, hosted rollout, push notification, iOS, web, M53, M54, or M55 work
  was started.
- Verification:
  - `supabase --version`
  - `supabase migration --help`
  - `supabase db --help`
  - Supabase changelog/docs scan for relevant schema, RLS, grants, and security
    guidance.
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/transaction_deletion.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Known gaps:
  - M54 later exposed deletion from Activity and refreshed affected Flutter
    providers.
  - M55 later completed final end-to-end transaction deletion regression/docs
    cleanup.
  - No hosted Supabase migration push was run.
- Assumptions made:
  - Optional deletion reasons are app/user metadata and must not contain raw
    transaction payloads, merchant details, amounts, cardholder names, notes,
    raw email bodies, parsed email body snippets, or diagnostics.
  - The existing hard-delete FK behavior is the intended M52 contract:
    transaction labels, transaction sources, and transaction-scoped review rows
    cascade; piggy-bank entries and Gmail parse attempts are preserved and
    unlinked.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Transaction Deletion M53 Notes

- Completed on 2026-06-14.
- Added migration
  `supabase/migrations/20260614122706_import_resurrection_guard.sql`, replacing
  `public.ingest_gmail_transaction(...)` with a tombstone-aware service-role
  ingestion contract. The RPC checks `public.deleted_transaction_sources` before
  source-account, transaction, transaction-source, or review writes. Matching
  Gmail fingerprints return `suppressed = true`, `suppression_reason =
  'deleted_transaction_source'`, null transaction/review ids, and no side
  effects.
- Updated `supabase/functions/gmail-sync/index.ts` so suppressed Gmail parses
  are successful handled work, increment a `suppressed` count, write
  `gmail_parse_attempts` with null transaction id and sanitized suppression
  diagnostics, and emit structured logs containing only household id, mailbox
  id, source type, source message id, and suppression reason.
- Updated `tools/workbook-import/src/workbook-importer.mjs` so workbook imports
  fetch tombstoned workbook fingerprints, skip transaction/source/review writes
  for matching rows, preserve non-deleted idempotent upserts, report
  `suppressedCount`, and validate database totals against the
  tombstone-adjusted transaction set.
- Added regression coverage in:
  - `tools/workbook-import/test/workbook-fixture.test.mjs`
  - `supabase/tests/gmail_ingestion.sql`
  - `supabase/functions/tests/gmail_sync.test.ts`
- No Flutter repository, Activity UI, restore/undo/bulk delete, hosted rollout,
  push notification, iOS, web, M54, or M55 work was started.
- Verification:
  - `supabase --version`
  - `supabase functions --help`
  - Supabase changelog/docs scan for relevant Edge Function, CLI, RLS, and
    breaking-change guidance.
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
- Known gaps:
  - M54 later exposed owner-only deletion from Activity and refreshed affected
    Flutter providers.
  - M55 later completed final deletion regression/docs cleanup.
  - No hosted Supabase migration push or Edge Function deployment was run.
- Assumptions made:
  - A tombstoned Gmail parse should remain a `parsed` parse attempt with null
    transaction id and sanitized suppression diagnostics, rather than adding a
    new parse status.
  - Workbook category, source-account, merchant, and alias reference seeding can
    remain based on the source workbook; only transaction-bearing rows are
    suppressed.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Transaction Deletion M54 Notes

- Completed on 2026-06-14.
- Added `TransactionDeleteRequest`, `TransactionDeleteResult`, and
  `FinanceRepository.deleteTransaction(...)`, with Supabase RPC, disabled
  repository, and fake repository support.
- Added an owner-only destructive Delete action to the Activity transaction
  detail surface. Admin, member, viewer, and unauthenticated states do not get
  the action.
- Added an `AppModalDialog` confirmation that explains Activity/spend/trend/
  label/review/monthly-cap removal, preserved but unlinked Vault entries and
  service diagnostics, and workbook/Gmail re-import suppression.
- Successful deletion calls `delete_transaction`, closes the detail sheet,
  shows a success snackbar, refreshes affected Activity, Dashboard, Trend,
  Review, Label, month, and Vault providers, and moves back one page if the
  current Activity page becomes empty.
- RPC errors stay in the confirmation flow and leave the current Activity state
  intact.
- Tightened `AppActionPill` label shrinking so compact modal actions do not
  overflow at narrow widths.
- Added focused Flutter coverage in
  `apps/mobile/test/finance_features_test.dart` for owner visibility,
  non-owner hiding, cancellation, confirmation/list removal, RPC error
  handling, provider-refetch observability, narrow delete layout, and
  deterministic Settings category drilldown setup inside the
  transaction-focused test subset.
- Verification:
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/shared/widgets/action_pill.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "transaction"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - M55 later completed final end-to-end transaction deletion regression/docs
    cleanup.
  - No hosted Supabase rollout was run.
- Deferred scope was not started: new Supabase schema, Gmail/workbook ingestion
  changes, restore, undo, bulk delete, push notifications, hosted rollout, iOS,
  web, and M55.
- Assumptions made:
  - M54 does not collect an optional deletion reason in the UI; the repository
    model supports it for the existing RPC contract, but the action remains a
    confirmation-only destructive flow.
  - Owner visibility continues to use `HouseholdContext.memberRole == 'owner'`
    as planned, with Postgres retaining final authorization.
- Mocks created:
  - None.
- Mocks used:
  - Extended the existing `_FakeFinanceRepository` in
    `apps/mobile/test/finance_features_test.dart` to record delete requests,
    mutate in-memory transactions, and expose fetch counts for provider refresh
    assertions.

## Transaction Deletion M55 Notes

- Completed on 2026-06-14.
- Ran the full local regression path for the completed M52-M55 transaction
  deletion flow. Existing focused coverage verified owner-only database
  deletion, spend summary and monthly-cap recalculation, transaction child-row
  cascade behavior, Vault and Gmail diagnostics unlinking, tombstone privacy
  shape, workbook suppression, Gmail suppression, sanitized Edge Function
  handled-work semantics, and owner-only Activity delete UI behavior.
- No additional product, schema, importer, Edge Function, or Flutter fixes were
  required during M55.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/ARCHITECTURE.md`,
  `docs/implementation-plan/DATA_MODEL.md`,
  `docs/implementation-plan/INGESTION.md`,
  `docs/implementation-plan/GMAIL_CONNECTOR.md`,
  `docs/implementation-plan/WORKBOOK_IMPORT.md`,
  `docs/implementation-plan/MILESTONES.md`,
  `docs/implementation-plan/TRANSACTION_DELETION.md`, and this handoff so the
  final transaction deletion behavior is reflected in durable docs.
- Marked `docs/implementation-plan/TRANSACTION_DELETION.md` completed-only for
  later cleanup under the repository's completed-plan convention.
- Verification:
  - `supabase --version`
  - Supabase changelog scan for relevant breaking changes.
  - `supabase db --help`
  - `supabase test --help`
  - `supabase db reset --help`
  - `supabase db lint --help`
  - `supabase db advisors --help`
  - `supabase test db --help`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `deno test --allow-env --allow-read supabase/functions/tests`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug`
- Known gaps:
  - No hosted Supabase migration push, Edge Function deployment, or production
    data migration was run.
- Deferred scope was not started: restore, undo, bulk delete, push
  notifications, hosted rollout, iOS, and web.
- Assumptions made:
  - The existing M52-M54 implementation already represented the intended final
    product behavior; M55 was a verification and docs-closeout milestone.
  - `TRANSACTION_DELETION.md` should remain as completed-only until a later
    cleanup removes completed companion plans.
- Mocks created:
  - None.
- Mocks used:
  - Existing M54 `_FakeFinanceRepository` test support was used by the Flutter
    test suite; no new mocks were added.

## Merchant Autocomplete M56 Notes

- Completed on 2026-06-15.
- Created `docs/implementation-plan/MERCHANT_AUTOCOMPLETE.md` as the active
  companion plan for merchant autocomplete and duplicate prevention.
- Added Milestones 56-60 to `docs/implementation-plan/MILESTONES.md`, marking
  M56 complete and M57-M60 planned.
- Updated `docs/implementation-plan/README.md` and this handoff so fresh
  sessions read the new companion plan before executing M57-M60.
- Planned milestone sequence:
  - Milestone 57: Merchant Repository and Activity Filter Foundation.
  - Milestone 58: Shared Merchant Autocomplete in Metadata Editor.
  - Milestone 59: Close-Match Merchant Save Confirmation.
  - Milestone 60: Merchant Autocomplete Regression, Docs, and Cleanup.
- Implementation remains planned only. No Flutter, Supabase, importer, Edge
  Function, hosted rollout, push notification, iOS, or web work was started.
- Verification:
  - Planning artifact inspection only.
- Assumptions made:
  - Merchant autocomplete should be a new non-deferred sequence after M55 while
    M18-M21 remain deferred by user request.
  - Activity suggestion selection should filter by canonical merchant id, while
    free typing should preserve today's statement merchant search behavior.
  - Save-time duplicate confirmation should compare canonical merchant display
    names only and should not inspect aliases or raw statement merchants.
  - No Supabase migration is required for the initial implementation because
    existing merchant lookup reads and exact duplicate protection are already
    available.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Merchant Autocomplete M57 Notes

- Completed on 2026-06-15.
- Extended `MerchantOption` with nullable `categoryId` and `subcategoryId`, and
  extended `TransactionQuery` with nullable `merchantId`.
- Updated `fetchMerchants(...)` to select `category_id` and `subcategory_id`
  from `public.merchants`.
- Updated `fetchTransactions(...)` so selected canonical merchant ids filter by
  `merchant_id`; free typing still uses the existing `statement_merchant`
  `ilike` search when no merchant id is selected.
- Updated Activity List to watch `merchantOptionsProvider(householdId)`, keep
  one visible Merchant search control, select canonical merchant suggestions
  through Material autocomplete, clear `merchantId` when the user types after a
  selection, and clear both typed text and selected merchant id on Clear filters.
- Preserved Dashboard drilldown route semantics: existing `merchant` query
  params continue to seed statement merchant text search, not canonical
  merchant id filters.
- No Supabase migration, importer, Edge Function, hosted rollout, push
  notification, iOS, web, M58, M59, or M60 work was started.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Activity"`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "transaction query supports label filter equality and copyWith"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing `public.merchants` category/subcategory fields and authenticated
    RLS-backed reads are sufficient for M57.
  - Canonical merchant selection remains local Activity filter state in M57; a
    later milestone can expand route semantics only if explicitly planned.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with merchant
    category/subcategory fields and selected merchant id filtering.

## Merchant Autocomplete M58 Notes

- Completed on 2026-06-15.
- Replaced the shared transaction metadata editor Merchant group text field
  with a local Material autocomplete field backed by
  `merchantOptionsProvider(initialValue.householdId)`.
- Selecting an existing merchant suggestion fills the canonical display name and
  updates category/subcategory only when both merchant taxonomy ids are present
  in the editor's current option lists.
- Preserved freeform merchant entry, Suggest updates, Create category,
  confidence, notes, validation, loading, save, cancel, and error handling.
- Added focused widget coverage for both Activity detail editing and Review
  resolution through the shared editor.
- No Supabase migration, importer, Edge Function, hosted rollout, push
  notification, iOS, web, M59, or M60 work was started.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "metadata|merchant review"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing household merchant option reads are sufficient for M58.
  - The autocomplete helper should remain local to the metadata editor because
    Activity search already has filter-specific autocomplete behavior.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options and repository fakes.

## Merchant Autocomplete M59 Notes

- Completed on 2026-06-15.
- Added `merchant_name_matcher.dart` with deterministic merchant normalization,
  Levenshtein similarity, token-prefix handling, and the planned
  `merchantCloseMatchThreshold = 0.82` plus
  `merchantCloseMatchLeadMargin = 0.05` constants unchanged.
- Updated the shared transaction metadata editor save flow so exact normalized
  matches save the existing canonical display name without prompting.
- Added the close-match confirmation dialog with `Use <merchant name>`, `Keep
  new name`, and dismiss/cancel behavior while keeping the editor
  single-submit safe.
- Remembered kept close-match names by normalized typed value for the current
  editor session, so a failed save can be retried without prompting again.
- Added focused helper and widget coverage for `Amazon Shoping` ->
  `Amazon Shopping`, `Swigy Instamart` -> `Swiggy Instamart`, `Amazon Prime`
  and `Uber Eats` non-matches, exact case-only canonical saves, Use existing,
  Keep new name, and cancel behavior.
- No Supabase migration, importer, Edge Function, hosted rollout, push
  notification, iOS, web, M60, or other later-milestone work was started.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing household merchant option reads are sufficient for M59.
  - The initial close-match constants satisfy the documented M59 test matrix, so
    no threshold tuning was needed.
  - Close-match comparison remains limited to canonical merchant display names.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with an `Uber` merchant option
    and a one-save failure hook for the keep-new retry test.

## Merchant Autocomplete M60 Notes

- Completed on 2026-06-15.
- Ran focused and full Flutter verification for Activity merchant filters,
  existing transaction search behavior, Review resolution, transaction detail
  metadata edits, close-match merchant confirmation, and narrow metadata editor
  layout.
- Confirmed the final behavior: Activity preserves free-text statement merchant
  search while selected suggestions filter by canonical `merchant_id`; Activity
  and Review metadata edits share the same merchant autocomplete editor;
  compatible selected merchants can fill category/subcategory ids; exact
  existing names canonicalize without a prompt; clear typo-level matches prompt;
  documented non-matches and freeform merchant names save without interruption.
- No regressions were found during M60. No app code, Supabase migration, RPC,
  importer, Edge Function, hosted rollout, push notification, iOS, web, or
  later-milestone work was started.
- Marked `docs/implementation-plan/MERCHANT_AUTOCOMPLETE.md` completed-only
  after folding final behavior into durable docs.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|review|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Existing household merchant option reads and backend exact duplicate
    protection remain sufficient for final merchant autocomplete behavior; no
    schema or RPC migration was needed.
  - Close-match comparison remains limited to canonical merchant display names.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options, query capture, and
    metadata correction test hooks.

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

## Transaction Deletion Planning Notes

- Completed on 2026-06-14 as a planning-only documentation update.
- Added `docs/implementation-plan/TRANSACTION_DELETION.md` as the detailed
  fresh-thread implementation plan for Milestones 52-55.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/ARCHITECTURE.md`,
  `docs/implementation-plan/DATA_MODEL.md`,
  `docs/implementation-plan/INGESTION.md`,
  `docs/implementation-plan/GMAIL_CONNECTOR.md`,
  `docs/implementation-plan/WORKBOOK_IMPORT.md`,
  `docs/implementation-plan/MILESTONES.md`, and this handoff so transaction
  deletion is discoverable from the repo's standard planning entrypoints.
- Planned milestone sequence:
  - Milestone 52: Transaction Delete Database Contract.
  - Milestone 53: Import Resurrection Guard.
  - Milestone 54: Activity Transaction Delete UX.
  - Milestone 55: Transaction Deletion Regression, Docs, and Cleanup.
- This planning update did not start migrations, Dart code, Flutter UI, tests,
  workbook importer behavior, Gmail Edge Function behavior, or hosted Supabase
  changes.
- Verification run:
  - Planning docs and existing transaction, label, cap, importer, and Gmail
    ingestion paths were inspected before editing.
  - `git diff --check`
  - Conflict-marker scan over implementation-plan docs.
  - Trailing-whitespace scan over edited implementation-plan docs.
- Known gaps:
  - No markdown linter is configured or run for implementation-plan docs.
- Assumptions made:
  - Transaction deletion is owner-only.
  - Deletion is a hard delete of the transaction row.
  - Source tombstones should block workbook and Gmail re-import resurrection.
  - Piggy-bank entries and service diagnostics should be preserved but unlinked.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 36 Completion Notes

- Completed on 2026-06-13 as a planning-only documentation update.
- Added `docs/implementation-plan/UI_REDESIGN.md` as the detailed fresh-thread
  implementation plan for the UI redesign.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/MILESTONES.md`, and this handoff so Milestones
  37-51 are discoverable from the repo's standard planning entrypoints.
- Planned milestone sequence:
  - Milestone 37: UI Design Tokens, Themes, and Theme Preference.
  - Milestone 38: Shared Responsive UI Primitives.
  - Milestone 39: App Shell, Navigation IA, and Routes.
  - Milestone 40: Dashboard Redesign.
  - Milestone 41: Activity List Mode.
  - Milestone 42: Activity Charts Mode.
  - Milestone 43: Transaction Details Redesign.
  - Milestone 44: Transaction Metadata Editor Redesign.
  - Milestone 45: Review Redesign.
  - Milestone 46: Vaults Redesign.
  - Milestone 47: Settings Focused Screen and Theme Selector.
  - Milestone 48: Sign-In and Household Gate Redesign.
  - Milestone 49: Ask / AI Redesign.
  - Milestone 50: Dialogs, Forms, Empty States, and Motion Pass.
  - Milestone 51: UI Redesign Final Regression, Responsive QA, and Docs
    Closeout.
- Implementation remains planned. No Dart code, Flutter UI, tests, Supabase
  migrations, Edge Functions, hosted Supabase changes, staging, commits, or
  branch changes were started by this planning update.
- Verification run:
  - Planning docs, DESIGN.md, current Flutter shell/theme files, current screen
    files, current tests, and the stored Stitch reference bundle were inspected
    before editing.
  - `git status --short`
  - `rg -n "^(<<<<<<<|=======|>>>>>>>)" docs apps/mobile supabase tools || true`
  - `cd apps/mobile && flutter analyze`
- Known gaps:
  - No markdown linter is configured or run for implementation-plan docs.
  - The Stitch reference bundle is present in the working tree and should be
    reviewed/staged with the docs when committing this planning update.
- Assumptions made:
  - User-selected IA decisions are source-of-truth for the redesign: Activity
    replaces Transactions and Trends without keeping old routes, Vaults is the
    visible destination name, and Settings opens from a global gear rather than
    the bottom bar.
  - Theme preference is local device state, not a Supabase-synced setting.
  - `DESIGN.md` wins when Stitch token output differs from the design-system
    document.
- Mocks created:
  - None.
- Mocks used:
  - Existing Stitch export under
    `docs/design-references/stitch/themed-dashboard-ui-redesign`.

## Milestone 37 Completion Notes

- Started and completed on 2026-06-13.
- Replaced the seed-color-only Flutter theme with centralized DESIGN.md token
  constants, including lime primary CTA `#9fe870`, on-primary ink `#0e0f0c`,
  sage canvas `#e8ebe6`, white card surface, ink/body/muted text colors,
  positive/warning/negative semantic colors, and canonical 24px card/button
  radius values.
- Added explicit `AppTheme.light()` and `AppTheme.dark()` theme data with
  token-driven surfaces, typography colors, Material component themes, and a
  semantic color theme extension.
- Added local system/light/dark theme-mode persistence using
  `shared_preferences`, defaulting to `ThemeMode.system` while loading or when
  no valid stored value exists.
- Wired `SpendLensApp` to pass `theme`, `darkTheme`, and `themeMode` into
  `MaterialApp.router`.
- Added focused theme tests for token use, mode parsing, shared-preferences
  save/load, provider default/load/change behavior, and app-level theme-mode
  application.
- No Supabase schema, Edge Function, RLS, repository-query, hosted rollout,
  push notification, iOS, web, M38, or later-milestone work was started.
- Verification run:
  - `git status --short --branch`
  - Required M37 planning docs, `DESIGN.md`, Stitch README/project metadata,
    existing app theme/app wiring, `pubspec.yaml`, and current tests were
    inspected before editing.
  - `cd apps/mobile && flutter pub get`
  - `cd apps/mobile && dart format lib/src/core/theme/app_theme.dart lib/src/core/theme/theme_mode_controller.dart lib/src/app/spend_lens_app.dart test/theme_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - M37 owns the local theme foundation and persistence layer; the visible
    Settings theme selector remains deferred to Milestone 47.
  - `DESIGN.md` is authoritative for token values when Stitch metadata differs.
  - Theme mode remains local device state and is not synced to Supabase.
- Mocks created:
  - None.
- Mocks used:
  - Stored Stitch reference README and project metadata were inspected for M37
    context; no Stitch HTML or screen mock content was copied into Flutter.

## Milestone 38 Completion Notes

- Started and completed on 2026-06-13.
- Added `responsive.dart` with the DESIGN.md breakpoint contract: mobile below
  768px, tablet 768-1023px, and desktop at 1024px and above.
- Extended `AppPage` into a responsive, safe-area-aware page scaffold with
  constrained large-screen content width, mobile bottom-navigation spacing, and
  reusable display/section heading primitives.
- Reworked `MetricCard` and `EmptyState` on top of the new card/state
  primitives while preserving existing constructor compatibility for current
  screens.
- Added reusable shared primitives for white content cards, sage feature cards,
  dark feature cards, filter pills, status chips, icon chips, large amount
  text, primary/secondary/destructive action pills, modal/bottom-sheet card
  shells, loading states, and error states.
- Added `app_primitives.dart` as a shared-widget barrel export for upcoming
  screen milestones.
- Added `apps/mobile/test/shared_primitives_test.dart` covering breakpoint
  classification, responsive page padding/content constraints, and
  representative light/dark primitive rendering.
- No app shell, navigation IA, route, Activity destination, screen-specific
  redesign, Supabase/backend/schema, hosted rollout, push notification, iOS,
  web, M39, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/shared/widgets/action_pill.dart lib/src/shared/widgets/amount_text.dart lib/src/shared/widgets/app_card.dart lib/src/shared/widgets/app_page.dart lib/src/shared/widgets/app_primitives.dart lib/src/shared/widgets/chips.dart lib/src/shared/widgets/empty_state.dart lib/src/shared/widgets/metric_card.dart lib/src/shared/widgets/responsive.dart test/shared_primitives_test.dart`
  - `cd apps/mobile && flutter test test/shared_primitives_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The root `DESIGN.md` and existing M37 `AppThemeTokens`/semantic colors are
    the authoritative design-token sources for M38.
  - M38 should provide reusable primitives and keep current screen behavior
    intact; M39 owns app-shell/navigation IA and routes.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 39 Completion Notes

- Started and completed on 2026-06-13.
- Added `/activity` as the authenticated Activity destination and routed it
  through a new `ActivityScreen` integration point backed by the existing
  transaction-list behavior for this milestone.
- Replaced primary shell navigation with exactly Dashboard, Activity, Review,
  and Vaults, using the M38 responsive breakpoint helper for mobile bottom
  navigation versus wide navigation rail behavior.
- Removed Settings from primary navigation and added a global shell settings
  action that opens `/settings` inside the authenticated shell context.
- Removed active `/transactions` and `/trends` app routes; Ask remains a
  non-primary authenticated route.
- Retargeted Dashboard category/merchant drilldowns and Settings category
  detail drilldowns to `/activity`, preserving existing category, label,
  merchant, `startDate`, and `endDate` query semantics through Activity.
- Updated route/helper tests for Activity and added shell navigation coverage
  for the four primary destinations plus the settings action.
- No Dashboard redesign, Activity list/charts content migration,
  Review/Vaults/Settings visual redesign, Supabase/backend/schema, hosted
  rollout, push notification, iOS, web, M40, or later-milestone work was
  started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_route.dart lib/src/features/activity/activity_screen.dart lib/src/app/router.dart lib/src/app/app_shell.dart lib/src/features/dashboard/dashboard_screen.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart test/widget_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The visible Vaults primary destination can continue to use the existing
    `/piggy-banks` route until the later Vaults-specific redesign/renaming
    milestone.
  - The existing transaction-list implementation pane can remain as the temporary Activity
    list implementation behind `/activity`; the full list/charts consolidation
    remains deferred to M41-M42.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 40 Completion Notes

- Started and completed on 2026-06-14.
- Rebuilt Dashboard around the Stitch dashboard hierarchy: large Dashboard
  display title with compact month pill, Spending section, large net-spend
  card, month-change card, Review queue card, Monthly caps progress rows, Top
  categories cards, and Top merchants cards.
- Preserved selected reporting month, current month net spend,
  month-over-month amount/percent, review queue count, recurring monthly caps,
  cap add/edit/delete, carry-forward display, top category drilldown, and top
  merchant drilldown.
- Kept Dashboard category and merchant drilldowns routed to `/activity` with
  equivalent month/category/merchant filters.
- Added 390px Dashboard hierarchy widget coverage while keeping existing cap
  workflow and drilldown coverage passing.
- No Activity List mode migration, Activity Charts migration,
  Review/Vaults/Settings visual redesign, cap backend/schema/RPC work, hosted
  rollout, push notification, iOS, web, M41, or later-milestone work was
  started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The existing shell settings affordance added in M39 remains the Dashboard
    settings affordance for M40, so Dashboard itself does not add a second
    settings button.
  - The existing cap form remains functionally intact for M40; broader
    modal/sheet polish remains deferred to M50.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/dashboard-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/dashboard-unified-navigation.html`

## Milestone 41 Completion Notes

- Started and completed on 2026-06-14.
- Added Activity's List/Charts segmented control with List as the default mode
  and a Charts placeholder only; Activity Charts implementation remains
  deferred to Milestone 42.
- Moved the existing transaction list behavior under Activity List while
  preserving merchant search, category, label, source type, source account,
  period/custom date range, clear filters, pagination, Dashboard drilldown, and
  Settings drilldown query semantics for `/activity`.
- Restyled Activity List filters as pill-like responsive controls and
  transaction rows as large rounded cards with icon chips, merchant/group names,
  date/statement/category/subcategory/type metadata, amounts, label chips with
  overflow, and detail tap targets.
- Preserved transaction label edit and metadata edit entry points through the
  transaction detail sheet.
- Added focused Activity List default/narrow-viewport widget coverage and
  updated the off-screen transaction detail test tap for the larger cards.
- No Activity Charts implementation, Review/Vaults/Settings redesign,
  push-notification work, M42, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/shared/widgets/period_filter_dropdown.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - Activity Charts should remain a non-functional placeholder in M41 because
    chart/report migration is explicitly Milestone 42.
  - The existing transaction detail sheet remains the correct place for label
    and metadata edit entry points until the detail/editor redesign milestones.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/activity-scandi-fintech-refinement.html`

## Milestone 42 Completion Notes

- Started and completed on 2026-06-14.
- Replaced Activity's Charts placeholder with the existing Trends report
  behavior inside the Activity segmented control.
- Preserved `TrendReport`, `TrendQuery`, and `trendReportProvider` contracts
  unchanged while keeping category, source type, source account, and
  period/custom date filtering.
- Preserved filtered transaction CSV copy as a secondary chart action.
- Reshaped the report into the Stitch hierarchy: Gross spend, Refunds, Net
  spend, Monthly Net Spend chart, Gross/Refunds/Net monthly table, and Category
  Trend card.
- Kept chart and table content constrained or horizontally scrollable for
  narrow Android widths, with wider category trend table behavior retained on
  larger layouts.
- Updated trend tests to open Activity Charts mode and verified no app/test code
  still navigates to `/trends`.
- No Transaction Details redesign, Transaction Metadata Editor redesign,
  Review/Vaults/Settings redesign, push-notification work, M43, or
  later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The existing Trend report model/provider contracts remain the correct data
    source for Activity Charts.
  - The standalone `/trends` app route had already been removed by M39, so M42
    only removed remaining direct Trends pane usage from focused tests.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/activity-unified-navigation.html`

## Milestone 43 Completion Notes

- Completed on 2026-06-14.
- Rebuilt the transaction detail bottom sheet as a constrained M38 shared modal
  card surface, matching the Stitch detail hierarchy with close affordance,
  centered merchant/date/large amount, transaction type/status pill, divider
  detail rows, and primary Edit action.
- Detail rows now always include statement, gross spend, refunds, net expense,
  source amount, category, subcategory, and confidence, with cardholder, notes,
  and labels included when applicable.
- Preserved existing metadata editor and label editor entry points and behavior;
  the Transaction Metadata Editor itself was not restyled.
- Added focused Activity List coverage for opening transaction details at a
  390px viewport and checking the new surface/actions without overflow.
- No Transaction Metadata Editor redesign, Review/Vaults/Settings redesign,
  push-notification work, M44, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The existing transaction list card remains the Activity List entry point for
    details; M43 only changes the detail surface opened from that card.
  - The metadata editor visual redesign remains deferred to Milestone 44.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-details-refined-shapes.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/transactions-details-refined-shapes.html`

## Milestone 44 Completion Notes

- Completed on 2026-06-14.
- Rebuilt the shared transaction metadata editor as a constrained modal card
  matching the Stitch form hierarchy with `Edit metadata` display title,
  outlined merchant group, category, subcategory, confidence, and notes fields,
  inline Create category affordance, explanatory copy, and responsive
  Suggest/Cancel/Save actions.
- Preserved merchant group editing, category/subcategory selection, confidence
  editing, notes editing, inline category creation, AI Suggest requests and
  failure handling, transaction-detail saves, Review correction saves, and
  existing provider invalidation after save.
- Added focused coverage for Suggest failure retaining manual form values and
  saving them afterward, plus a 390px dark-theme metadata editor render check.
- No Review/Vaults/Settings/sign-in/Ask/dialog redesign, push-notification
  work, M45, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/transaction_metadata/transaction_metadata_editor.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - Activity and Review should continue to share the same metadata editor and
    caller-owned provider invalidation behavior.
  - The existing category creation dialog remains visually out of scope for
    M44 and is deferred to later dialog/form polish.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-edit-metadata.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/transactions-edit-metadata.html`

## Milestone 45 Completion Notes

- Completed on 2026-06-14.
- Rebuilt Review around the Stitch queue-card hierarchy with the `Review`
  display title, supporting copy, Open Reviews and Correction Data metric cards,
  warning-rail queue cards, merchant/source/date line, large amount treatment,
  needs-attention status, classification chips, confidence chip, and full-width
  Resolve action.
- Preserved Gmail parse failure visibility and detail rendering, queue
  loading/error states, correction flow through the shared metadata editor,
  Review correction save behavior, and caller-owned provider invalidation after
  save.
- Moved the Review queue to a `SliverList.builder` inside a responsive
  sliver-based page so cards fit 390px mobile width and wider layouts without
  nested unbounded scrollables.
- Added focused widget coverage for redesigned loading/error states, 390px
  queue-card rendering, Gmail parse failure rendering with a lazy queue, and
  the existing Review correction flow.
- No Vaults/Piggy Banks redesign, Settings/sign-in/Ask/dialog redesign,
  metadata editor redesign beyond preserving existing integration,
  push-notification work, M46, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/merchant_review/merchant_review_screen.dart lib/src/shared/widgets/chips.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - Review items do not expose a source-account label, so the redesigned
    merchant/source/date line uses the existing source amount and transaction
    date fields without changing repository contracts.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/review-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/review-unified-navigation.html`

## Milestone 46 Completion Notes

- Completed on 2026-06-14.
- Restyled the existing Piggy Banks route as the visible `Vaults` destination
  with the Stitch hierarchy: display title, New Vault action, Active ledgers
  and Total balance summary cards, selected-vault hero card, deposit and
  withdraw actions, Current balance, Target progress, Remaining, and empty
  entries card.
- Preserved create/edit vault behavior, selected ledger behavior, deposit,
  withdrawal, and adjustment entries, no-overdraft validation, and
  ledger-derived balance/progress reads without renaming database, RPC,
  repository, or model contracts away from piggy-bank terminology.
- Added responsive stacked cards on mobile and constrained responsive card
  grids on wider layouts, including compact hero action buttons that fit the
  390px Android viewport without overflow.
- Updated focused finance coverage from visible Piggy Banks copy to Vaults and
  exercised the create/deposit/withdraw/progress flow at 390px width.
- No Settings focused screen/theme selector work, sign-in/Ask/dialog/export/OCR
  redesign, Supabase/backend/schema/RPC work, push-notification work, M47, or
  later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/piggy_banks/piggy_banks_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - None.
- Assumptions made:
  - The public `/piggy-banks` route and `PiggyBank*` repository/model names
    remain implementation details from the existing contract; only visible UI
    copy changes to Vaults in M46.
  - Adjustment entries remain available as a compact third hero action beside
    Deposit and Withdraw to preserve existing ledger behavior.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/vaults-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/vaults-scandi-fintech-refinement.html`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/metadata/vaults-scandi-fintech-refinement.screen.json`

## Milestone 47 Completion Notes

- Completed on 2026-06-14.
- Rebuilt Settings as a focused non-tab route with a Back affordance, constrained
  focused page width, Account & Runtime, Theme, Categories, Labels, Gmail
  Importer, AI Core, and System Environment cards using the M38 primitives and
  DESIGN.md surfaces.
- Added the Settings theme selector with System default, Light, and Dark
  options wired to the existing M37 `AppThemeModeController`, so changes update
  `MaterialApp.router` immediately and persist through the local theme-mode
  store.
- Hid the primary shell navigation while `/settings` is active, while preserving
  the global shell settings affordance from other authenticated routes and
  direct `/settings` reachability.
- Preserved sign-out, category create/rename/delete/merge, label
  create/rename/delete, Gmail connect/disconnect/status, AI budget/status,
  environment/config display, and category detail drilldown to Activity.
- No sign-in/household gate redesign, Ask/AI redesign, dialog/form polish,
  Supabase/backend/schema/RPC/Edge Function/hosted work, push-notification work,
  M48, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/app/app_shell.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
  - Conflict-marker scan over changed files.
- Known gaps:
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - Settings should hide primary navigation while active to match the stored
    focused no-nav Stitch reference; users return via Back or reach Settings
    from the global shell settings affordance on other authenticated routes.
  - Theme mode remains local device state and must not be synced to Supabase.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/settings-focused-view-no-nav.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/settings-focused-view-no-nav.html`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/metadata/settings-focused-view-no-nav.screen.json`

## Milestone 49 Completion Notes

- Completed on 2026-06-14.
- Restyled the non-primary Ask route using the redesigned app primitives:
  prompt composer, primary Ask action, AI budget/status card, status chips,
  loading card, inline error state, and result card now follow the DESIGN.md
  card/input/action system.
- Preserved the existing `/ask` route, prompt input behavior,
  backend-mediated expense Q&A call, AI budget status provider, provider
  invalidation after successful calls, and Settings/shell route constraints that
  keep Ask outside the four primary tabs.
- Added focused Ask widget coverage for light and dark rendering plus inline
  error-state rendering while keeping the existing submit-and-answer test.
- No Edge Function, backend, Supabase schema/RPC, hosted configuration, AI
  semantic changes, push-notification work, M50, or later-milestone work was
  started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/ai/ai_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
  - Conflict-marker scan over changed files.
- Known gaps:
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - M49 has no dedicated Ask/AI Stitch reference asset in the committed
    themed-dashboard export, so DESIGN.md plus existing redesigned primitives
    are the visual authority.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 50 Completion Notes

- Completed on 2026-06-14.
- Added shared reduced-motion-aware modal, entrance, and press-scale primitives
  and used them to normalize category creation, monthly cap, label, taxonomy,
  category merge/delete, transaction-label, and vault dialog/sheet/form chrome.
- Themed app snackbars as floating rounded toast surfaces, replaced remaining
  Settings empty/detail legacy chrome with shared empty/card primitives, and
  kept long modal action rows visible under constrained viewport heights.
- Added low-cost motion for shared filter pills, Activity mode selection,
  modal/empty/loading entrance, action button press feedback, and vault entry
  type transitions while respecting accessible navigation.
- Preserved existing repository calls, navigation, validation, AI/auth/backend
  semantics, and test keys; no Supabase, schema, RPC, Edge Function, hosted,
  product-behavior, push-notification, M51, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/shared/widgets/empty_state.dart lib/src/shared/widgets/app_card.dart lib/src/shared/widgets/action_pill.dart lib/src/shared/widgets/chips.dart lib/src/core/theme/app_theme.dart lib/src/features/categories/category_creation_dialog.dart lib/src/features/dashboard/dashboard_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/settings/settings_screen.dart lib/src/features/piggy_banks/piggy_banks_screen.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --plain-name "settings merges categories after explicit subcategory mapping"`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - M50 uses the committed Stitch transaction/details/settings/vault references
    plus `DESIGN.md`; there is no separate dedicated dialog-state Stitch asset
    beyond those screen exports.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 51 Completion Notes

- Completed on 2026-06-14.
- Added final responsive/theme regression coverage for the redesigned shell and
  core authenticated surfaces at 390px mobile, 768px tablet, and 1024px
  large-window widths while cycling light, dark, and system theme modes.
- Extended sign-in and household gate theme coverage to the same representative
  width set.
- Fixed a Dashboard desktop-width layout regression where the wide spending-card
  row could receive unbounded scroll height; equal card height is preserved with
  finite intrinsic layout.
- Documented final UI behavior in `README.md`,
  `docs/implementation-plan/README.md`, `MILESTONES.md`, this handoff, and
  `UI_REDESIGN.md`.
- Confirmed deferred scope remains unchanged: Milestones 18-21 push
  notifications, iOS, web, hosted rollout, Supabase/backend/schema/RPC/Edge
  Function work, product-behavior changes, and later/deferred future milestones
  were not started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart test/widget_test.dart`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "app shell exposes settings outside primary navigation|redesigned core surfaces render at M51 widths and theme modes"`
  - `cd apps/mobile && flutter test test/widget_test.dart --plain-name "auth entry and household gate states render in app themes"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
  - Conflict-marker scan over changed files.
- Known gaps:
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - The committed Stitch screenshots are 390px mobile references; tablet and
    desktop validation comes from Flutter responsive breakpoints and widget
    coverage.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/dashboard-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/review-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/vaults-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/settings-focused-view-no-nav.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-details-refined-shapes.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-edit-metadata.jpg`

## Milestone 48 Completion Notes

- Completed on 2026-06-14.
- Restyled sign-in as a responsive DESIGN.md auth surface on the sage canvas
  with a rounded auth card, branded wallet mark, environment badge, preserved
  Supabase readiness notices, and preserved Google sign-in action.
- Restyled household loading as a focused branded loading card and household
  error as a redesigned gate card with retry and sign-out actions wired to the
  existing providers.
- Added focused auth/gate widget coverage for light, dark, and system theme
  rendering plus sign-in, retry, and sign-out behavior.
- No auth repository/OAuth behavior changes, Ask/AI redesign, dialog/form
  polish, Supabase/backend/schema/RPC/Edge Function/hosted work,
  push-notification work, M49, or later-milestone work was started.
- Verification run:
  - `cd apps/mobile && dart format lib/src/app/router.dart lib/src/features/auth/sign_in_screen.dart lib/src/shared/widgets/app_gate_scaffold.dart lib/src/shared/widgets/app_primitives.dart test/widget_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/widget_test.dart`
  - `cd apps/mobile && flutter test integration_test/app_test.dart` (blocked:
    no supported Android device connected; macOS/web are not generated for this
    project)
  - `cd apps/mobile && flutter test`
  - `git diff --check`
  - Conflict-marker scan over changed files.
- Known gaps:
  - No Android-emulator manual smoke was run; the integration smoke could not
    run because no supported Android device was connected.
- Assumptions made:
  - M48 has no dedicated Stitch auth/gate reference, so the implementation uses
    DESIGN.md plus existing M38 primitives as the visual authority.
- Mocks created:
  - None.
- Mocks used:
  - None.

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
  - Category rename/add/delete/merge was later implemented through M22-M25.
    Remaining future taxonomy-admin work includes reorder, moving
    subcategories between categories, category icons/colors, category audit
    timeline UI, cross-household templates, bulk AI recategorization, and
    subcategory-specific Transactions filters.
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

## Milestone 17 Completion Notes

- Completed on 2026-06-10.
- Added `FinanceRepository.fetchAvailableMonths` plus
  `availableMonthsProvider`, backed by `v_monthly_spend.period_month`.
- Added a shared `PeriodFilterDropdown` with:
  - `All dates`.
  - One option per available reporting month, formatted like `Mar 2026`.
  - `Custom date range`, which delegates to the existing date-range picker.
- Updated Transactions to replace the standalone date-range button with the
  shared period dropdown. Month selections map to the first/last day of the
  month, reset pagination to page 0, and preserve search/category/source
  filters.
- Updated transaction route preloaded `startDate`/`endDate` values so exact
  calendar-month ranges display as the matching month label while keeping the
  existing URL query contract.
- Updated Trends to replace the standalone date-range button with the same
  period dropdown while preserving the default all-date report until a month or
  custom range is selected.
- No database migration, RLS, Edge Function, hosted deploy, or Supabase API
  change was needed.
- Verification run:
  - `curl -L --max-time 20 https://supabase.com/changelog.md | rg -n "breaking|Dart|Flutter|PostgREST|REST|select|order" -i`
  - Supabase MCP docs search for Dart select/order Data API usage.
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/transactions/transactions_screen.dart apps/mobile/lib/src/features/trends/trends_screen.dart apps/mobile/lib/src/shared/widgets/period_filter_dropdown.dart apps/mobile/test/finance_features_test.dart`
  - `flutter test test/finance_features_test.dart`
  - `flutter analyze`
  - `flutter test`
- Known gaps:
  - Custom range picker behavior continues to use Flutter's existing
    `showDateRangePicker`; no additional picker-specific widget test was added.
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - Available months should come from the same monthly spend view used by the
    dashboard.
  - Month/custom selections should continue to use inclusive `startDate` and
    `endDate` filters.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data.

## Push Notifications Plan Creation Notes

- Completed on 2026-06-11.
- Added `docs/implementation-plan/PUSH_NOTIFICATIONS.md` as the detailed
  implementation plan for Milestones 18-21.
- Updated `docs/implementation-plan/MILESTONES.md` with concise completed
  entries for Milestones 16-17 and planned entries for Milestones 18-21.
- Updated implementation-plan README, architecture, external setup, production
  readiness, and this handoff to point future sessions at the Android push
  notification plan.
- Implementation remains planned. Milestone 18 was not started.
- Verification run:
  - Planning artifact inspection.
  - Official docs lookup for Firebase Cloud Messaging, FCM HTTP v1, Android
    notification permission, and Supabase Edge Function secrets.
- Assumptions made:
  - Android push provider is Firebase Cloud Messaging.
  - Notification text defaults to merchant and amount details.
  - New transaction notifications are grouped per successful processing batch.
  - iOS and web push notifications remain deferred.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Category Management Plan Creation Notes

- Completed on 2026-06-11.
- Added a detailed companion implementation plan for Milestones 22-25. That
  completed-only plan was retired during docs cleanup on 2026-06-12 after the
  final category-management behavior was folded into `DATA_MODEL.md`,
  `MILESTONES.md`, and this handoff.
- Originally updated `docs/implementation-plan/MILESTONES.md` with planned
  entries for:
  - Milestone 22, Category Manager Foundation and Usage Preview.
  - Milestone 23, Taxonomy Delete and Review Requeue.
  - Milestone 24, Category Merge with Explicit Subcategory Mapping.
  - Milestone 25, Category Management Regression, Docs, and Cleanup.
- M22-M25 were later completed, and the active new-session routing no longer
  points at the retired companion plan.
- At plan-creation time, implementation remained planned and Milestone 22 had
  not started. Milestone 22 has since been completed; see the completion notes
  below.
- Verification run:
  - Planning artifact inspection.
  - Existing Supabase/RLS/category/review schema inspection.
  - Existing Flutter Settings, category creation, finance repository, and test
    surface inspection.
- Assumptions made:
  - Category management was originally planned after the existing M18-M21 push
    notification sequence unless the user explicitly reprioritized it. The user
    later deferred M18-M21, and M22-M25 were completed.
  - Delete means remove taxonomy rows, never transactions.
  - Deleted category transactions should return to Review for reclassification.
  - Category merge requires explicit source-subcategory mapping before save.
  - Reordering remains deferred.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 22 Completion Notes

- Started on 2026-06-11 after the user explicitly deferred Milestones 18-21.
- Completed on 2026-06-11.
- Replaced the compact Settings category list with a grouped category manager
  that keeps category rows visually grouped with subcategory rows, compact edit
  icon actions, selected usage details, and recent transaction previews.
- Added `CategoryManagerSnapshot`, `CategoryUsagePreview`, and related Riverpod
  providers to expose category/subcategory transaction counts, net spend, and
  recent transactions with merchant/date/amount/category context.
- Added optional subcategory filtering to `TransactionQuery` so category
  preview reads can reuse the existing transaction repository path.
- Added `public.update_household_category_taxonomy(...)` as the single
  app-facing `security invoker` RPC for non-destructive taxonomy edits. It
  requires a signed-in profile and household write access, trims and rejects
  blank names, validates category/subcategory ownership, rejects
  case-insensitive duplicate category and subcategory names, updates existing
  rows in place, inserts only new subcategories, and returns the edited
  category with the ordered subcategory list.
- The save flow refreshes category/subcategory lookups, category manager
  snapshot/preview, dashboard snapshots, transactions, trends, and merchant
  review providers after taxonomy edits.
- Deferred by scope: delete, merge, moving subcategories between categories,
  reorder controls, Firebase, push notifications, and later category milestones.
- Verification run:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/categories/category_creation_dialog.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
  - Destructive category operations remain deferred to later category
    milestones.
- Assumptions made:
  - RLS-protected direct reads from `categories`, `subcategories`, and
    `transactions` are sufficient for M22 usage previews; only taxonomy
    mutation needed a dedicated RPC.
  - Subcategory preview filtering could extend the existing `TransactionQuery`
    without changing visible Transactions-screen controls.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M22 category
    manager snapshot, preview, and taxonomy update behavior.

## Milestone 23 Completion Notes

- Started on 2026-06-11 after Milestone 22 completed and the user kept
  Milestones 18-21 deferred.
- Completed on 2026-06-11.
- Added compact delete icon actions to the Settings category manager for
  category and subcategory rows, with confirmation dialogs that show affected
  transaction counts, active mapping-rule counts, cap counts, and recent
  transaction examples before deletion.
- Added `public.delete_household_subcategory(...)` and
  `public.delete_household_category(...)` as app-facing `security invoker` RPCs.
  They require a signed-in profile plus household write access, validate
  ownership, preserve transactions, and route affected rows back through Review.
- Subcategory deletion clears affected `subcategory_id` references on
  transactions, merchants, mapping rules, and review suggestions while
  preserving transaction `category_id`, marking classification audit metadata,
  and deleting the subcategory row only after references are cleared.
- Category deletion clears affected category/subcategory/rule references,
  preserves merchant and statement merchant context, creates or updates open
  Review rows with a taxonomy-deleted reason, disables future mapping rules
  that referenced the deleted taxonomy, clears merchant/review suggestion
  references, removes category caps, and deletes the category row afterward.
- Replaced direct taxonomy DELETE policies with writer-scoped guarded policies
  that only allow already-unused category/subcategory rows to be deleted
  directly. pgTAP coverage verifies direct authenticated DELETE cannot bypass
  Review requeue for used taxonomy; the RPC path clears/requeues first.
- Delete success refreshes Settings category manager data, category/subcategory
  lookups, dashboard, transactions, trends, available months, and merchant
  review queue providers.
- Deferred by scope: Milestone 24 merge, reorder, category archival, bulk AI
  recategorization, Firebase, and push notifications.
- Verification run:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `dart format apps/mobile/lib/src/data/repositories/finance_repository.dart apps/mobile/lib/src/features/categories/category_creation_dialog.dart apps/mobile/lib/src/features/settings/settings_screen.dart apps/mobile/test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
  - Category merge remains deferred to Milestone 24.
- Assumptions made:
  - Direct authenticated DELETE may remain available for already-unused
    taxonomy rows as long as used taxonomy cannot bypass Review requeue.
  - Subcategory deletion should keep active category-level future mapping rules
    usable by clearing only `subcategory_id`.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M23 delete
    impact confirmation and post-delete refresh behavior.

## Milestone 24 Completion Notes

- Started on 2026-06-11 after Milestone 23 completed and the user kept
  Milestones 18-21 deferred.
- Completed on 2026-06-11.
- Added `public.merge_household_categories(...)`, an app-facing
  `security invoker` RPC that requires a signed-in profile and household write
  access, validates destination/source category ownership, requires every source
  subcategory to be mapped exactly once, rejects duplicate destination
  subcategory names case-insensitively, creates requested destination
  subcategories, repoints taxonomy references, merges same-month caps, deletes
  merged-away taxonomy rows after references move, and returns changed counts.
- The merge RPC repoints transactions, merchants, merchant mapping rules, and
  existing review suggestions to the surviving taxonomy. Active future mapping
  rules remain active, and affected transactions record acting profile,
  timestamp, and a merge audit note.
- The RPC does not create Review items during merge.
- Added a Settings category-manager merge flow where the user chooses one
  destination category, one or more source categories, may edit the surviving
  category name, sees affected transaction counts, net spend, caps, active
  mapping rules, and recent transaction examples, and must explicitly map every
  source subcategory to an existing or new destination subcategory before Save
  is enabled.
- Merge success refreshes Settings category manager data, category/subcategory
  lookups, dashboard, transactions, trends, merchant review queue, available
  months, and monthly cap/dashboard providers.
- Added pgTAP coverage for missing mapping rejection, duplicate new
  destination subcategory rejection, RLS rejection, taxonomy reference
  repointing, cap merging, deletion of merged-away taxonomy, transaction audit
  metadata, and the no-new-review-items contract.
- Added Flutter widget coverage for the merge dialog, disabled Save until
  mapping is complete, duplicate subcategory-name validation, surviving
  category rename, RPC request payload, post-merge repository state, and success
  snackbar.
- Deferred by scope: Milestone 25 regression/docs cleanup, undo history,
  category archival, reorder, icons/colors, AI-assisted merge suggestions,
  Firebase, and push notifications.
- Verification run:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
  - Milestone 25 was completed in a separate fresh worker session after this
    milestone; see the notes below.
- Assumptions made:
  - Category-level transactions without a source subcategory should move to the
    surviving category with no destination subcategory mapping required.
  - Existing review suggestions should be repointed, but merge should not create
    additional Review items.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M24 merge
    dialog and post-merge refresh behavior.
  - Local pgTAP fixture rows in `supabase/tests/category_taxonomy_merge.sql`.

## Milestone 25 Completion Notes

- Started on 2026-06-11 after Milestone 24 completed and the user kept
  Milestones 18-21 deferred.
- Completed on 2026-06-11.
- Added a Settings category-detail `View transactions` action that opens the
  existing Transactions route with the selected category filter applied.
- Polished category manager empty/error states and category detail header layout
  for narrow mobile viewports.
- Added focused Flutter widget coverage for Settings category-detail transaction
  drilldown and narrow viewport fit, using the existing finance test harness.
- Updated durable category-management docs in the implementation-plan README
  and data model notes. `WORKBOOK_IMPORT.md` was left unchanged because importer
  behavior and commands did not change.
- Deferred by scope: Milestones 18-21 push notifications, category reorder,
  cross-household templates, category icons/colors, category audit timeline UI,
  bulk AI recategorization, and subcategory-specific Transactions filters.
- Verification run:
  - `supabase db reset --local`
  - `pnpm --dir tools/workbook-import install --frozen-lockfile`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/categories/category_creation_dialog.dart lib/src/features/merchant_review/merchant_review_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/transaction_metadata/transaction_metadata_editor.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - The existing category-only Transactions filter is the durable drilldown
    contract for M25; subcategory context remains in Settings.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M25 Settings
    drilldown and narrow viewport coverage.

## Transaction Labels Planning Notes

- Completed on 2026-06-12 as a planning-only documentation update.
- Added `docs/implementation-plan/TRANSACTION_LABELS.md` as the detailed
  fresh-thread implementation plan for Milestones 26-28.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/DATA_MODEL.md`, and
  `docs/implementation-plan/MILESTONES.md` so transaction labels are discoverable
  from the repo's standard planning entrypoints.
- Planned milestone sequence:
  - Milestone 26: Labels Data Model and Repository Foundation.
  - Milestone 27: Transaction Labeling UX.
  - Milestone 28: Settings Label Manager and Regression.
- Implementation remains planned. No migrations, Dart code, Flutter UI, tests, or
  hosted Supabase changes were started by this planning update.
- Verification run:
  - Planning docs were inspected for current milestone state before editing.
  - `rg -n "Milestone 26|M26|TRANSACTION_LABELS|REDESIGN|Design" docs/implementation-plan docs -g '*.md'`
  - `git diff --check`
  - Conflict-marker scan over the edited implementation-plan docs.
  - `rg -n "[ \t]+$" docs/implementation-plan/TRANSACTION_LABELS.md docs/implementation-plan/README.md docs/implementation-plan/DATA_MODEL.md docs/implementation-plan/MILESTONES.md docs/implementation-plan/SESSION_HANDOFF.md`
- Known gaps:
  - No markdown linter is configured or run for implementation-plan docs.
- Assumptions made:
  - User-facing term is "Labels".
  - Labels are household-shared.
  - V1 includes transaction-detail label editing, Transactions filtering, and a
    Settings label manager.
  - V1 edits one transaction at a time and does not include bulk label selection.
  - Used-label deletion detaches the label from all transactions after
    confirmation.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Docs Cleanup Notes

- Completed on 2026-06-12 as a documentation-only cleanup.
- Removed completed-only companion execution plans:
  - `docs/implementation-plan/CATEGORY_MANAGEMENT.md`
  - `docs/implementation-plan/TRANSACTION_METADATA_EDITING.md`
- Kept active/deferred companion plans and runbooks:
  - `docs/implementation-plan/PUSH_NOTIFICATIONS.md`
  - `docs/implementation-plan/TRANSACTION_LABELS.md`
  - `docs/implementation-plan/GMAIL_CONNECTOR.md`
  - `docs/implementation-plan/PRODUCTION_READINESS.md`
  - `docs/implementation-plan/WORKBOOK_IMPORT.md`
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/MILESTONES.md`, and this handoff so new-session
  routing no longer points at removed files and M22-M25 are marked completed in
  the milestone ledger.
- Verification run:
  - `git diff --check`
  - Active-link and routing scan for the removed filenames; only this cleanup
    note should retain those paths.
  - Conflict-marker scan over `docs/`.
  - `find docs -maxdepth 3 -type f | sort`
- Assumptions made:
  - Completed-only execution plans can be retired once their durable behavior is
    represented in `README.md`, `DATA_MODEL.md`, `MILESTONES.md`, and this
    handoff.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 26 Completion Notes

- Started on 2026-06-12 after Milestone 25 and the transaction-labels planning
  update completed. Milestones 18-21 remained deferred by explicit user request.
- Completed on 2026-06-12.
- Added household-scoped `public.labels` and `public.transaction_labels` with
  composite household ownership constraints, case-insensitive label uniqueness,
  RLS policies, authenticated-only table grants, and label assignment indexes.
- Added `public.v_label_usage` as a `security_invoker` Settings read path for
  label usage counts and recent use timestamps.
- Added app-facing `security invoker` RPCs:
  `set_transaction_labels`, `rename_household_label`, and
  `delete_household_label`.
- Extended the Flutter finance repository contract with label options, label
  manager snapshots, label mutation request/result types,
  `TransactionQuery.labelId`, transaction label lists, label mutation methods,
  and two-step label hydration for fetched transaction pages.
- Added focused pgTAP coverage for label creation/reuse, selected-transaction
  assignment replacement, duplicate-name handling, rename/delete semantics,
  viewer/non-member/cross-household rejection, and direct RLS isolation.
- Added focused Flutter repository-contract coverage for label query equality,
  fake label mutations, label filtering, rename usage snapshots, and delete
  detach behavior.
- Deferred by scope: Milestone 27 transaction labeling UI, Milestone 28 Settings
  label manager UI/regression, bulk labeling, label colors/icons, AI label
  suggestions, label reports, automatic workbook/Gmail labels, and all
  Milestone 18-21 push-notification work.
- Verification run:
  - `supabase --version` -> `2.105.0`
  - `supabase migration --help`
  - Supabase changelog/docs scan for relevant breaking changes before schema
    edits.
  - `supabase migration new labels_foundation`
  - `supabase db reset --local` attempted four times; each attempt applied all
    migrations including `20260612130532_labels_foundation.sql`, then failed
    after container restart while the CLI queried local Storage/Kong at
    `127.0.0.1:54321`.
  - `supabase test db --local supabase/tests/transaction_labels.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - Local privilege queries confirmed no `anon` access to `labels`,
    `transaction_labels`, or `v_label_usage`, and only `labels.name` has
    authenticated update privilege.
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `git diff --check`
- Known gaps:
  - The local Supabase reset command did not exit cleanly because local Kong and
    several non-DB services remained stopped after database recreation. Local DB
    tests, lint, and advisors passed after the migration applied.
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - Label rows are household-shared, app-facing, and independent from taxonomy,
    merchant rules, review rows, budgets, workbook import, and Gmail import.
  - Label assignment replacement is scoped to one selected transaction.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M26 label
    repository contracts and filtering behavior.

## Milestone 27 Completion Notes

- Started on 2026-06-12 from a dirty local checkout that already contained a
  partial transaction-label UX patch. Existing M27 edits were preserved and
  completed.
- Completed on 2026-06-12. Milestone 28 and Milestones 18-21 were not started.
- Added label chips to transaction list rows with compact display and `+N`
  overflow for long label sets.
- Added full label display to transaction detail and an Edit labels action.
- Added a one-transaction label editor bottom sheet that supports selecting
  existing labels, inline new-label creation, removing selected labels, disabled
  save state while unchanged/submitting, and user-visible save errors.
- Label saves use the existing finance repository `setTransactionLabels` API and
  refresh transaction, label lookup, and label manager providers.
- Added a single-label Transactions filter using route query param `labelId`,
  backed by `TransactionInitialFilters.labelId` and `TransactionQuery.labelId`;
  Clear filters clears the label filter and URL state.
- Added focused Flutter coverage for label display/overflow, route filtering,
  clear-filter behavior, opening the editor, saving an existing label to exactly
  one transaction, inline new-label creation, and removal of an existing label.
- Deferred by scope: Milestone 28 Settings label management, bulk labeling,
  label colors/icons, label reports, dashboard/trend label summaries, AI label
  suggestions, automatic workbook/Gmail labeling, Supabase changes, and all
  Milestone 18-21 push-notification work.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Known gaps:
  - No Supabase commands were run because M27 made no database changes.
  - No Android-emulator manual smoke was run.
- Assumptions made:
  - M27 remains app/UI-only on top of the M26 repository/database contract.
  - Label edits apply only to the selected transaction and must not alter
    merchant/category mappings or matching transactions from the same merchant.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M27 label
    editor, display, overflow, and filtering behavior.

## Milestone 28 Completion Notes

- Completed on 2026-06-12. Milestones 18-21 remained deferred and were not
  started.
- Added a Settings Labels manager with usage counts, refresh, create, rename,
  and delete actions.
- Added repository support for Settings-created unattached labels through the
  existing authenticated `labels` insert RLS contract.
- Label rename preserves the label ID through `renameHouseholdLabel` and
  refreshes label lookup, label-manager, and transaction-query providers.
- Label delete shows attached transaction count before confirmation, detaches
  the label from all transactions through `deleteHouseholdLabel`, preserves
  transaction rows and classification, and refreshes label lookup,
  label-manager, and transaction-query providers.
- Transactions clears an active label filter after label lookup refresh when the
  selected label no longer exists.
- Added focused Flutter coverage for Settings label create/rename/delete with
  impact confirmation, used-label detach while preserving transaction
  classification, active deleted-label filter clearing, and long labels in a
  narrow viewport.
- Deferred by scope: label colors/icons, label reports, dashboard/trend label
  summaries, bulk labeling, AI label suggestions, automatic workbook/Gmail
  labels, Supabase schema/RPC changes, and all Milestone 18-21 push-notification
  work.
- Verification run:
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Known gaps:
  - No Supabase commands were run because M28 made no schema/RPC changes.
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - Settings-created labels can use the existing authenticated `labels` insert
    RLS contract for unattached household labels instead of adding a new
    Supabase RPC.
  - Clearing an active deleted label filter after label lookup refresh is the
    deliberate stale-label behavior.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for Settings
    label create, rename, delete, detach, and active-filter regression coverage.

## Milestone 35 Completion Notes

- Completed on 2026-06-13. Milestones 18-21 remained deferred and were not
  started. No later milestone was started.
- Added final recurring-cap pgTAP coverage for selected stop-month returns,
  future-month hiding after stop, exact-month label assignment progress, and
  exact-month RPC viewer/non-member behavior.
- Updated Dashboard cap copy so empty and create states describe recurring caps
  starting from the selected month instead of isolated one-month cap records.
- Renamed the Dashboard cap section helper away from the legacy budget wording.
- Updated durable docs to describe the final recurring/carry-forward monthly cap
  contract: stable cap-series identity, selected-month-forward edits/deletes,
  optional positive/negative carry-forward, effective-cap progress,
  category/label OR matching, one-count-per-cap matching, allowed overlap, and
  compatibility roles for legacy cap tables/views.
- Verification run:
  - Supabase changelog/docs scan; the current Data API grant change and pgTAP
    testing guidance did not require schema changes for M35.
  - `supabase --version`
  - `supabase --help`
  - `supabase db --help`
  - `supabase test db --help`
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/monthly_caps.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Known gaps:
  - No hosted Supabase rollout or Android-emulator manual smoke was run.
  - No schema migration was added because M35 was regression/docs/active-copy
    cleanup only.
- Assumptions made:
  - The existing M32-M33 RPC/view behavior is the final backend contract for
    recurrence and carry-forward.
  - The non-member exact-month progress RPC should reject with the existing
    permission error rather than silently returning an empty list.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, with an empty cap list
    state for the new recurring-copy assertion.

## Milestone 34 Completion Notes

- Completed on 2026-06-13. Milestones 18-21 remained deferred and were not
  started. Milestone 35 was not started.
- Added a Dashboard `Carry forward remainder` toggle to the monthly cap
  create/edit sheet. New caps default to disabled; edit forms initialize from
  the active cap version for the selected month.
- Saved carry-forward changes through the existing
  `MonthlyCapUpsertRequest.carryForwardEnabled` field and existing Supabase
  `upsert_monthly_cap` RPC contract; no schema, migration, or RPC changes were
  needed for M34.
- Updated recurring copy so edits say they save from the selected month onward
  and stop confirmations say earlier months stay visible while transactions,
  categories, labels, merchant rules, and review rows stay unchanged.
- Updated Dashboard cap rows to render base cap, positive/negative carried
  amount, effective available cap, spent, left/over, percent, matched count,
  and target chips using repository-returned progress values.
- Added focused widget coverage for create/edit carry-forward behavior,
  selected-month-forward stop copy, positive and negative carry-forward rows on
  a narrow viewport, future active cap-month selection without transactions,
  and preserved cap add/edit/delete and category/merchant drilldowns.
- Verification run:
  - Supabase changelog scan before touching the Supabase-backed repository path;
    no M34-relevant breaking change required a code or schema adjustment.
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Known gaps:
  - No hosted Supabase rollout, Android-emulator manual smoke, or database
    reset was run because M34 used the existing M32-M33 backend contract and
    only changed Dashboard UX/tests/docs.
  - Cap drilldown, cap reports, push notifications, AI suggestions, shared
    templates, hosted rollout, and Milestone 35 regression/docs cleanup remain
    deferred.
- Assumptions made:
  - M33's `get_monthly_cap_progress` response remains the source of truth for
    carry-forward math; Flutter should display returned values rather than
    recomputing carry-forward.
  - `Stop cap` is clearer than `Delete cap` for the Dashboard action because
    the recurring series is stopped from the selected month forward and older
    months remain readable.
  - Existing fake finance repository/widget-test data is sufficient for M34
    because no backend contract changed.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended with
    carry-forward-enabled cap rows and a future active cap month without
    transaction spend.

## Milestone 33 Completion Notes

- Completed on 2026-06-13. Milestones 18-21 remained deferred and were not
  started. Milestone 34 was not started.
- Added the Supabase CLI-created migration
  `20260613131821_carry_forward_progress_semantics.sql`.
- Updated `public.get_monthly_cap_progress` and
  `public.v_monthly_cap_progress` so recurring caps derive carry-forward
  month by month in Postgres instead of returning zeroed carry fields.
- Preserved `cap_amount` as the backwards-compatible base amount alias while
  returning derived `base_cap_amount`, `carry_forward_enabled`,
  `carry_forward_amount`, `effective_cap_amount`, `remaining_amount`,
  `percent_used`, and `is_over_budget`.
- Kept matching semantics unchanged: `net_expense`, category OR label targets,
  one transaction counted once per cap, and overlapping caps allowed.
- Added pgTAP coverage for positive carry-forward, negative carry-forward,
  chained active months, disabled carry-forward resets, selected-month
  amount/target edits, refunds, and bill payments.
- Added a focused Flutter model parsing regression for carry-forward fields.
- Verification run:
  - Supabase changelog and official docs scan before schema edits; relevant
    noted items were Data API grants and `security_invoker` view guidance.
  - `supabase --version`
  - `supabase migration new --help`
  - `supabase migration new carry_forward_progress_semantics`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/monthly_caps.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `git diff --check`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
  - Dashboard carry-forward toggle/copy, cap drilldown, notifications, AI
    suggestions, hosted rollout, and Milestones 18-21 remain deferred.
- Assumptions made:
  - Carry-forward should apply only when both the current active version and
    the previous active month have carry-forward enabled; a disabled month
    resets that month and the following month's carry amount.
  - `cap_amount` remains the app-facing base cap alias for M33, while
    `effective_cap_amount` drives carry-forward-aware remaining and over-budget
    values.
  - `public.v_monthly_cap_progress` remains a compatibility view over version
    months, while exact selected-month Dashboard reads continue through
    `public.get_monthly_cap_progress`.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data; the M33 Flutter
    regression uses an inline JSON row to exercise `MonthlyCapProgress`
    carry-forward parsing.

## Milestone 32 Completion Notes

- Completed on 2026-06-13. Milestones 18-21 remained deferred and were not
  started. Milestone 33 was not started.
- Added the Supabase CLI-created migration
  `20260613124104_recurring_cap_series_foundation.sql` with recurring cap
  series, month-effective versions, versioned category/label targets, RLS,
  explicit authenticated grants, compatibility views, and backfill from
  existing M29-M31 monthly caps.
- Replaced active cap mutation behavior so `upsert_monthly_cap` creates a
  recurring series, edits write a selected-month version while leaving older
  months readable, and `delete_monthly_cap` stops the series from the selected
  month forward.
- Added `get_monthly_cap_progress` for exact-month recurring cap progress and
  `get_available_reporting_months` so recurring cap months can appear before
  transactions exist.
- Updated Flutter repository models, Dashboard delete wording, fake repository
  support, and docs while keeping carry-forward calculations and Dashboard
  carry-forward copy deferred.
- Added pgTAP and Flutter coverage for selected-month edit/delete behavior,
  zero-transaction recurring progress, cap-driven available months, and
  versioned target cleanup after category delete, category merge, and label
  delete.
- Verification run:
  - Supabase changelog scan before schema edits; relevant noted item was the
    2026 Data API grant change for new public tables.
  - `supabase --version`
  - `supabase migration new --help`
  - `supabase migration new recurring_cap_series_foundation`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/monthly_caps.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Known gaps:
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
  - Carry-forward calculations, carry-forward Dashboard copy, cap drilldown,
    notifications, AI suggestions, and hosted rollout remain deferred.
- Assumptions made:
  - `monthly_cap_id` remains the app-facing stable series ID, while the active
    month-effective row is exposed separately as `monthly_cap_version_id`.
  - `monthly_caps`, `monthly_cap_categories`, `monthly_cap_labels`, and
    `v_monthly_cap_progress` should remain as compatibility tables/views for
    migrated history, older SQL coverage, and lifecycle bridging.
  - Carry-forward stays disabled by default in M32; M33-M35 will add effective
    carry-forward calculations and visible carry-forward copy.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M32
    recurring cap version IDs, base amount/carry-forward fields, selected-month
    delete requests, and unchanged Dashboard create/edit/delete flows.

## Milestone 31 Completion Notes

- Completed on 2026-06-12. Milestones 18-21 remained deferred and were not
  started.
- Removed the remaining active Dashboard category-only cap assumption by
  replacing the old capped-category helper/copy with target-neutral monthly cap
  count and category-or-label target coverage text.
- Added monthly-cap pgTAP coverage for category target rename, label target
  rename, and transaction label assignment changes. Existing M29-M30 coverage
  continues to cover category delete, category merge, label delete, mixed-cap
  no-double-counting, allowed overlap, and Dashboard create/edit/delete flows.
- Updated durable docs to describe monthly caps as required named category/label
  target groups with OR matching, one-count-per-cap semantics, and allowed
  overlap. `category_caps` remains documented as migrated history, and
  `v_budget_progress` remains a category-only compatibility view.
- Verification run:
  - `supabase --version`
  - `supabase --help`
  - `supabase db --help`
  - `supabase test db --help`
  - `supabase db reset --help`
  - `supabase db lint --help`
  - `supabase db advisors --help`
  - Supabase changelog scan before Supabase verification.
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/monthly_caps.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format --set-exit-if-changed lib/src/data/repositories/finance_repository.dart lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
  - `rg -n "cappedCategoryCount|uncappedCategories|All categories capped|saveCategoryCap|BudgetProgress" apps/mobile`
- Known gaps:
  - `supabase db reset --local` applied all migrations through
    `20260612174258_monthly_cap_data_model_repository_foundation.sql`, then
    exited during container restart because the local Storage API at
    `127.0.0.1:54321` refused connection. Database tests, lint, and advisors
    passed afterward against the freshly reset local database.
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - Legacy `category_caps` and `v_budget_progress` should stay as compatibility
    history because migrations, compatibility tests, and older docs still
    intentionally reference them.
  - The Dashboard cap metric should count uncovered category and label target
    options together rather than exposing separate category-only wording.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for the
    Dashboard category-or-label target coverage metric.

## Milestone 30 Completion Notes

- Completed on 2026-06-12. Milestones 18-21 remained deferred and were not
  started. Milestone 31 was not started.
- Replaced the Dashboard category-chip cap creation affordance with a clear
  `Add cap` action in the Monthly caps section.
- Added a shared Dashboard cap bottom sheet for create/edit with required name,
  INR monthly amount, multi-select category chips, multi-select label chips,
  disabled Save until valid, and inline errors for blank name, invalid amount,
  and missing targets.
- Updated existing cap rows to show the cap name, spent amount, cap amount,
  remaining or over amount, percent progress, matched transaction count,
  category/label target chips, and edit/delete icon actions.
- Added edit flow support that opens the same form with existing name, amount,
  category targets, and label targets selected.
- Added delete confirmation that calls the repository `deleteMonthlyCap` path
  for only the cap and its targets.
- Refreshed Dashboard providers after create, edit, and delete, while keeping
  top category and top merchant drilldowns unchanged.
- Deferred by scope: cap-row transaction drilldown, cap reports, cap
  notifications, automatic label assignment, all Milestone 31 cleanup work, and
  all Milestone 18-21 push-notification work.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Known gaps:
  - No Supabase commands were run because M30 made no schema/RPC changes.
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - The M29 repository/RPC contract is the source of truth for deleting only cap
    rows and target rows; M30 did not add client-side transaction or taxonomy
    mutation paths.
  - Cap-row transaction drilldown remains deferred because cap matching is OR
    across categories and labels while current Transactions filters combine
    category and label filters as AND.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for Dashboard
    category-only, label-only, mixed cap create, validation, edit, delete,
    progress/target rendering, and existing drilldown regression coverage.

## Milestone 29 Completion Notes

- Completed on 2026-06-12. Milestones 18-21 remained deferred and were not
  started. Milestones 30-31 were not started.
- Added `public.monthly_caps`, `public.monthly_cap_categories`, and
  `public.monthly_cap_labels` with household ownership constraints, target
  uniqueness, first-day/nonnegative/nonblank checks, indexes, RLS, and
  authenticated-only grants.
- Added migration-time backfill from legacy `public.category_caps` into named
  monthly caps with one category target per legacy cap. App/view reads and
  writes now use monthly caps instead of `category_caps`.
- Added RLS-safe `upsert_monthly_cap` and `delete_monthly_cap` RPCs that
  validate signed-in profile/household write access, cap names, period month,
  amount, target ownership, and at least one category or label target.
- Added `public.v_monthly_cap_progress` as a security-invoker view with
  category OR label matching, one-count-per-transaction within each cap,
  overlap support across caps, deterministic target arrays/names, and progress
  metrics. `v_budget_progress` is retained as a category-only compatibility
  view over monthly caps.
- Updated category/label dependency behavior so category deletion removes cap
  targets and deletes caps left with no targets, category merge repoints and
  dedupes category targets without summing named caps, label deletion removes
  cap label targets and deletes caps left with no targets, and label rename
  needs no cap mutation.
- Updated Flutter repository contracts with monthly-cap progress/target models,
  RPC-backed upsert/delete requests/results, dashboard category/label option
  lists, and fake repository behavior while keeping the existing dashboard cap
  UI shape for Milestone 30.
- Verification run:
  - `supabase migration new monthly_cap_data_model_repository_foundation`
  - `supabase --version`
  - `supabase --help`
  - `supabase db --help`
  - `supabase migration --help`
  - `supabase migration new --help`
  - `supabase test db --help`
  - `supabase db lint --help`
  - `supabase db advisors --help`
  - `supabase db reset --help`
  - `supabase db query --help`
  - Supabase changelog/docs scan for relevant schema, RLS, grants, function,
    and security-invoker view guidance before schema edits.
  - `supabase db reset --local` applied all migrations through
    `20260612174258_monthly_cap_data_model_repository_foundation.sql`, then
    exited during container restart because the local Storage API at
    `127.0.0.1:54321` refused connection.
  - `supabase test db --local supabase/tests/monthly_caps.sql supabase/tests/summary_views.sql supabase/tests/category_taxonomy_delete.sql supabase/tests/category_taxonomy_merge.sql supabase/tests/transaction_labels.sql supabase/tests/rls_isolation.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --type security --level warn --fail-on none`
  - `supabase db advisors --local --type performance --level warn --fail-on none`
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
- Known gaps:
  - The local Supabase reset command did not exit cleanly because local
    non-database services remained stopped/unreachable after database
    recreation. The migration was applied and DB tests, lint, and advisors
    passed against the freshly migrated local database.
  - No hosted Supabase migration push or Android-emulator manual smoke was run.
- Assumptions made:
  - The existing dashboard category-cap edit affordance may keep creating
    single-category named monthly caps using the category name until the
    Milestone 30 multi-target UX replaces it.
  - Legacy `category_caps` remains as migrated history only and is not used for
    new app/view reads or writes.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M29
    monthly-cap progress, target option lists, RPC-backed upsert/delete behavior,
    category deletion/merge dependency behavior, and label deletion dependency
    behavior.

## Monthly Caps Planning Notes

- Completed on 2026-06-12 as a planning-only documentation update.
- Added `docs/implementation-plan/MONTHLY_CAPS.md` as the detailed fresh-thread
  implementation plan for Milestones 29-31.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/DATA_MODEL.md`, and
  `docs/implementation-plan/MILESTONES.md` so multi-target monthly caps are
  discoverable from the repo's standard planning entrypoints.
- Planned milestone sequence:
  - Milestone 29: Monthly Cap Data Model and Repository Foundation.
  - Milestone 30: Dashboard Multi-Target Cap UX.
  - Milestone 31: Monthly Caps Regression, Docs, and Cleanup.
- Implementation remains planned. No migrations, Dart code, Flutter UI, tests,
  or hosted Supabase changes were started by this planning update.
- Verification run:
  - Planning docs were inspected for current milestone state before editing.
  - `git status --short`
  - `rg -n "monthly caps|category caps|Monthly caps|category_caps|v_budget_progress|Milestone 28|Cross-Milestone|TRANSACTION_LABELS|Current milestone|Next recommended|Milestone Status|Transaction Labels" docs/implementation-plan/README.md docs/implementation-plan/DATA_MODEL.md docs/implementation-plan/MILESTONES.md docs/implementation-plan/SESSION_HANDOFF.md`
  - `git diff --check`
  - Conflict-marker scan over edited implementation-plan docs.
  - `rg -n "[ \t]+$" docs/implementation-plan/MONTHLY_CAPS.md docs/implementation-plan/README.md docs/implementation-plan/DATA_MODEL.md docs/implementation-plan/MILESTONES.md docs/implementation-plan/SESSION_HANDOFF.md`
- Known gaps:
  - No markdown linter is configured or run for implementation-plan docs.
- Assumptions made:
  - User selected required cap names.
  - User selected allowing overlapping caps.
  - Cap targets are top-level categories and transaction labels in this
    sequence.
  - Cap-row drilldown is deferred because cap target matching is OR while
    current Transactions category/label filters combine as AND.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Recurring Monthly Caps Planning Notes

- Completed on 2026-06-13 as a planning-only documentation update.
- Updated `docs/implementation-plan/MONTHLY_CAPS.md` with a fresh-thread
  implementation plan for recurring monthly caps and optional carry-forward.
- Updated `docs/implementation-plan/README.md`,
  `docs/implementation-plan/DATA_MODEL.md`, and
  `docs/implementation-plan/MILESTONES.md` so recurring cap carry-forward is
  discoverable from the repo's standard planning entrypoints.
- Planned milestone sequence:
  - Milestone 32: Recurring Cap Series Foundation.
  - Milestone 33: Carry-Forward Progress Semantics.
  - Milestone 34: Dashboard Carry-Forward UX.
  - Milestone 35: Recurring Caps Regression, Docs, and Cleanup.
- Implementation remains planned. No migrations, Dart code, Flutter UI, tests,
  hosted Supabase changes, staging, commits, or branch changes were started by
  this planning update.
- Verification run:
  - Planning docs and current monthly-cap implementation context were inspected
    before editing.
  - `git status --short`
  - `git diff --check`
  - Conflict-marker scan over edited implementation-plan docs.
  - Trailing-whitespace scan over edited implementation-plan docs.
- Known gaps:
  - No markdown linter is configured or run for implementation-plan docs.
- Assumptions made:
  - Every newly created monthly cap should be recurring after Milestone 32.
  - Carry-forward is optional and defaults off.
  - Carry-forward can be positive or negative and should be derived from
    prior-month progress, not manually entered.
  - Edits and deletes apply from the selected month forward while prior months
    remain historical.
  - Milestones 18-21 remain deferred unless explicitly resumed.
- Mocks created:
  - None.
- Mocks used:
  - None.
