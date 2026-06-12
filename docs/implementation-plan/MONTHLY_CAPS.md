# Multi-Target Monthly Caps Plan

Last updated: 2026-06-12

This document is the implementation plan for named monthly caps that can target
one or more categories and one or more transaction labels. Each milestone below
is a standalone milestone intended to be executed in a separate Codex thread.
Stop after completing and documenting the current milestone; do not
automatically continue to the next milestone.

## Target Behavior

SpendLens users can create named monthly caps from the Dashboard. A cap has a
required name, a monthly amount, and at least one target. Targets can be
top-level categories, labels, or a mix of both.

A transaction contributes to a cap when:

- its `category_id` matches any category target on the cap, or
- it has any label that matches any label target on the cap.

If one transaction matches the same cap through both category and label, count
it once for that cap. Overlapping caps are allowed: the same transaction can
contribute to more than one cap when the user intentionally creates caps with
overlapping targets.

The first version supports:

- Migrating existing category caps into named monthly caps.
- Creating, editing, and deleting named monthly caps from Dashboard.
- Selecting multiple categories and multiple labels while creating or editing a
  cap.
- Showing progress, remaining amount, percent used, over-budget state, matched
  transaction count, and target chips for each cap.
- Preserving transaction classification and label assignment semantics. Cap
  edits do not recategorize transactions, assign labels, change merchant rules,
  or send transactions to Review.

## Existing Foundation

- Dashboard cap UI lives in
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`.
- Flutter finance data flows through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`.
- Dashboard tests live in `apps/mobile/test/finance_features_test.dart`.
- Current category-only caps use `public.category_caps`,
  `public.v_budget_progress`, `BudgetProgress`, and `saveCategoryCap`.
- Categories are household-scoped in `public.categories`; category management
  through M25 includes rename, delete, merge, usage preview, and category
  transaction drilldown.
- Labels are household-scoped in `public.labels` and attached through
  `public.transaction_labels`; label management through M28 includes
  transaction chips/editing/filtering and Settings label vocabulary management.
- Transactions store category classification on `public.transactions` and label
  assignments in `public.transaction_labels`.
- Financial summaries and caps use `net_expense`; card bill payments have
  `net_expense = 0`; refunds reduce spend through `refund_amount`.
- The repo standard for app-facing Supabase writes is authenticated,
  household-scoped, RLS-safe `security invoker` RPCs.
- The repo standard verification path is local Supabase reset/tests/lint,
  local advisors with `--fail-on none`, Flutter analyze, focused Flutter widget
  tests, full Flutter tests, and a debug Android build when UI behavior changes.

## Global Rules For M29-M31

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, or prepare later milestones unless the user
  explicitly asks to proceed.
- Preserve Android-first scope. Do not add iOS or web-specific cap work in this
  sequence.
- Use the user-facing term "Monthly caps" or "Caps". Avoid "budgets" for this
  feature unless referring to existing code identifiers that have not yet been
  renamed.
- Cap names are required. Do not add generated-only or optional names.
- Cap overlap is allowed. Do not block a category or label from being reused in
  another cap for the same month.
- Within one cap, count each matching transaction once even when the transaction
  matches multiple targets.
- Cap targets are top-level categories and labels only. Do not add subcategory,
  merchant, source-account, regex, amount-range, or AI-suggested cap targets in
  this sequence.
- Label assignment stays manual and row-specific. Cap creation must not assign
  labels to transactions.
- Cap mutations must be household-scoped and RLS-safe. Use authenticated
  app-facing `security invoker` RPCs for create/update/delete.
- Do not use service-role credentials, Edge Functions, or privileged Flutter
  client code for cap management.
- Create migrations with `supabase migration new <descriptive_name>` when
  implementation starts. Do not invent migration filenames.
- Before Supabase implementation, run `supabase --version`, discover relevant
  CLI help, and scan the Supabase changelog/docs for relevant breaking changes.
