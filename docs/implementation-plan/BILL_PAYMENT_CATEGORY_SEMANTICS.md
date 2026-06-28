# Bill-Payment Category Semantics Plan

Last updated: 2026-06-28

This document is the implementation plan for treating the household category
named `Payments/Credits (not expense)` as bill-payment semantics. Each
milestone below is a standalone milestone intended to be executed in a separate
Codex thread. Stop after completing and documenting the current milestone; do
not automatically continue to the next milestone.

## Target Behavior

Transactions categorized under the exact household category name
`Payments/Credits (not expense)` are non-expense bill-payment rows, regardless
of subcategory.

- Any matching transaction is stored with
  `transaction_type = 'bill_payment_credit'`.
- The original `amount` remains the bill-cleared amount.
- `gross_spend = 0`, `refund_amount = 0`, and `net_expense = 0`.
- `v_monthly_spend.bill_payments` accounts for those rows through
  `abs(amount)`.
- Dashboard shows the selected month bills-paid amount as a third KPI in the
  existing Spending card row.
- If a transaction is moved out of `Payments/Credits (not expense)`, the system
  converts it to `debit_spend` by using `abs(amount)` for `gross_spend` and
  `net_expense`.
- Review confidence behavior remains separate. This sequence does not
  auto-resolve, suppress, or otherwise alter Review items.

## Existing Foundation

- The transaction enum already includes `bill_payment_credit` in
  `public.transaction_type`.
- `public.transactions` has money-shape constraints tying
  `bill_payment_credit` to zero gross/refund/net values.
- `public.v_monthly_spend` already exposes `bill_payments` as the sum of
  `abs(amount)` for `bill_payment_credit` transactions.
- Flutter already parses `MonthlySpend.billPayments` from
  `v_monthly_spend`, but Dashboard does not display it.
- Dashboard spending UI lives in
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`.
- The category rule is exact-name based by user decision. Do not add a new
  durable category flag in this sequence.
- Live linked-project inspection during planning found two current
  `Payments/Credits (not expense)` transactions that still use
  `debit_spend`, totaling `132790.49` to move from gross/net spend into
  bills paid.

## Global Rules For M82-M85

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Use the exact category name `Payments/Credits (not expense)` as the rule
  boundary. If that category is renamed away from the exact name, affected
  transactions should no longer receive bill-payment semantics.
- Keep Review confidence workflow separate from transaction type semantics.
  Do not auto-resolve Review rows merely because a transaction becomes
  `bill_payment_credit`.
- Keep household scoping explicit whenever looking up categories.
- Do not add a user-facing transaction-type editor in this sequence.
- Do not change merchant mapping confidence, category taxonomy management,
  monthly cap matching, Activity filters, or transaction deletion behavior
  except as required by corrected transaction money fields.
- Use the Supabase skill before schema work. Check relevant Supabase CLI help
  before migrations and create migrations with
  `supabase migration new <descriptive_name>`.
- Keep app-facing database work authenticated, household-scoped, RLS-safe, and
  free of service-role credentials in Flutter.
- Use DESIGN.md and existing shared primitives for visible Dashboard UI.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M82 - Bill-Payment Category Semantics Planning and Reference Readiness

Status: Completed on 2026-06-28.

Purpose: Create this companion plan and wire M83-M85 into durable planning
docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `INGESTION.md`,
  `MONTHLY_CAPS.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md` so a fresh
  session can start M83 from docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, web, or runtime implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `BILL_PAYMENT_CATEGORY_SEMANTICS.md` describes M82-M85 as serial standalone
  milestones.
- M83 became the next recommended non-deferred implementation milestone at M82
  closeout.
- Durable docs state that implementation remains planned only.

Verification:

```bash
rg -n "BILL_PAYMENT_CATEGORY_SEMANTICS|Milestone 8[2-5]|Payments/Credits|bill_payment_credit|Bills paid" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Bill-Payment Category Semantics companion plan and routed future
  implementation through M83-M85.
- Updated durable planning entrypoints and related spend/cap docs so the
  planned exact-category semantics are discoverable without reading this chat.
