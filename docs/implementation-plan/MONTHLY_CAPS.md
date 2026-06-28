# Monthly Caps Plan

Last updated: 2026-06-13

This document is the implementation plan for named monthly caps, including the
completed multi-target category/label work, recurring cap foundation, and
backend carry-forward semantics. Each milestone below is a standalone milestone
intended to be executed in a separate Codex thread. Stop after completing and
documenting the current milestone; do not automatically continue to the next
milestone.

For the planned post-M35 Dashboard cap transaction drilldown, see
[Monthly Cap Drilldown](MONTHLY_CAP_DRILLDOWN.md). That follow-up is tracked as
Milestones 78-81 and must not be implemented by routing cap taps to Activity
filters.

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

The completed M29-M35 implementation supports:

- Migrating existing category caps into named monthly caps.
- Creating, editing, and stopping named recurring monthly caps from Dashboard.
- Selecting multiple categories and multiple labels while creating or editing a
  cap.
- Showing progress, remaining amount, percent used, over-budget state, matched
  transaction count, and target chips for each cap.
- Preserving transaction classification and label assignment semantics. Cap
  edits do not recategorize transactions, assign labels, change merchant rules,
  or send transactions to Review.
- Keeping stable recurring cap series identity with month-effective versions,
  so edits and deletes apply from the selected month forward while prior months
  remain readable.
- Returning cap progress for exact months even when a recurring cap has no
  matching transactions in that month.
- Calculating positive and negative carry-forward in Postgres from the previous
  active month's effective cap minus spend, including chained, disabled, edited,
  refund, and bill-payment cases.
- Toggling carry-forward from the Dashboard cap form and showing base, carried,
  effective available, spent, remaining/over, percent, matched count, and target
  values in cap rows.

Each recurring cap can optionally carry forward the previous month's remaining
amount into the next month:

- If the base cap is INR 10,000 and the prior month spent INR 8,000, the next
  month carries `+INR 2,000` and has an effective cap of INR 12,000.
- If the base cap is INR 10,000 and the prior month spent INR 12,000, the next
  month carries `-INR 2,000` and has an effective cap of INR 8,000.
- Carry-forward can chain month to month while the same cap series remains
  active and carry-forward is enabled.

## Existing Foundation

- Dashboard cap UI lives in
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`.
- Flutter finance data flows through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`.
- Dashboard tests live in `apps/mobile/test/finance_features_test.dart`.
- Completed M29-M33 cap plumbing uses `public.monthly_cap_series`,
  `public.monthly_cap_versions`, `public.monthly_cap_version_categories`,
  `public.monthly_cap_version_labels`, `public.upsert_monthly_cap`,
  `public.delete_monthly_cap`, `public.get_monthly_cap_progress`,
  `public.get_available_reporting_months`, `MonthlyCapProgress`,
  `MonthlyCapUpsertRequest`, and `MonthlyCapDeleteRequest`.
- `public.monthly_caps`, `public.monthly_cap_categories`,
  `public.monthly_cap_labels`, and `public.v_monthly_cap_progress` remain as
  compatibility tables/views for migrated history, older SQL coverage, and
  lifecycle bridging.
- Legacy category-only caps use `public.category_caps` and
  `public.v_budget_progress` for backfill and compatibility history only.
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

## Global Rules For M32-M35

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, prepare, or jump ahead to any later
  milestone unless the user explicitly asks to proceed.
- Preserve Android-first scope. Do not add iOS, web, or hosted rollout work in
  this sequence.
- Every user-created monthly cap is recurring after M32. Do not keep creating
  isolated one-month cap definitions for new Dashboard cap creation.
- Recurring cap identity must be stored explicitly. Do not infer recurrence by
  matching cap names, target sets, or amounts.
- Cap edits and deletes apply from the selected month forward. Prior months
  remain historical unless the user explicitly requests a future all-history
  edit mode in a separate milestone.