- Add focused pgTAP and Flutter tests in the same milestone as each behavior
  change.
- Milestones 18-21 remain deferred unless the user explicitly resumes push
  notification work.
- At completion, update `SESSION_HANDOFF.md` and include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M29 - Monthly Cap Data Model And Repository Foundation

Purpose: Replace the category-only cap contract with named monthly caps that
can target categories and labels before exposing the new Dashboard UX.

Instructions:

- Start by reading:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `docs/implementation-plan/TRANSACTION_LABELS.md`
  - `supabase/migrations/20260604203957_create_spendlens_foundation.sql`
  - `supabase/migrations/20260612130532_labels_foundation.sql`
  - category delete/merge migrations from M23-M24
  - `supabase/tests/summary_views.sql`
  - `supabase/tests/transaction_labels.sql`
  - `supabase/tests/category_taxonomy_delete.sql`
  - `supabase/tests/category_taxonomy_merge.sql`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Add a Supabase migration created by the CLI.
- Add `public.monthly_caps`:
  - `id uuid primary key default gen_random_uuid()`
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `name text not null`
  - `period_month date not null`
  - `cap_amount numeric(14,2) not null`
  - `created_by uuid references public.profiles(id) on delete set null`
  - `created_at timestamptz not null default now()`
  - `updated_at timestamptz not null default now()`
  - `unique (id, household_id)`
  - trimmed nonblank name check
  - first-day-of-month check
  - nonnegative cap amount check
  - case-insensitive unique index on `(household_id, period_month, lower(name))`
- Add `public.monthly_cap_categories`:
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `monthly_cap_id uuid not null`
  - `category_id uuid not null`
  - `created_at timestamptz not null default now()`
  - primary key `(monthly_cap_id, category_id)`
  - foreign key `(monthly_cap_id, household_id)` to `monthly_caps(id, household_id)` on delete cascade
  - foreign key `(category_id, household_id)` to `categories(id, household_id)` on delete cascade
- Add `public.monthly_cap_labels`:
  - `household_id uuid not null references public.households(id) on delete cascade`
  - `monthly_cap_id uuid not null`
  - `label_id uuid not null`
  - `created_at timestamptz not null default now()`
  - primary key `(monthly_cap_id, label_id)`
  - foreign key `(monthly_cap_id, household_id)` to `monthly_caps(id, household_id)` on delete cascade
  - foreign key `(label_id, household_id)` to `labels(id, household_id)` on delete cascade
- Add lookup indexes for:
  - monthly caps by `(household_id, period_month)`
  - category targets by `(household_id, category_id)`
  - label targets by `(household_id, label_id)`
- Enable RLS on all new tables.
- Add RLS policies:
  - household members can select caps and cap targets.
  - household writers can insert/update/delete caps and targets.
  - policies must include household ownership predicates, not only
    `TO authenticated`.
- Grant only the required table privileges to `authenticated`; do not grant
  access to `anon`.
- Backfill existing `public.category_caps` rows into `public.monthly_caps`:
  - use the category name as the required cap name.
  - preserve `household_id`, `period_month`, `cap_amount`, `created_by`,
    `created_at`, and `updated_at` where available.
  - create one category target per backfilled cap.
  - reject or explicitly resolve impossible duplicate names in the migration
    rather than silently coalescing caps.
- Add app-facing RPCs:
  - `public.upsert_monthly_cap(p_household_id uuid, p_monthly_cap_id uuid default null, p_name text, p_period_month date, p_cap_amount numeric, p_category_ids uuid[] default '{}', p_label_ids uuid[] default '{}')`
    - `security invoker` and empty `search_path`.
    - requires a signed-in profile and household write access.
    - trims and requires the cap name.
    - validates first-day period month and nonnegative cap amount.
    - requires at least one distinct category or label target.
    - validates every category and label ID belongs to the household.
    - inserts or updates one cap row and atomically replaces all category and
      label targets.
    - returns the cap row plus ordered target rows.
  - `public.delete_monthly_cap(p_household_id uuid, p_monthly_cap_id uuid)`
    - requires household write access.
    - deletes only the cap and its targets.
    - returns the deleted cap ID.
