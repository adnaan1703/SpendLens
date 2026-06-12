# Transaction Labels Plan

Last updated: 2026-06-12

This document is the implementation plan for household-shared transaction labels
in SpendLens. Each milestone below is a standalone milestone intended to be
executed in a separate Codex thread. Stop after completing and documenting the
current milestone; do not automatically continue to the next milestone.

## Target Behavior

SpendLens users can attach reusable labels to individual transactions. Labels
are different from categories:

- A category is transaction classification and can drive merchant mapping,
  review, budgets, summaries, and future import behavior.
- A label is a free-form marker on selected transaction rows only.

Labels are household-shared in v1. Any household member can see labels used in
the household, and household writers can create, reuse, rename, attach, detach,
and delete labels according to RLS. Attaching a label to one transaction must not
attach it to other transactions from the same merchant, statement merchant,
category, or import source.

The first label version should support:

- Creating or reusing labels while editing one transaction.
- Attaching and removing labels from one transaction at a time.
- Showing compact label chips in transaction list rows and transaction details.
- Filtering Transactions by one selected label.
- Managing the household label vocabulary from Settings with create, rename,
  usage counts, and delete-with-impact confirmation.

Deleting a used label detaches it from all transactions after confirmation.
Transactions are never deleted, unclassified, requeued to Review, or otherwise
mutated beyond label assignments.

## Existing Foundation

- `public.transactions` is the canonical household-scoped transaction ledger.
- Transaction list/detail UI lives in
  `apps/mobile/lib/src/features/transactions/transactions_screen.dart`.
- Transaction metadata editing already opens from transaction detail through
  `apps/mobile/lib/src/features/transaction_metadata/transaction_metadata_editor.dart`.
- Settings already contains management cards in
  `apps/mobile/lib/src/features/settings/settings_screen.dart`.
- Flutter finance data flows through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`, with
  Riverpod providers for transaction queries and Settings management surfaces.
- Existing transaction filters use `TransactionQuery`, `transactionsProvider`,
  and route query parameters such as `categoryId`, `merchant`, `startDate`, and
  `endDate`.
- The repo standard for app-facing Supabase writes is authenticated,
  household-scoped, RLS-safe `security invoker` RPCs.
- The repo standard verification path is local Supabase reset/tests/lint,
  local advisors with `--fail-on none`, Flutter analyze, focused Flutter widget
  tests, full Flutter tests, and a debug Android build when UI behavior changes.

## Global Rules For M26-M28

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, or prepare later milestones unless the user
  explicitly asks to proceed.
- Preserve Android-first scope. Do not add iOS or web-specific label work in
  this sequence.
- Use the user-facing term "Labels". Avoid switching UI copy to "Tags" unless
  the user explicitly asks.
- Labels are household-shared, not private per profile.
- Label mutations must be household-scoped and RLS-safe. Use authenticated
  app-facing `security invoker` RPCs for create/reuse/rename/delete and
  transaction assignment mutations.
- Do not use service-role credentials, Edge Functions, or privileged Flutter
  client code for label management.
- Create migrations with `supabase migration new <descriptive_name>` when
  implementation starts. Do not invent migration filenames.
- Keep labels independent from taxonomy and merchant rules. Do not update
  `category_id`, `subcategory_id`, `merchant_id`, `merchant_mapping_rules`,
  Review items, category caps, workbook importer mapping, or Gmail future
  mapping behavior when labels change.
- Editing labels affects only the selected transaction's label assignments in
  v1. Do not add bulk multi-select labeling unless the user explicitly expands
  scope.
- Deleting a label detaches it from all transactions after a confirmation that
  shows usage impact. Do not delete transactions or send them to Review.
- Add focused pgTAP and Flutter tests in the same milestone as the behavior
  change.
- At completion, update `SESSION_HANDOFF.md` and include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M26 - Labels Data Model And Repository Foundation

Purpose: Add the database, RLS, RPC, repository, and test foundation for
household-shared labels before exposing the UI.

Instructions:

- Start by reading:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `supabase/migrations/20260604203957_create_spendlens_foundation.sql`
  - `supabase/migrations/20260608195329_transaction_metadata_editing.sql`
  - relevant category-management RPC migrations for the current RLS/RPC style
  - `supabase/tests/transaction_metadata_editing.sql`
  - `supabase/tests/category_creation.sql`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Before implementing Supabase changes, run `supabase --version`,
  `supabase migration --help`, and scan `https://supabase.com/changelog.md` for
  relevant breaking changes.