- Carry-forward is optional per recurring cap and defaults off.
- Carry-forward values can be positive or negative and must be derived from
  prior-month progress in Postgres, not manually entered by the user.
- Cap progress continues to use `net_expense`. Refunds reduce spend through
  existing transaction semantics, and card bill payments remain zero net
  expense.
- Cap matching remains OR across selected categories and labels, with
  one-count-per-cap transaction semantics and allowed overlap across separate
  caps.
- Cap targets remain top-level categories and transaction labels only. Do not
  add subcategory, merchant, source-account, regex, amount-range, annual, shared
  template, or AI-suggested targets in this sequence.
- Keep cap progress computation in Supabase. Flutter should render returned
  base cap, carry-forward, effective cap, spent, and remaining values.
- New app-facing Supabase tables, views, and RPCs must be RLS-safe, household
  scoped, and reachable only through authenticated client privileges. Use
  `security_invoker` views and functions where appropriate; never use
  service-role credentials from Flutter.
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

## M32 - Recurring Cap Series Foundation

Completed on 2026-06-13.

Purpose: Introduce stable recurring cap identity and current/future cap
versioning before adding carry-forward calculations or Dashboard copy.

Instructions:

- Start by reading M29-M31 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/MILESTONES.md`
  - `supabase/migrations/20260612174258_monthly_cap_data_model_repository_foundation.sql`
  - relevant category delete, category merge, label delete, and label rename
    migrations/tests
  - `supabase/tests/monthly_caps.sql`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Add a Supabase migration created by the CLI.
- Add a recurring cap series table that stores stable identity:
  - household ownership.
  - created profile/timestamps.
  - active lifecycle state sufficient to stop a cap from a selected month
    forward without deleting history.
- Add versioned recurring cap detail rows effective from a first-of-month date:
  - required name.
  - base monthly amount.
  - carry-forward flag, default `false`.
  - created profile/timestamps.
  - uniqueness that prevents two versions for the same cap series and effective
    month.
- Add versioned category and label target tables tied to the cap version, not
  only the cap series, so historical months preserve the targets active then.
- Backfill existing `monthly_caps` rows into recurring cap series and first
  versions:
  - one series per existing named cap row.
  - `period_month` becomes the first version's effective month.
  - `cap_amount`, name, created profile, timestamps, category targets, and label
    targets are preserved.
  - carry-forward defaults to disabled.
  - keep existing monthly cap rows usable until their replacement read path is
    fully wired in this milestone.
- Replace active app-facing cap mutation behavior with current/future
  recurrence semantics:
  - `upsert_monthly_cap` creates a series when no cap ID is provided.
  - editing an existing cap writes a new version effective from the selected
    month and leaves older months unchanged.
  - `delete_monthly_cap` stops the series from the selected month forward and
    leaves prior progress visible.
  - RPCs validate signed-in profile, household writer access, first-of-month
    dates, nonnegative amount, nonblank trimmed name, and at least one category
    or label target.
- Add an app read path that can return active cap progress for a requested
  month even when no transaction exists in that month, preferably an RPC such as
  `get_monthly_cap_progress(p_household_id, p_period_month)`.
- Update repository models and requests to carry stable cap series ID, active
  version ID, base amount, carry-forward flag, and selected targets while
  preserving existing Dashboard behavior when carry-forward is off.
- Update `fetchAvailableMonths`/Dashboard month selection so months with active
  recurring caps can be selected even before transactions exist.
- Keep user-visible Dashboard copy functionally unchanged in M32 except for any
  unavoidable current/future edit/delete wording. Do not add carry-forward
  display copy until M34.
- Preserve category/label lifecycle behavior for versioned targets:
  - category delete removes affected future/current category targets and removes
    future/current versions left with no targets.
  - category merge repoints and dedupes current/future target rows.
  - label delete removes affected current/future label targets and removes
    future/current versions left with no targets.
  - label/category rename requires no target mutation.

Expected code shape:

- Prefer a versioned recurring-cap schema over name/target inference. The series
  ID is the durable identity; version rows are the month-effective configuration.
- Keep the Dashboard data model close to the current `MonthlyCapProgress` shape
  so M33-M34 can add carry-forward fields without a second UI rewrite.
- Keep old compatibility views/tables only where required for migration history
  or legacy docs/tests; do not add new Flutter reads from `category_caps`.

Acceptance criteria:

- Existing M29-M31 cap data migrates into recurring series without losing target
  information.
- Creating a cap from Dashboard creates a recurring cap series.
- Editing from a selected month changes that month and future months only.
- Deleting from a selected month hides that month and future months only.
- Prior months remain readable after edit/delete.
- Recurring cap months can appear in the Dashboard month selector without
  requiring transactions for those months.
- Existing category/label OR matching, no double-counting, overlap, RLS, and
  lifecycle cleanup behavior still passes with carry-forward disabled.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/monthly_caps.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added `monthly_cap_series`, `monthly_cap_versions`, versioned category/label
  target tables, RLS policies, explicit authenticated grants, and a backfill
  from existing M29-M31 monthly caps.
- Replaced active cap mutation semantics so creates make a stable recurring
  series, edits write a selected-month version, and deletes stop the series from
  the selected month forward while preserving prior progress.
- Added `get_monthly_cap_progress` for exact-month cap progress and
  `get_available_reporting_months` so recurring cap months can appear before
  transactions exist.
- Updated Flutter repository models and Dashboard delete wording while keeping
  carry-forward display copy deferred.
- Added pgTAP coverage for selected-month edit/delete behavior, zero-transaction
  recurring progress, cap-driven available months, and versioned target cleanup
  after category delete, category merge, and label delete.

## M33 - Carry-Forward Progress Semantics

Completed on 2026-06-13.

Purpose: Add positive and negative carry-forward calculations to recurring cap
progress while keeping the Dashboard presentation mostly unchanged.

Instructions:

- Start by reading M32 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - M32 recurring cap migration and tests
  - `supabase/tests/monthly_caps.sql`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Extend the cap progress read path with carry-forward fields:
  - `base_cap_amount`
  - `carry_forward_enabled`
  - `carry_forward_amount`
  - `effective_cap_amount`
  - existing `spent_amount`
  - `remaining_amount`
  - `percent_used`
  - `is_over_budget`
- Keep `cap_amount` in app-facing responses as a backwards-compatible alias for
  base monthly cap amount unless this milestone updates every app caller in the
  same change.
- Calculate carry-forward in Postgres over the recurring cap series:
  - first active month carry-forward is `0`.
  - if carry-forward is disabled for the active version, carry-forward is `0`.
  - if the previous active month for the same series has carry-forward disabled,
    the next month starts from `0`.
  - otherwise carry-forward equals previous month's effective cap minus previous
    month's spend, allowing positive or negative values.
  - effective cap equals base cap plus carry-forward.
  - remaining equals effective cap minus current-month spend.
  - over-budget state is based on negative remaining, including cases where
    negative carry-forward exhausts the month before current spend.
- Support chained carry-forward month by month. Do not skip across inactive or
  deleted future months.
- Preserve current matching semantics:
  - use `net_expense`.
  - match selected category OR selected label.
  - count one transaction once per cap.
  - allow overlapping separate caps.
- Update Dart model parsing and fake repository behavior for all new fields.
- Keep Dashboard row rendering mostly unchanged in this milestone if needed, but
  ensure tests can assert the values returned by repository/model code.

Expected code shape:

- Keep the carry-forward calculation in SQL/RPC/view code so every client sees
  the same effective cap.
- Prefer deterministic month-series logic over storing mutable derived carry
  values. Derived values should update when prior-month transactions, labels, or
  refunds change.
- Use numeric precision consistent with existing cap/spend fields.

Acceptance criteria:

- A positive prior-month remainder increases the next month's effective cap.
- A negative prior-month remainder reduces the next month's effective cap.
- Carry-forward chains across multiple active months.
- Disabling carry-forward stops the chain from that month.
- Edits to amount or targets from a selected month affect carry-forward only
  from that month onward.
- Refunds and bill payments follow existing `net_expense` semantics.
- Flutter models expose carry-forward and effective-cap values for M34.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/monthly_caps.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added the Supabase CLI-created migration
  `20260613131821_carry_forward_progress_semantics.sql`.
- Replaced the zeroed carry-forward projection in
  `public.get_monthly_cap_progress` and `public.v_monthly_cap_progress` with
  recursive, month-by-month recurring cap calculations.
- Kept `cap_amount` as the backwards-compatible base monthly amount while
  returning derived `carry_forward_amount`, `effective_cap_amount`,
  `remaining_amount`, `percent_used`, and `is_over_budget`.
- Preserved category OR label matching, one-count-per-cap semantics,
  overlapping caps, `net_expense` spend semantics, and security-invoker
  database access.
- Added pgTAP coverage for positive carry-forward, negative carry-forward,
  chained months, disabled carry-forward resets, selected-month amount/target
  edits, refunds, and bill payments.
- Added a focused Flutter model parsing regression for carry-forward fields.

## M34 - Dashboard Carry-Forward UX

Purpose: Expose the carry-forward option and effective cap explanation in the
Dashboard cap form and progress rows.

Instructions:

- Start by reading M32-M33 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Add a `Carry forward remainder` toggle to the cap create/edit sheet:
  - default off for newly created caps.
  - initialized from the selected cap's active version when editing.
  - saved through the updated `MonthlyCapUpsertRequest`.
- Keep the form compact and task-focused. Do not add long instructional
  paragraphs in the app UI.
- Update save/delete copy for recurring semantics:
  - editing saves changes from the selected month forward.
  - deleting stops the cap from the selected month forward.
  - confirmations must not imply transactions, categories, labels, merchant
    rules, or review rows are deleted.
- Update cap progress rows to render carry-forward state:
  - always show the base monthly cap.
  - when carry-forward is nonzero, show `Carried +INR ...` or
    `Carried -INR ...`.
  - show `Available INR ...` using `effective_cap_amount`.
  - keep spent, left/over, percent, matched count, and target chips.
  - if effective cap is already zero or negative because of carry-forward, show
    the over-budget/error state before current-month spend.
- Ensure long cap names, target chips, and carry-forward copy wrap on narrow
  Android viewports without overflow.
- Refresh Dashboard providers after create, edit, and delete as today.
- Do not add cap-row drilldown, cap reports, push notifications, or AI
  suggestions in M34.

Expected code shape:

- Keep helper widgets local to Dashboard unless an existing shared widget is
  already the natural fit.
- Continue to use repository-returned values for progress. Flutter should not
  recompute carry-forward.
- Use existing INR formatting helpers for positive and negative carry-forward
  values.

Acceptance criteria:

- Users can enable or disable carry-forward while creating a cap.
- Users can edit carry-forward behavior from the selected month forward.
- Positive carry-forward displays as extra available cap.
- Negative carry-forward displays as already-exhausted cap space.
- Over-budget states use effective cap, not the base cap alone.
- Dashboard month selection exposes future active recurring cap months even
  before transactions exist.
- Existing add/edit/delete target workflows and top category/merchant
  drilldowns still work.

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

Completion notes:

- Added Dashboard create/edit support for `Carry forward remainder`, defaulting
  off for new caps and initializing from the active cap version while editing.
- Saved carry-forward changes through the existing monthly cap upsert request;
  no new migration or RPC was needed because M32-M33 already exposed the
  repository contract.
- Updated selected-month-forward edit and stop/delete copy so users see that
  earlier months stay readable and finance/taxonomy/review data is unchanged.
- Updated cap progress rows to show base cap, positive or negative carried
  amount, effective available cap, spent, left/over, percent, matched count,
  and target chips using repository-returned values.
- Added focused widget coverage for create/edit carry-forward toggles, stop
  confirmation copy, positive and negative carry-forward rows on a narrow
  viewport, future active cap-month selection without transactions, and
  preserved add/edit/delete/drilldown workflows.

## M35 - Recurring Caps Regression, Docs, And Cleanup

Purpose: Harden recurring cap and carry-forward behavior, then fold final
behavior into durable docs and handoff.

Instructions:

- Start by reading M32-M34 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`, plus:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/MILESTONES.md`
  - `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - all monthly-cap, category lifecycle, and label lifecycle tests.