- Add `public.v_monthly_cap_progress` as a `security_invoker` view:
  - one row per monthly cap.
  - includes cap ID, name, household ID, period month, cap amount, spent amount,
    remaining amount, percent used, over-budget flag, matched transaction count,
    category target IDs/names, and label target IDs/names.
  - matches transactions from the same household and period month when category
    OR label target matches.
  - counts each transaction once per cap.
  - uses `net_expense`.
  - orders or aggregates target labels and categories deterministically.
- Update category and label dependency behavior:
  - Category deletion removes cap category targets and deletes any cap left with
    no category or label targets.
  - Category merge repoints category targets to the destination category and
    dedupes targets; do not sum independent named caps.
  - Label deletion removes cap label targets and deletes any cap left with no
    targets.
  - Label rename needs no cap-target mutation because cap targets use label IDs.
- Keep the legacy `category_caps` table only as temporary migrated history in
  M29. Stop app and view reads/writes from using it. Do not add new client
  writes to `category_caps`.
- Extend Dart repository contracts:
  - replace or deprecate `BudgetProgress` with `MonthlyCapProgress`.
  - add cap target models for category and label targets.
  - add `MonthlyCapUpsertRequest`, `MonthlyCapUpsertResult`, and
    `MonthlyCapDeleteRequest`.
  - replace `saveCategoryCap` with repository methods backed by the new RPCs.
  - update `DashboardSnapshot` to expose monthly cap progress and category/label
    option lists needed by M30.
  - update fake repository behavior for tests without exposing the new UI yet.

Expected code shape:

- Keep cap create/update transactional inside the upsert RPC. A failed
  validation must leave both cap rows and target rows unchanged.
- Keep progress computation in Postgres. Flutter should render progress, not
  recompute matching transactions.
- Keep cap matching independent from transaction filtering. Do not overload
  `TransactionQuery.categoryId` plus `labelId`, because that query currently
  behaves as an AND filter while cap matching is OR.

Acceptance criteria:

- Existing category-only caps are migrated into named monthly caps with one
  category target each.
- Household writers can create, update, and delete named monthly caps through
  RLS-safe RPCs.
- Cap progress includes category-only, label-only, and mixed target caps.
- One transaction matching multiple targets in the same cap is counted once.
- Overlapping caps can both include the same transaction.
- Viewer and non-member mutations are rejected.
- Flutter repository contracts can fetch monthly cap progress and mutate caps.

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

## M30 - Dashboard Multi-Target Cap UX

Purpose: Expose named category/label caps from the Dashboard while preserving
the existing dashboard summaries and transaction drilldowns.

Instructions:

- Start by reading M29 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Replace the category-chip-only cap creation affordance with a clear `Add cap`
  action in the Monthly caps section.
- Add or refactor a cap dialog/bottom sheet:
  - required name text field.
  - monthly amount field with INR prefix.
  - multi-select category chips.
  - multi-select label chips.
  - disabled Save until name is nonblank, amount is valid and nonnegative, and
    at least one category or label is selected.
  - inline validation errors for blank name, invalid amount, and no targets.
- Existing cap rows should show:
  - required cap name.
  - spent, cap amount, remaining/over amount, percent progress, and matched
    transaction count.
  - selected category and label chips.
  - edit icon action.
  - delete icon action.
- Editing a cap opens the same form with existing name, amount, categories, and
  labels selected.
- Deleting a cap asks for confirmation and deletes only the cap and cap targets.
  Do not delete transactions, categories, labels, review rows, merchant rules, or
  transaction label assignments.
- Refresh dashboard providers after cap create, edit, and delete.
- Keep top category and top merchant drilldowns unchanged.
- Do not add cap-row transaction drilldown in M30. A cap's target matching is OR
  across categories and labels, while the current Transactions screen supports
  separate category and label filters that combine as AND.