- Add a migration created with the Supabase CLI for label foundation.
- Add `public.labels`:
  - `id uuid primary key default gen_random_uuid()`
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `name text not null`
  - `created_by uuid references public.profiles(id) on delete set null`
  - `created_at timestamptz not null default now()`
  - `updated_at timestamptz not null default now()`
  - `unique (id, household_id)`
  - nonblank trimmed-name check
  - case-insensitive unique index on `(household_id, lower(name))`
- Add `public.transaction_labels`:
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `transaction_id uuid not null`
  - `label_id uuid not null`
  - `created_by uuid references public.profiles(id) on delete set null`
  - `created_at timestamptz not null default now()`
  - primary key `(transaction_id, label_id)`
  - foreign key `(transaction_id, household_id)` to `public.transactions(id, household_id)` on delete cascade
  - foreign key `(label_id, household_id)` to `public.labels(id, household_id)` on delete cascade
- Add indexes for label lookup and transaction filtering:
  - `labels_household_id_idx`
  - `transaction_labels_household_label_idx` on `(household_id, label_id)`
  - `transaction_labels_household_transaction_idx` on `(household_id, transaction_id)`
- Enable RLS on both tables.
- Add RLS policies:
  - Household members can select labels and transaction-label assignments.
  - Household writers can create/update/delete labels.
  - Household writers can create/delete transaction-label assignments.
  - Policies must include household ownership predicates, not only `TO authenticated`.
- Grant only the required table privileges to `authenticated`; do not grant access
  to `anon`.
- Add app-facing RPCs:
  - `public.set_transaction_labels(p_household_id uuid, p_transaction_id uuid, p_label_ids uuid[] default '{}', p_new_label_names text[] default '{}')`
    - `security invoker` and empty `search_path`.
    - Requires a signed-in profile and household write access.
    - Validates the transaction belongs to the household.
    - Validates all provided label IDs belong to the household.
    - Trims new label names, rejects blanks, reuses existing labels by
      case-insensitive name, and inserts genuinely new labels.
    - Replaces the selected transaction's label assignments with the final
      distinct label set.
    - Returns ordered label rows for the transaction.
  - `public.rename_household_label(p_household_id uuid, p_label_id uuid, p_name text)`
    - Requires household write access.
    - Trims and rejects blank names.
    - Rejects case-insensitive duplicates in the household.
    - Preserves the label ID and returns the updated label.
  - `public.delete_household_label(p_household_id uuid, p_label_id uuid)`
    - Requires household write access.
    - Counts attached transactions, deletes assignments through cascade or
      explicit delete, deletes the label, and returns detached transaction count.
- Add a read path for Settings usage:
  - Prefer a `security_invoker` view or repository query that returns each label
    with attached transaction count and recent-use timestamp.
  - The view/query must remain household-scoped and must not expose another
    household's label names or transactions.
- Extend Dart repository contracts:
  - Add `TransactionLabel` or `LabelOption`.
  - Add `LabelManagerSnapshot` or equivalent Settings model with usage counts.
  - Add request/result types for setting transaction labels, renaming labels, and
    deleting labels.
  - Add `FinanceRepository` methods and disabled/fake implementations for label
    fetch and mutation.
  - Extend `TransactionQuery` with nullable `labelId`, equality, hash, and
    `copyWith` support.
  - Extend `FinanceTransaction` with `labels`, defaulting to an empty list.
- Update `SupabaseFinanceRepository.fetchTransactions` so fetched transaction
  rows include labels without duplicating transactions in the returned page.
  Prefer a two-step lookup by returned transaction IDs if embedded PostgREST joins
  would make pagination fragile.
- Add pgTAP tests for:
  - Label creation/reuse through `set_transaction_labels`.
  - Replacement of labels for only the selected transaction.
  - Case-insensitive duplicate-name rejection or reuse as appropriate per RPC.
  - Rename success and duplicate rejection.
  - Delete detaches assignments and preserves transactions.
  - Viewer and non-member mutation rejection.
  - Cross-household label ID and transaction ID rejection.
  - RLS isolation for direct table access.

Expected code shape:

- Keep label assignment transactional inside RPCs. A failed validation must leave
  label rows and transaction-label assignments unchanged.