- Run regression for:
  - recurring cap creation across empty/future months.
  - current/future edit preserving historical months.
  - current/future delete preserving historical months.
  - positive carry-forward.
  - negative carry-forward.
  - chained carry-forward.
  - disabled carry-forward.
  - category delete and merge with versioned targets.
  - label delete, rename, and transaction label assignment with versioned
    targets.
  - no double-counting within a mixed cap.
  - allowed overlap between separate caps.
  - viewer and non-member RLS behavior.
- Review remaining code and docs for stale one-month-only cap assumptions:
  - cap rows as isolated monthly records.
  - delete copy that implies full historical deletion.
  - edit copy that implies all-history changes.
  - progress copy that compares only spent against base cap.
  - `v_monthly_cap_progress` callers that cannot include recurring months
    without transactions.
- Update durable docs:
  - `README.md` product summary and scope defaults.
  - `DATA_MODEL.md` recurring cap model and progress calculation.
  - `MILESTONES.md` status for completed M32-M35 work.
  - `SESSION_HANDOFF.md` current status, milestone status, verification run, and
    known gaps.
- Keep historical completion notes intact when they describe old milestone
  behavior; add current-state notes instead of rewriting history.
- Keep Milestones 18-21 deferred unless the user explicitly resumes them.

Expected code shape:

