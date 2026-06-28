# SpendLens Implementation Plan

This folder is the durable planning context for building SpendLens across multiple Codex sessions.

Read these documents in order at the start of every new implementation thread:

1. [Architecture](ARCHITECTURE.md)
2. [Data Model](DATA_MODEL.md)
3. [Ingestion Design](INGESTION.md)
4. [Milestones](MILESTONES.md)
5. [External Setup Checklist](EXTERNAL_SETUP.md)
6. [Gmail Connector](GMAIL_CONNECTOR.md)
7. [Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md) as the completed-only
   reference for Milestones 65-69
8. [Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md) as the
   completed-only reference for Milestones 70-73
9. [Regex Backend Migration](REGEX_BACKEND_MIGRATION.md) as the completed-only
   reference for Milestones 74-77 and when touching merchant mapping
   regex/rule matching
10. [Production Readiness](PRODUCTION_READINESS.md)
11. [Push Notifications](PUSH_NOTIFICATIONS.md) when executing Milestones 18-21
12. [Transaction Labels](TRANSACTION_LABELS.md) when executing Milestones 26-28
13. [Monthly Caps](MONTHLY_CAPS.md) when executing Milestones 29-35
14. [Monthly Cap Drilldown](MONTHLY_CAP_DRILLDOWN.md) as the completed-only
    reference for Milestones 78-81 and when touching cap drilldown behavior
15. [Bill-Payment Category Semantics](BILL_PAYMENT_CATEGORY_SEMANTICS.md) as
    the active plan for Milestones 82-85 and when touching
    `Payments/Credits (not expense)` transaction-type semantics
16. [UI Redesign](UI_REDESIGN.md) when executing Milestones 37-51
17. [Transaction Deletion](TRANSACTION_DELETION.md) when executing Milestones
    52-55
18. [Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md) as the completed-only
    reference for Milestones 56-60
19. [Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md) as the
    completed-only reference for Milestones 61-64
20. [Session Handoff](SESSION_HANDOFF.md)

Completed-only companion execution plans are removed after their durable
behavior has been folded into this README, [Data Model](DATA_MODEL.md),
[Milestones](MILESTONES.md), and [Session Handoff](SESSION_HANDOFF.md).

## Product Summary

SpendLens is a personal and household expense intelligence app. The current implementation plan is Android-first: build the Flutter Android app first and defer iOS and web until later.

The app imports historical credit-card analysis from `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`, then moves to ongoing ingestion from Gmail transaction emails for credit cards and UPI. It presents spend by category, named monthly caps with category and label targets, recurring cap carry-forward semantics, Dashboard-context cap transaction drilldowns, transaction details, merchant review workflows, Activity list and chart views, manual piggy-bank ledgers surfaced as Vaults, backend-mediated Gemini expense Q&A, household category management, transaction labels, owner-only transaction deletion with source tombstones and workbook/Gmail resurrection suppression, merchant autocomplete with close-match duplicate guarding, Settings merchant group management, backend-owned regex merchant mapping, planned `Payments/Credits (not expense)` bill-payment semantics, and planned Android push notifications for newly processed transactions. Milestones 37-51 completed the UI redesign that consolidated Transactions and Trends into Activity, presented Piggy Banks as Vaults, removed Settings from primary navigation, and added local light/dark/system theme support.

## Architecture Decision

Use a serverless-first backend:

- Flutter Android app.
- iOS app deferred to a later phase.
- Web interface deferred to a later phase.
- Supabase Auth for user identity.
- Supabase Postgres for relational finance data.
- Supabase Row Level Security for household-level data isolation.
- Supabase Edge Functions for privileged backend operations.
- Supabase Queues or job tables for async work.
- Google Gmail API plus Cloud Pub/Sub for mailbox push notifications.
- Firebase Cloud Messaging for Android push delivery after transaction
  processing.
- Dedicated worker service only when AI or ingestion workloads outgrow Edge Functions.

This is not a "no backend" architecture. It is a backend without a permanently running custom API server in v1.

## Scope Defaults

- Usage model: personal plus household.
- Currency: INR.
- Monthly caps: required-name recurring caps can target multiple categories
  and/or multiple labels. Edits and deletes apply from the selected month
  forward while prior months remain readable. Optional positive or negative
  carry-forward is calculated in Postgres and shown on Dashboard as base,
  carried, effective available, spent, remaining/over, percent, matched count,
  and target details. Dashboard cap rows open a dedicated view-only
  cap-transaction screen for the selected month; membership is read from the
  monthly-cap transaction RPC rather than approximated with Activity filters,
  and `Under review` means an open Review queue item for that transaction.
- Piggy banks: manual ledger accounts in v1.
- Merchant corrections: apply to matching past and future transactions.
- Transaction metadata edits: apply to the matching normalized statement merchant
  and future imports unless a milestone explicitly narrows scope.
- Bill-payment category semantics: Milestone 82 created the active companion
  plan for making the exact household category name
  `Payments/Credits (not expense)` force `bill_payment_credit` transaction
  shape with zero gross/net expense, plus a Dashboard bills-paid KPI.
  Because the planned rule is name-based, category renames to or from the exact
  name should reshape affected transactions when M83 implements the database
  invariant.
  Milestones 83-85 remain planned; do not treat this behavior as implemented
  until those milestones complete.