- Keep direct client sequencing simple: the app asks for final labels for one
  transaction, and the RPC performs create/reuse/replace atomically.
- Keep labels independent from transaction classification fields and review
  metadata.

Acceptance criteria:

- The local database has household-scoped `labels` and `transaction_labels` with
  RLS, grants, constraints, indexes, and RPCs.
- Household writers can create/reuse labels and replace labels for exactly one
  transaction through the RPC.
- Household writers can rename and delete labels; delete detaches assignments and
  leaves transactions intact.
- Viewers and non-members cannot mutate labels or assignments.
- Flutter repository models can fetch transactions with label lists and issue
  label mutations through the repository contract.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M27 - Transaction Labeling UX

Purpose: Let users see, create, attach, remove, and filter labels from
transaction surfaces without adding bulk editing.

Instructions:

- Start by reading the M26 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/lib/src/features/transaction_metadata/transaction_metadata_editor.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Add label chips to transaction list rows:
  - Show compact chips below or within the existing subtitle area without
    crowding amount/date/category text.
  - Cap visible chips in list rows and show `+N` overflow for long label sets.
  - Keep mobile/narrow viewport layout stable.
- Add label display to transaction detail:
  - Show all labels for the transaction.
  - Add an edit labels action in the transaction detail bottom sheet.
- Add a transaction-label editor:
  - It may be a small dedicated dialog/bottom sheet rather than expanding the
    existing classification metadata editor.
  - It must support selecting existing labels, creating new labels inline by
    name, removing labels, save-disabled state while submitting, and SnackBar or
    inline error display for RPC failures.
  - The copy must make scope clear: labels apply only to this transaction.
  - Save through the repository method backed by `set_transaction_labels`.
- Refresh providers after save:
  - Current transaction query.
  - Label lookup/manager providers.
  - Any active Settings label provider if it exists from M26.
  - Dashboard/trends/review providers are not required unless the implementation
    later makes them label-aware.
- Add a single-label Transactions filter:
  - Add `labelId` to `TransactionInitialFilters.fromUri`.
  - Add `labelId` to `TransactionQuery`.
  - Add a label dropdown/chip filter alongside existing transaction filters.
  - Apply the filter through the repository query using `transaction_labels`.
  - Clear filters must clear `labelId`.
  - Route query param is `labelId`.
- Do not add multi-select or bulk label assignment in this milestone.
- Do not add label trend reports or dashboard summaries in this milestone.
- Add Flutter widget tests for:
  - Transaction list displays labels and overflow.
  - Transaction detail opens the label editor.
  - Existing label selection saves only the selected transaction.
  - Inline new label creation submits the expected request.
  - Removing a label submits the expected request.
  - `labelId` route/filter applies to `TransactionQuery`.
  - Clear filters removes the label filter.

Expected code shape:

- Prefer a small reusable label editor widget under the Transactions feature or a
  narrow `features/labels` folder if the widget/model surface becomes shared by
  Settings in M28.
- Keep transaction classification metadata editing separate from labels unless a
  small shared helper improves the user flow without coupling label saves to
  merchant/category saves.
- Keep route/query state consistent with existing transaction filter patterns.

Acceptance criteria:

- A household writer can attach existing labels to a selected transaction from
  transaction detail.
- A household writer can create a new label inline and attach it to the selected
  transaction.
- A household writer can remove labels from the selected transaction.
- Labels appear on transaction list rows and transaction detail after save.
- Filtering Transactions by one label returns only transactions attached to that
  label.
- Label edits do not update other transactions from the same merchant or create
  merchant mapping rules.

Verification:

```bash
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Completed on 2026-06-12 from the existing partial M27 local patch.
- Transaction list rows now show compact label chips with overflow, and
  transaction detail shows all labels with an Edit labels action.
- The transaction label editor saves through `setTransactionLabels`, supports
  existing-label selection, inline new-label creation, removal, disabled save
  states, and user-visible errors.
- Transactions supports a single-label filter through route query param
  `labelId`; Clear filters removes the label filter and resets route query
  parameters.
- Label saves refresh the current transaction query plus label lookup/manager
  providers.
- Focused widget tests cover display/overflow, detail editor opening, existing
  label save to one transaction, inline new-label creation, label removal,
  `labelId` route/filter behavior, and clear-filter behavior.
- Verification run:
  - `cd apps/mobile && dart format lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Assumptions made:
  - M27 is UI-only on top of the M26 label repository/database contract.
  - Label edits are scoped to exactly one selected transaction and do not update
    merchant/category mappings.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for M27 label UI
    and filtering coverage.