- Final docs should describe monthly caps as recurring named category/label
  target groups with optional carry-forward and current/future versioning.
- Keep compatibility notes clear if old `monthly_caps` or
  `v_monthly_cap_progress` names remain as views over recurring structures.
- Do not add cap reports, cap notifications, cap drilldown, shared templates,
  AI cap suggestions, subcategory targets, or hosted rollout in M35.

Acceptance criteria:

- Recurring cap and carry-forward behavior is covered by database and Flutter
  regression tests.
- No active Dashboard copy assumes caps are one-month-only records.
- Durable docs and handoff reflect final recurring/carry-forward behavior and
  deferred work.
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

Completion notes:

- Completed on 2026-06-13.
- Added final pgTAP coverage for selected stop-month returns, future-month
  hiding after a stopped recurring cap, exact-month transaction label progress,
  and exact-month RPC viewer/non-member behavior.
- Updated Dashboard copy so empty and create states describe recurring caps
  starting in the selected month instead of isolated one-month cap records.
- Renamed the Dashboard cap section helper away from the old budget wording.
- Folded final recurring/carry-forward behavior into `README.md`,
  `DATA_MODEL.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md`.
- Verification passed:
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
  - No migration was added because M35 tightened regression/docs/active copy
    only.
- Assumptions made:
  - Existing M32-M33 RPC/view behavior remains the final backend contract for
    recurrence and carry-forward.
  - The non-member exact-month progress RPC should reject with the existing
    permission error rather than silently returning an empty list.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data, with an empty cap list
    state for the new recurring-copy assertion.

## Deferred Scope

- Subcategory caps.
- Merchant, source-account, amount-range, pattern, or AI-suggested cap targets.
- Cap-row drilldown to Transactions.
- Cap notifications, alerts, or push delivery.
- Shared household templates or annual budget planning.
- Label auto-assignment from cap creation.