- Category management: category/subcategory creation, rename, add, delete, and
  merge are app-facing and household-scoped; renames preserve IDs; category
  deletion requeues affected transactions for Review; category merge requires
  explicit subcategory mapping.
- Transaction labels: household-shared reusable labels attach only to selected
  transaction rows; Settings manages the shared label vocabulary with usage
  counts and delete-with-detach confirmation. Label changes do not alter
  merchant mapping, categories, review state, monthly caps, summaries, or future
  imports.
- Transaction deletion: Milestone 52 added the owner-only Postgres hard-delete
  contract, minimal household-scoped source tombstones, cascade/unlink behavior,
  and database regression coverage. Milestone 53 made workbook and Gmail
  ingestion suppress tombstoned source fingerprints with adjusted importer
  validation and sanitized Gmail diagnostics. Milestone 54 exposed owner-only
  deletion from Activity transaction details with confirmation, provider
  refreshes, and narrow-layout coverage. Milestone 55 verified the full local
  deletion regression path across database, importer, Edge Functions, Flutter
  tests, and Android debug build, then closed the companion plan as
  completed-only.
- Merchant autocomplete: Milestone 56 created the companion plan for canonical
  merchant suggestions in Activity search and the shared transaction metadata
  editor. Milestone 57 added canonical merchant filtering to Activity while
  preserving free-text statement merchant search. Milestone 58 added shared
  metadata-editor merchant autocomplete for Activity and Review edits, including
  compatible category/subcategory selection from existing merchant options.
  Milestone 59 added close-match save confirmation and exact existing-name
  canonicalization in the shared metadata editor. Milestone 60 completed final
  Flutter regression and docs cleanup, confirmed no schema or RPC migration was
  needed, and left `MERCHANT_AUTOCOMPLETE.md` as a completed-only reference.
- Merchant group management: Milestone 61 created the companion plan for
  Settings-based canonical merchant group rename and merge. Milestone 62 added
  the RLS-safe data/repository contract: `public.v_merchant_group_usage`,
  `rename_household_merchant(...)`, `merge_household_merchants(...)`, Flutter
  repository request/result models, and canonical Dashboard merchant grouping.
  The contract treats `public.merchants` as the group source of truth, renames
  by preserving merchant IDs, merges by moving aliases/rules/transactions/open
  review suggestions to a destination merchant, deletes source merchant rows
  after references move, and requires the user to choose whether merge category
  fields are preserved or replaced by the destination merchant
  category/subcategory. Milestone 63 added the Settings Merchant groups section
  with rename, merge, explicit category strategy selection, impact summaries, and
  provider refreshes. Milestone 64 completed final local regression/docs
  cleanup, confirmed Settings rename/merge writes remain RPC-backed, and left
  `MERCHANT_GROUP_MANAGEMENT.md` as a completed-only reference.
- Gmail label ingestion: Milestone 65 created the companion plan for moving
  HDFC Gmail ingestion from Inbox/sender/subject candidate discovery to the
  readonly Gmail label `Banking/HDFC Transactions`. Milestone 66 added watched
  label storage, exact label resolution, label-filtered Gmail watch renewal,
  history/backfill discovery, and thread-message filtering while keeping Gmail
  OAuth readonly. Milestone 67 added body-first parser routing, the
  `Netbanking :: IMPS` source/candidate type, sanitized `other` watched-label
  parse failures, and IMPS source-reference fingerprinting. Milestone 68 added
  persistent household-wide `Ignore for now` handling for visible sanitized
  parse failures in Review. Milestone 69 completed the final local
  regression/docs cleanup and left `GMAIL_LABEL_INGESTION.md` as a
  completed-only reference.
- Gmail parse failure review: Milestone 70 created the companion plan for
  paginated Review access to all unignored Gmail parse failures and on-demand
  plain-text email body viewing from a parse-failure row. Milestone 71 added
  the authenticated row-scoped body fetch contract plus repository pagination
  plumbing while keeping raw body storage out of Postgres/logs. Milestone 72
  added visible Review pagination, `Load more` and retry states, `View email`
  row actions, a transient selectable plain-text body dialog, and
  ignore-safe pagination behavior. Milestone 73 completed final local
  regression/docs cleanup, documented that historical skipped messages require
  explicit backfill/resync before Review can show them, and left
  `GMAIL_PARSE_FAILURE_REVIEW.md` as a completed-only reference.
- Regex backend migration: Milestone 74 created the companion plan for making
  Postgres the source of truth for merchant mapping rule evaluation, including
  regex rules. Milestone 75 hardened backend matching guardrails, made invalid
  regex rules fail closed, normalized non-regex patterns, preserved
  deterministic rule ranking, and added the read-only
  `classify_statement_merchant(...)` detail helper for future import clients.
  Milestone 76 moved workbook importer classification onto that backend helper
  and removed JavaScript-side rule sorting/regex matching from live imports.
  Milestone 77 verified the focused local Supabase and workbook importer
  regression path, confirmed backend-owned exact/contains/prefix/suffix/regex
  rule behavior across Gmail and workbook ingestion, and left
  `REGEX_BACKEND_MIGRATION.md` as a completed-only reference.
