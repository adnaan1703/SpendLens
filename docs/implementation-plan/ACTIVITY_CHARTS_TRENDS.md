# Activity Charts Trends Plan

Last updated: 2026-06-28

This document is the implementation plan for repairing Activity Charts category
trend visibility and adding a top-category month-by-month comparison chart.
Each milestone below is a standalone milestone intended to be executed in a
separate Codex thread. Stop after completing and documenting the current
milestone; do not automatically continue to the next milestone.

## Target Behavior

Activity Charts should make category spend trends readable month by month.

- `Category Trend` shows non-cumulative monthly net expense for each category.
- `Category Trend` remains horizontally scrollable on compact widths instead of
  collapsing to total-only category rows.
- A new `Top 10 Categories by Month` chart shows up to 10 category series in a
  single month-by-month chart.
- The top-10 chart obeys all current Activity Charts filters: category, source
  type, source account, and period. If a category filter is selected, the chart
  intentionally collapses to that selected category.
- Top categories are ranked by total net expense inside the current filtered
  report range, then plotted month by month.
- The chart uses monthly bucket values only. It must not show accumulated or
  running totals.
- Refunds reduce expense through existing `netExpense` / `netSpend` semantics,
  and bill-payment credits stay excluded from category trend totals.

## Existing Foundation

- Activity owns List and Charts modes through
  `apps/mobile/lib/src/features/activity/activity_screen.dart`.
- Activity Charts is implemented by `ActivityChartsPane` in
  `apps/mobile/lib/src/features/trends/trends_screen.dart`.
- Trend data is fetched through `trendReportProvider(TrendQuery)` and
  `FinanceRepository.fetchTrendReport(...)`.
- `TrendReport.fromTransactions(...)` already builds sorted monthly totals,
  category totals, and zero-filled `CategoryTrend.months` rows from filtered
  transaction data.
- `_CategoryTrendAccumulator.add(...)` stores each category/month bucket
  independently; the model is already non-cumulative.
- The current compact `Category Trend` UI drops to `_CompactCategoryTrendRow`,
  which hides the month-by-month values on narrow widths.
- The app already depends on `fl_chart`; `_MonthlyNetChart` is the existing
  horizontal-scroll chart pattern to reuse.
- Focused Activity Charts widget and model tests live in
  `apps/mobile/test/finance_features_test.dart`.
- Prior UI redesign guidance requires responsive verification at 390px, 768px,
  and 1024px widths for chart-heavy surfaces.

## Global Rules For M86-M88

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Keep this sequence Flutter-only unless a later approved milestone explicitly
  changes the data contract.
- Do not add Supabase migrations, RPCs, Edge Functions, importer changes,
  hosted rollout, iOS, web, push notifications, transaction export changes, or
  transaction editing behavior in this sequence.
- Preserve existing Activity Charts filters, CSV copy, metric cards, monthly net
  chart, and gross/refunds/net table unless a milestone explicitly names a
  visible change.
- Use `netExpense` / `netSpend` for category trend values. Do not use gross
  spend unless a future approved milestone changes the chart basis.
- Preserve bill-payment semantics: `bill_payment_credit` rows are excluded from
  category trend totals by the existing `TrendReport.fromTransactions(...)`
  path.
- Use existing app design primitives and `fl_chart`; do not introduce another
  charting dependency.
- Treat 390px overflow, clipped labels, unreadable legends, unbounded chart
  width/height, or hidden month values as blockers.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M86 - Activity Charts Trend Planning and Reference Readiness

Status: Completed on 2026-06-28.

Purpose: Create this companion plan and wire M87-M88 into durable planning docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md` so a fresh
  session can start M87 from docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, web, or runtime implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `ACTIVITY_CHARTS_TRENDS.md` describes M86-M88 as serial standalone
  milestones.
- M87 is the next recommended non-deferred implementation milestone.
- Durable docs state that implementation remains planned only.

Verification:

```bash
rg -n "ACTIVITY_CHARTS_TRENDS|Milestone 8[6-8]|Top 10 Categories|Category Trend" docs/implementation-plan
rg -n "^(<<<<<<<|=======|>>>>>>>)" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Activity Charts Trends companion plan and routed future
  implementation through M87-M88.
- Confirmed `Category Trend` should remain a month-by-month category table,
  horizontally scrollable on compact widths.
- Confirmed the new top-10 chart should be a horizontally scrollable multi-line
  chart using the existing `fl_chart` dependency.
- Confirmed top-10 category ranking uses total filtered net expense, and the
  chart applies all existing Activity Charts filters.
- Confirmed the data path remains client-side through existing
  `TrendReport.fromTransactions(...)` aggregation for this sequence.
- M87 was not started.
- Assumptions made:
  - Existing trend aggregation is adequate for v1 because Activity Charts
    already fetches filtered transactions and builds `CategoryTrend.months`.
  - `netExpense` / `netSpend` is the intended expense basis.
  - The top-10 chart should collapse to the selected category when the category
    filter is active.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M87 - Activity Charts Month-by-Month Category Trends

Status: Planned.

Purpose: Repair the visible Activity Charts category trend presentation and add
a top-category monthly comparison chart.

Instructions:

