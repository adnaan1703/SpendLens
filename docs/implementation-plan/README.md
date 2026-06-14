# SpendLens Implementation Plan

This folder is the durable planning context for building SpendLens across multiple Codex sessions.

Read these documents in order at the start of every new implementation thread:

1. [Architecture](ARCHITECTURE.md)
2. [Data Model](DATA_MODEL.md)
3. [Ingestion Design](INGESTION.md)
4. [Milestones](MILESTONES.md)
5. [External Setup Checklist](EXTERNAL_SETUP.md)
6. [Gmail Connector](GMAIL_CONNECTOR.md)
7. [Production Readiness](PRODUCTION_READINESS.md)
8. [Push Notifications](PUSH_NOTIFICATIONS.md) when executing Milestones 18-21
9. [Transaction Labels](TRANSACTION_LABELS.md) when executing Milestones 26-28
10. [Monthly Caps](MONTHLY_CAPS.md) when executing Milestones 29-35
11. [UI Redesign](UI_REDESIGN.md) when executing Milestones 37-51
12. [Transaction Deletion](TRANSACTION_DELETION.md) when executing Milestones
    52-55
13. [Session Handoff](SESSION_HANDOFF.md)

Completed-only companion execution plans are removed after their durable
behavior has been folded into this README, [Data Model](DATA_MODEL.md),
[Milestones](MILESTONES.md), and [Session Handoff](SESSION_HANDOFF.md).

## Product Summary

SpendLens is a personal and household expense intelligence app. The current implementation plan is Android-first: build the Flutter Android app first and defer iOS and web until later.

The app imports historical credit-card analysis from `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`, then moves to ongoing ingestion from Gmail transaction emails for credit cards and UPI. It presents spend by category, named monthly caps with category and label targets, recurring cap carry-forward semantics, transaction details, merchant review workflows, Activity list and chart views, manual piggy-bank ledgers surfaced as Vaults, backend-mediated Gemini expense Q&A, household category management, transaction labels, owner-only transaction deletion with source tombstones and workbook/Gmail resurrection suppression, and planned Android push notifications for newly processed transactions. Milestones 37-51 completed the UI redesign that consolidated Transactions and Trends into Activity, presented Piggy Banks as Vaults, removed Settings from primary navigation, and added local light/dark/system theme support.

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
  and target details.
- Piggy banks: manual ledger accounts in v1.
- Merchant corrections: apply to matching past and future transactions.
- Transaction metadata edits: apply to the matching normalized statement merchant
  and future imports unless a milestone explicitly narrows scope.
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
  validation and sanitized Gmail diagnostics. Milestones 54-55 remain planned
  for Activity UI and final regression/docs cleanup.
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
6. Check [Session Handoff](SESSION_HANDOFF.md) for current status.
7. Do only that milestone unless the user explicitly expands scope.
8. Preserve documented invariants, especially idempotency, RLS isolation, and no raw email retention.
9. Update milestone notes when an implementation decision changes the plan.

## Clarification Rule

Codex must not silently choose product, architecture, schema, package naming, deployment, billing, or external-service values that are not already documented here or explicitly confirmed by the user.

When a decision is needed:

- Ask the user before proceeding.
- Suggest a recommended value or option when useful.
- Wait for explicit confirmation before implementing that choice.
- Do not treat a recommendation in these docs as approval if the concrete value is still missing.

Codex may still inspect the repository and use discovered facts, such as existing file names, current code structure, package versions, and committed configuration. The clarification rule applies to undecided choices, not discoverable repo facts.