- Deferred by scope:
  - M28 Settings label management, bulk labeling, label colors/icons, label
    reports, dashboard/trend label summaries, AI label suggestions, automatic
    workbook/Gmail labels, Supabase changes, and M18-M21 push notifications.

## M28 - Settings Label Manager And Regression

Purpose: Add household label vocabulary management in Settings and harden the
full label workflow.

Instructions:

- Start by reading M26 and M27 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `apps/mobile/lib/src/features/settings/settings_screen.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
- Add a Labels card or section in Settings:
  - List household labels ordered by name or recent usage.
  - Show transaction usage count for each label.
  - Provide create, rename, and delete actions.
  - Keep UI consistent with existing Settings management surfaces.
- Create flow:
  - Accept one label name.
  - Trim, reject blank input, and surface duplicate/reuse behavior clearly.
  - Use the same backend validation as transaction inline creation.
- Rename flow:
  - Preserve label ID.
  - Update visible label chips across transaction list/detail/filter surfaces
    after provider refresh.
  - Reject blank and duplicate names with user-visible errors.
- Delete flow:
  - Show confirmation copy with attached transaction count.
  - Deleting a used label detaches it from all transactions.
  - Transactions remain intact and do not enter Review.
  - After success, refresh Settings label manager data and active transaction
    queries, especially if the deleted label was the active filter.
- Add regression coverage:
  - Settings create, rename, and delete with impact confirmation.
  - Used-label delete removes assignments but leaves fake transactions intact.
  - Active label filter handles deleted labels by clearing or emptying in a
    deliberate, tested way.
  - Narrow viewport layout does not overflow for long label names.
- Update durable docs:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/MILESTONES.md` if implementation changes the plan.
  - `docs/implementation-plan/SESSION_HANDOFF.md`
- Do not add label colors/icons, AI label suggestions, label reports, bulk
  labeling, or automatic workbook/Gmail labeling in this milestone.

Expected code shape:

- Reuse the repository and label editor primitives from M26-M27 where practical.
- Keep Settings label management focused on vocabulary and usage. It should not
  become a transaction bulk editor.
- Any final behavior change discovered during regression should be documented in
  `DATA_MODEL.md` and the M28 completion notes.

Acceptance criteria:

- Settings exposes a household label manager with create, rename, delete, and
  usage counts.
- Used-label deletion detaches that label from all transactions after
  confirmation and does not mutate transaction classification.
- Transaction label display, editing, and filtering still work after label
  rename/delete.
- Viewers and non-members cannot mutate labels.
- Final docs and handoff reflect implemented behavior and deferred label work.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Completed on 2026-06-12.
- Settings now exposes a Labels manager with usage counts, refresh, create,
  rename, and delete actions.
- Settings label create accepts one trimmed label name and uses the existing
  RLS-protected `labels` insert contract; duplicate/blank validation remains
  enforced by the repository/database path.
- Settings label rename preserves the label ID through `renameHouseholdLabel`
  and refreshes label lookup, label-manager, and transaction-query providers.
- Settings label delete shows attached transaction count before deletion,
  detaches that label from all transactions through `deleteHouseholdLabel`, and
  refreshes label lookup, label-manager, and transaction-query providers.
- Transactions clears an active label filter after label lookup refresh if the
  selected label no longer exists.
- Focused widget tests cover Settings create/rename/delete with impact
  confirmation, used-label detach while preserving transaction classification,
  active deleted-label filter clearing, and narrow-viewport long-label layout.
- Verification run:
  - `cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug --no-pub`
  - `git diff --check`
- Assumptions made:
  - M28 could use the existing authenticated `labels` insert RLS contract for
    Settings-created unattached labels instead of adding a new Supabase RPC.
  - Deleting the active label filter should clear the stale filter after label
    lookup refresh instead of leaving an empty/stale selected-label state.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, extended for Settings
    label create, rename, delete, detach, and active-filter regression coverage.
- Deferred by scope:
  - Label colors/icons, label reports, dashboard/trend label summaries, bulk
    labeling, AI label suggestions, automatic workbook/Gmail labels, Supabase
    schema/RPC changes, and M18-M21 push notifications.