- Before editing, inspect this plan, `README.md`, `MILESTONES.md`,
  `SESSION_HANDOFF.md`, `UI_REDESIGN.md`, `DESIGN.md`,
  `apps/mobile/lib/src/features/activity/activity_screen.dart`,
  `apps/mobile/lib/src/features/trends/trends_screen.dart`,
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`, and
  `apps/mobile/test/finance_features_test.dart`.
- Keep the implementation Flutter-only. Do not change repository interfaces,
  Supabase schema, RPCs, imports, Edge Functions, or CSV export.
- In `trends_screen.dart`, remove the compact-width branch that replaces
  `Category Trend` with `_CompactCategoryTrendRow` total-only rows.
- Keep `Category Trend` as a horizontally scrollable table on all widths:
  `Category`, `Txns`, `Total`, then one column per month from
  `report.monthlySpend`.
- Make the table readable at 390px by using stable minimum widths, constrained
  category labels, and horizontal scrolling rather than hiding month columns.
- Add a new `_TopCategoryMonthlyChart`-style private widget and render it as a
  new report section before `Category Trend`.
- Title the section `Top 10 Categories by Month`.
- Build the chart from `report.categoryTrends.take(10)` because
  `categoryTrends` is already sorted by total filtered `netSpend` descending.
- Plot each selected category as one line across `category.months`, using the
  same month order as `report.monthlySpend`.
- Size the chart with a fixed height and a horizontally scrollable width based
  on month count. Use the existing `_MonthlyNetChart` pattern as the starting
  point.
- Add a compact wrapped legend with stable theme-derived colors and truncated
  category labels.
- Use `_compactMoney(...)` for the Y-axis and `_shortMonth(...)` for the
  X-axis.
- Handle empty category trends with an `EmptyState`; do not crash on all-zero
  or negative values.
- Keep chart values non-cumulative. Do not derive running totals or cumulative
  sums.
- Add/extend tests in `apps/mobile/test/finance_features_test.dart` so fixture
  trend transactions include at least two categories across at least two
  months.
- Add focused model expectations proving `CategoryTrend.months` values are
  independent monthly buckets, including a month where a category has zero
  spend.
- Add widget coverage at 390px proving `Category Trend` still exposes month
  labels and monthly values instead of only category totals.
- Add widget coverage proving `Top 10 Categories by Month` renders and respects
  an active category filter.
- Do not start M88 docs closeout in this milestone beyond the normal milestone
  completion updates required by this plan and `SESSION_HANDOFF.md`.

Expected code shape:

- Presentation-only changes should remain localized to `trends_screen.dart`
  and `finance_features_test.dart` unless test fixtures require small helper
  edits.
- Reuse existing `TrendReport`, `CategoryTrend`, and `CategoryTrendMonth`
  models.
- Reuse `fl_chart`; no new package should be added.

Acceptance criteria:

- On compact Activity Charts widths, `Category Trend` shows month-by-month
  category values through horizontal scrolling.
- The monthly values are net monthly buckets, not accumulated totals.
- `Top 10 Categories by Month` shows up to 10 category lines in one chart.
- Existing Activity chart filters affect both the top-10 chart and the category
  trend table.
- Existing metric cards, monthly net chart, gross/refunds/net table, filters,
  and CSV copy behavior continue to work.
- No Supabase or repository contract changes are introduced.

Verification:

```bash
cd apps/mobile
dart format --set-exit-if-changed lib/src/features/trends/trends_screen.dart test/finance_features_test.dart
flutter analyze
flutter test test/finance_features_test.dart --name "trend report aggregates monthly category"
flutter test test/finance_features_test.dart --name "activity charts"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M88 - Activity Charts Regression, Docs, and Cleanup

Status: Planned.

Purpose: Verify the complete Activity Charts trend improvement and fold final
behavior into durable docs.

Instructions:

- Before editing, inspect this plan, `README.md`, `MILESTONES.md`,
  `SESSION_HANDOFF.md`, `UI_REDESIGN.md`, `DESIGN.md`, and the M87 diff.
- Run focused Activity Charts regression and the broader Flutter validation
  path listed below.
- Verify responsive behavior at minimum 390px mobile width, plus tablet and
  desktop-width coverage when tests or manual inspection make that practical.
- Confirm no visible chart/table overflows, clipped primary values, hidden month
  labels, or unreadable legends remain.
- Confirm M87 did not introduce Supabase, importer, Edge Function, iOS, web,
  push-notification, hosted rollout, or CSV export changes.
- Update `README.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`, and this plan with
  final behavior and closeout notes.
- If M87 and M88 are complete, mark this companion plan completed-only in the
  routing docs.
- Do not start any new Activity export, chart drilldown, server-side reporting
  aggregate, or transaction editing feature.

Expected code shape:

- Prefer documentation and test cleanup only unless regression finds a narrow
  Activity Charts bug.
- Any bug fix must stay scoped to the M87 behavior and be covered by focused
  widget/model tests.

Acceptance criteria:

- Focused Activity Charts tests pass.
- Full Flutter analyze and test pass, or any environment limitation is recorded
  with compensating evidence.
- Durable docs describe the final Activity Charts trend behavior.
- `ACTIVITY_CHARTS_TRENDS.md` is marked completed-only after M88.
- No unrelated deferred work is started.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart --name "activity charts"
flutter test
git diff --check
rg -n "ACTIVITY_CHARTS_TRENDS|Milestone 8[6-8]|Top 10 Categories|Category Trend" docs/implementation-plan
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