- Monthly cap drilldown: Milestone 78 created the companion plan for opening a
  view-only Dashboard-context transaction screen from each monthly cap row.
  Milestone 79 added the `get_monthly_cap_transactions(...)` RPC, Flutter
  repository models, and provider. Milestone 80 added the Dashboard child route,
  tappable cap rows, paginated view-only screen, open-review highlighting,
  invalid/stale states, and Back-to-Dashboard behavior. Milestone 81 verified
  the combined local Supabase and Flutter regression path and left
  `MONTHLY_CAP_DRILLDOWN.md` as completed-only. The screen must not redirect
  to Activity or approximate cap membership with Activity filters.
- Multi-target monthly caps: required-name recurring caps can include multiple
  categories, multiple labels, or both. A transaction counts once inside a cap
  when any selected category or label matches; overlapping caps are allowed.
  Recurring cap edits/deletes apply from the selected month forward and can
  optionally carry positive or negative remainder into the next month.
- Email retention: store minimal parsed data only; do not retain raw email bodies by default.
- AI: backend-mediated Gemini expense Q&A and transaction metadata suggestions; dev/staging use free-tier-only mode with Suggest search disabled by default.
- Android push notifications: Firebase Cloud Messaging delivery, Supabase
  device registration, and Supabase-managed notification outbox.
- UI redesign: `DESIGN.md` is the visual design-system source of truth.
  Stitch references under `docs/design-references/stitch/themed-dashboard-ui-redesign`
  are layout references only. The redesigned primary navigation is Dashboard,
  Activity, Review, and Vaults; Settings is a focused page opened from a global
  settings action. Theme mode supports system, light, and dark, with system as
  the default and local device persistence. Milestone 51 completed responsive
  and theme regression coverage at 390px, 768px, and 1024px widths and confirmed
  the final UI behavior in durable docs.
- iOS app: deferred, not part of the current implementation milestones.
- Web interface: deferred, not part of the current implementation milestones.

## Workbook Source Contract

The existing workbook is the seed data source and source-of-truth for initial semantics:

- `Transactions`: canonical historical transaction rows.
- `Category Summary`: initial category spend summaries.
- `Merchant Summary`: initial merchant/category mapping data.
- `Monthly`: initial monthly spend trend validation.
- `Cardholders`: household/cardholder seed data.
- `Needs Review`: initial low-confidence review queue.
- `Validation`: reconciliation checks for import correctness.
- `Sources & Notes`: import notes and merchant source URLs.

The workbook currently contains 475 FY 2025-26 transactions. Card bill payments are excluded from spend. Merchant refunds reduce net expense.

## New Session Guidance

When starting a new implementation thread:

1. Read this `README.md`.
2. Read [Architecture](ARCHITECTURE.md) and [Data Model](DATA_MODEL.md).
3. Read the active milestone in [Milestones](MILESTONES.md).
4. Read [UI Redesign](UI_REDESIGN.md) when executing Milestones 37-51.
5. Read [Transaction Deletion](TRANSACTION_DELETION.md) when executing
   Milestones 52-55.
6. Read [Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md) when touching
   merchant search/autocomplete or metadata-editor duplicate guarding.
7. Read [Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md) when touching
   merchant group rename/merge behavior.
8. Read [Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md) as completed
   reference material when touching label-based Gmail ingestion behavior.
9. Read [Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md) as
   completed reference material when touching Review parse-failure body viewing.
10. Read [Regex Backend Migration](REGEX_BACKEND_MIGRATION.md) as the
    completed-only reference when touching merchant mapping regex/rule matching.
11. Read [Monthly Cap Drilldown](MONTHLY_CAP_DRILLDOWN.md) as completed
    reference material when touching cap drilldown behavior.
12. Read [Bill-Payment Category Semantics](BILL_PAYMENT_CATEGORY_SEMANTICS.md)
    when executing Milestones 82-85 or touching `Payments/Credits (not expense)`
    transaction-type semantics.
13. Check [Session Handoff](SESSION_HANDOFF.md) for current status.
14. Do only that milestone unless the user explicitly expands scope.
15. Preserve documented invariants, especially idempotency, RLS isolation, and no raw email retention.
16. Update milestone notes when an implementation decision changes the plan.

## Clarification Rule

Codex must not silently choose product, architecture, schema, package naming, deployment, billing, or external-service values that are not already documented here or explicitly confirmed by the user.

When a decision is needed:

- Ask the user before proceeding.
- Suggest a recommended value or option when useful.
- Wait for explicit confirmation before implementing that choice.
- Do not treat a recommendation in these docs as approval if the concrete value is still missing.

Codex may still inspect the repository and use discovered facts, such as existing file names, current code structure, package versions, and committed configuration. The clarification rule applies to undecided choices, not discoverable repo facts.