- Preserve narrow-viewport layout. Long cap names and long label names must wrap
  or truncate without overflowing.
- Add Flutter tests for:
  - creating a category-only named cap.
  - creating a label-only named cap.
  - creating a mixed category/label cap.
  - required-name validation.
  - no-target validation.
  - edit flow preserving and changing targets.
  - delete confirmation.
  - rendering progress and target chips.
  - existing top category and merchant drilldowns still working.

Expected code shape:

- Prefer local helper widgets inside the Dashboard feature unless the same cap
  target selector is reused elsewhere in the same milestone.
- Reuse existing `CategoryOption` and `LabelOption` model shapes where possible.
- Keep user-visible copy compact and task-focused; do not add instructional
  paragraphs inside the app.

Acceptance criteria:

- Users can create a required-name monthly cap from multiple categories,
  multiple labels, or both.
- Users can edit cap amount and target selections.
- Users can delete a cap without touching transactions or taxonomy/label rows.
- Cap rows communicate exactly what they cover and how much has been spent.
- Dashboard tests cover the new workflows and prior dashboard drilldowns.

Verification:

```bash
cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M31 - Monthly Caps Regression, Docs, And Cleanup

Purpose: Harden the full multi-target cap workflow, document final behavior, and
remove stale category-only cap references.

Instructions:

- Start by reading M29 and M30 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/MILESTONES.md`
  - `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`
  - `apps/mobile/lib/src/features/settings/settings_screen.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - relevant cap, category-delete, category-merge, and label-delete tests.
- Review remaining code and docs for category-only cap assumptions:
  - `category_caps`
  - `v_budget_progress`
  - `BudgetProgress`
  - `saveCategoryCap`
  - "uncapped categories"
  - "category cap" user-facing copy where it now means a multi-target cap.
- Remove or retire the legacy `category_caps` table only after confirming no
  app code, views, active RPCs, tests, or docs still depend on it. If dropped,
  do it in a Supabase CLI-created migration and update grants/RLS tests.
- Keep historical completion notes intact when they describe old milestone
  behavior; add current-state notes instead of rewriting history.
- Update durable docs:
  - `README.md` product summary and scope defaults.
  - `DATA_MODEL.md` cap model and summary view list.
  - `MILESTONES.md` status for completed M29-M31 work.
  - `SESSION_HANDOFF.md` current status, milestone status, verification run, and
    known gaps.
- Add or update tests for:
  - category deletion removing category cap targets and deleting targetless caps.
  - category merge repointing category cap targets without summing independent
    named caps.
  - label deletion removing label cap targets and deleting targetless caps.
  - dashboard progress after category/label rename.
  - dashboard progress after transaction label assignment changes.
  - no double-counting within mixed caps.
  - allowed overlap between separate caps.
- Run the full local verification path.
- Keep Milestones 18-21 deferred unless the user explicitly resumes them.

Expected code shape:

- Final docs should describe monthly caps as named category/label target groups,
  with old category-only storage treated as legacy implementation history.
- Do not add cap reports, cap notifications, cap drilldown, rollover budgets,
  shared templates, AI cap suggestions, or subcategory targets in M31.

Acceptance criteria:

- No active app code reads or writes category-only cap contracts.
- Multi-target monthly caps behave correctly after category delete, category
  merge, label delete, label rename, and transaction label assignment changes.
- Durable docs and handoff reflect final cap behavior and deferred work.
- Full local database, Flutter, and debug build verification passes or any
  blocker is documented with exact failing command and error.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## Deferred Scope

- Subcategory caps.
- Merchant, source-account, amount-range, pattern, or AI-suggested cap targets.
- Cap-row drilldown to Transactions.
- Cap notifications, alerts, or push delivery.
- Budget rollover, recurring templates, shared household templates, or annual
  budget planning.
- Label auto-assignment from cap creation.