- Confirmed the rule is exact-name based on `Payments/Credits (not expense)`,
  regardless of subcategory.
- Confirmed the implementation should be a database invariant with historical
  backfill, not report-only derived behavior.
- Confirmed Dashboard should show bills paid as a third KPI in the existing
  Spending card row.
- Confirmed Review behavior remains separate and should not be auto-resolved or
  suppressed by this feature.
- Confirmed moving a transaction out of the category should convert it to
  `debit_spend`.
- M83 was not started.
- Assumptions made:
  - Exact category-name matching is acceptable even though a future category
    rename would intentionally stop this special handling.
  - Existing `v_monthly_spend.bill_payments` is the correct backend source for
    the Dashboard KPI once transaction rows are correctly typed.
  - A zero-amount transaction moved out of the category should fail clearly
    rather than create an invalid `debit_spend` row.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M83 - Payments/Credits Database Classification Contract

Status: Completed on 2026-06-28.

Purpose: Enforce bill-payment transaction shape for the exact
`Payments/Credits (not expense)` category and backfill existing rows.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `INGESTION.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`,
  `supabase/migrations/20260604203957_create_spendlens_foundation.sql`,
  `supabase/migrations/20260607131628_gmail_connector_ingestion.sql`,
  `supabase/migrations/20260608195329_transaction_metadata_editing.sql`,
  `supabase/migrations/20260614122706_import_resurrection_guard.sql`, and the
  transaction-related SQL tests.
- Use the Supabase skill. Check `supabase --version`,
  `supabase migration --help`, `supabase db --help`, and relevant Supabase
  changelog/docs before schema work.
- Create the migration with
  `supabase migration new bill_payment_category_semantics`.
- Add a private normalization helper and transaction trigger for
  `public.transactions` that:
  - Looks up `NEW.category_id` within `NEW.household_id`.
  - Treats only exact category name `Payments/Credits (not expense)` as the
    special bill-payment category.
  - On insert or update into that category, sets
    `transaction_type = 'bill_payment_credit'`, `gross_spend = 0`,
    `refund_amount = 0`, and `net_expense = 0`, preserving `amount`.
  - On update away from that category, sets `transaction_type = 'debit_spend'`,
    `gross_spend = abs(NEW.amount)`, `refund_amount = 0`, and
    `net_expense = abs(NEW.amount)`.
  - Raises a clear exception if an update away would create a debit spend with
    zero amount.
- Attach the trigger as `before insert or update` on `public.transactions`.
  It must run before constraints validate the row.
- Inspect category taxonomy update paths, especially
  `update_household_category_taxonomy(...)`. Because the rule is exact-name
  based, category renames to or from `Payments/Credits (not expense)` must also
  reshape affected transactions. Prefer a database-owned category-name update
  trigger or helper so a rename away converts affected rows to `debit_spend`
  shape, and a rename to the exact name converts affected rows to
  `bill_payment_credit` shape.
- Backfill existing transactions whose category name is exactly
  `Payments/Credits (not expense)` so they become `bill_payment_credit` with
  zero gross/refund/net values.
- Do not alter `amount`, `source_fingerprint`, transaction date/time, merchant,
  labels, Review rows, Gmail diagnostics, deletion tombstones, or category
  taxonomy.
- Do not change `v_monthly_spend` unless tests prove its existing
  `bill_payments` calculation is insufficient.
- Add focused pgTAP coverage, preferably in a new
  `supabase/tests/bill_payment_category_semantics.sql` file, proving:
  - Backfilled category rows are `bill_payment_credit`.
  - Insert/update into the category forces bill-payment shape.
  - Moving away converts to `debit_spend`.
  - Category renames to or from `Payments/Credits (not expense)` reshape
    affected transactions consistently with the exact-name rule.
  - `v_monthly_spend` moves those amounts out of gross/net and into
    `bill_payments`.
  - Existing open Review rows remain open.

Expected code shape:

- One migration containing the trigger helper, trigger, comments, and backfill.
- One focused database test file, or a focused addition to the closest existing
  SQL test if that better matches local test organization.
- No Flutter UI changes in this milestone.

Acceptance criteria:

- Any transaction categorized as `Payments/Credits (not expense)` is stored as
  `bill_payment_credit` with zero gross/refund/net values.
- Existing linked-project shape represented by two CRED rows totaling
  `132790.49` would move from spend into bills paid after backfill.
- Moving a row out of the category converts it to valid `debit_spend` shape.
- Renaming a category to or from the exact category name reshapes affected
  transactions consistently with the rule.
- Review queue state is unchanged by the backfill.
- Current monthly spend and monthly cap calculations now exclude these rows
  through existing `net_expense` semantics.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/bill_payment_category_semantics.sql
supabase test db --local supabase/tests/summary_views.sql
supabase test db --local supabase/tests/monthly_caps.sql
supabase db lint --local --schema app_private,public --fail-on error
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added `app_private.is_bill_payment_category(...)` plus a
  `public.transactions` before-trigger that forces insert/update rows in the
  exact `Payments/Credits (not expense)` category to
  `bill_payment_credit` shape while preserving `amount`.
- Added a `public.categories` rename trigger so category renames to or from the
  exact name reshape existing transactions consistently with the name-based
  rule.
- Backfilled existing exact-category transactions to zero gross/refund/net
  `bill_payment_credit` rows.
- Added focused pgTAP coverage for insert/update normalization, moves away,
  zero-amount move-away rejection, category renames to/from the exact name,
  monthly spend, monthly cap progress, and Review independence.
- No Flutter UI, importer, Edge Function, hosted rollout, iOS, web, push
  notification, or Dashboard KPI work was started.
- Verification run:
  - `supabase db reset --local` was attempted with the local stack stopped,
    then with reduced local stacks, but the CLI repeatedly hung while loading
    Docker registry credentials after local schema initialization. As
    compensating compile evidence, all `supabase/migrations/*.sql` files were
    applied in order through `docker exec -i supabase_db_SpendLens psql
    -v ON_ERROR_STOP=1 -U postgres -d postgres`.
  - `supabase test db --local supabase/tests/bill_payment_category_semantics.sql`
    passed.
  - `supabase test db --local supabase/tests/summary_views.sql` passed.
  - `supabase test db --local supabase/tests/monthly_caps.sql` passed when run
    serially; an initial parallel run contended while enabling pgTAP.
  - `supabase db lint --local --schema app_private,public --fail-on error`
    passed.
  - `git diff --check` passed.
- Assumptions made:
  - Direct moves out of the exact bill-payment category should preserve
    `amount` and use `abs(amount)` for debit gross/net values.
  - Existing `bill_payment_credit` rows outside the exact category should not
    be rewritten merely because unrelated fields are edited; M83 only owns the
    exact-name category invariant and moves/renames across that boundary.
  - The local `supabase db reset --local` registry-credential hang is an
    environment/CLI issue, not an M83 migration failure, because the full
    migration stack applied cleanly through the same local Postgres container.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M84 - Dashboard Bills Paid KPI

Status: Completed on 2026-06-28.

Purpose: Surface the existing monthly bills-paid total on Dashboard after the
backend semantics make it reliable.

Instructions:

- Before editing, inspect this plan, `DESIGN.md`, `README.md`,
  `MILESTONES.md`, `SESSION_HANDOFF.md`,
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`,
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`, and
  `apps/mobile/test/finance_features_test.dart`.
- Reuse `DashboardSnapshot.monthlySpend.billPayments`; do not add a new
  repository query if the existing `v_monthly_spend` read already provides the
  value.
- Add a third KPI in Dashboard's existing Spending section:
  - label `Bills paid`
  - amount `formatMoney(snapshot.monthlySpend.billPayments)`
  - concise supporting copy such as `Card payments cleared`
- On tablet/desktop widths, show monthly net, month change, and bills paid in
  the same first Spending card row.
- On narrow widths, stack the three cards with stable spacing and no overflow.
- Use existing Dashboard card patterns, `AppContentCard`, `LargeAmountText`,
  icons, and theme tokens.
- Keep Review, Monthly caps, top categories, top merchants, Activity filters,
  cap drilldown, and transaction detail behavior unchanged.
- Do not add a bill-payment drilldown in this milestone.

Expected code shape:

- A small Dashboard UI addition, likely a new local `_BillsPaidCard` beside
  `_NetSpendCard` and `_MonthChangeCard`.
- Existing fake repository/dashboard fixture data extended only as needed for
  widget coverage.

Acceptance criteria:

- Dashboard shows the selected month's bills-paid amount.
- The amount comes from `MonthlySpend.billPayments`.
- Layout remains readable at 390px and desktop widths.
- Existing Dashboard actions and drilldowns still work.

Verification:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "Dashboard|Bills paid"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added a third Dashboard Spending KPI card labeled `Bills paid`, sourced from
  the existing `DashboardSnapshot.monthlySpend.billPayments` value and rendered
  with the existing Dashboard card, amount-text, icon, and theme-token
  patterns.
- Preserved the existing `v_monthly_spend`/`MonthlySpend` repository read path;
  no new backend query, schema, importer, Edge Function, hosted rollout,
  Activity filter, cap drilldown, transaction detail, Review, iOS, web, or push
  notification work was started.
- Added focused widget coverage proving the KPI displays `MonthlySpend`
  bill-payment data at 390px mobile and desktop widths without Flutter
  exceptions.
- Verification run:
  - `cd apps/mobile && flutter analyze` passed.
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name
    "Dashboard|Bills paid"` passed.
  - `git diff --check` passed.
- Assumptions made:
  - The existing Dashboard fake snapshot value `billPayments: 12000` is the
    correct fixture for M84 widget coverage because the repository contract
    already parses `v_monthly_spend.bill_payments`.
  - `Card payments cleared` is acceptable concise supporting copy for the new
    KPI.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake finance repository/widget-test data from
    `apps/mobile/test/finance_features_test.dart`.

## M85 - Bill-Payment Semantics Regression, Docs, and Cleanup

Status: Planned.

Purpose: Verify the complete category-driven bill-payment workflow and fold
final behavior into durable docs.

Instructions:

- Before editing, inspect this plan, `README.md`, `ARCHITECTURE.md`,
  `DATA_MODEL.md`, `INGESTION.md`, `MONTHLY_CAPS.md`, `MILESTONES.md`,
  `SESSION_HANDOFF.md`, the M83/M84 implementation diffs,
  `supabase/tests`, and `apps/mobile/test/finance_features_test.dart`.
- Run the focused local regression path for transaction money shape,
  summary views, monthly caps, workbook importer validation, Gmail ingestion
  transaction upserts, transaction metadata corrections, Dashboard rendering,
  and Review preservation.
- Update durable docs with final behavior:
  - `README.md`
  - `DATA_MODEL.md`
  - `INGESTION.md`
  - `MONTHLY_CAPS.md`
  - `MILESTONES.md`
  - `SESSION_HANDOFF.md`
  - this plan
- Mark this plan completed-only after M85 completes.
- Confirm hosted Supabase migration push and app release work remain separate
  explicit rollout operations unless the user asks for them.
- Do not start push notifications, iOS, web, Activity export, bill-payment
  drilldown, transaction-type editor, category flag migration, or unrelated
  cleanup.

Expected code shape:

- Regression fixes and durable docs only.
- Do not broaden the exact-name rule or add new UI beyond the M84 KPI.

Acceptance criteria:

- Focused Supabase, importer, and Flutter verification passes locally or
  documents an environment limitation with compensating evidence.
- Existing and future `Payments/Credits (not expense)` transactions no longer
  inflate gross spend, net expense, or monthly caps.
- Dashboard bills-paid KPI reflects corrected `bill_payment_credit` rows.
- Review queue behavior remains independent from bill-payment typing.
- `BILL_PAYMENT_CATEGORY_SEMANTICS.md` is marked completed-only.
- No unrelated deferred work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/bill_payment_category_semantics.sql
supabase test db --local supabase/tests/summary_views.sql
supabase test db --local supabase/tests/monthly_caps.sql
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase db lint --local --schema app_private,public --fail-on error
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
