# Monthly Cap Drilldown Plan

Last updated: 2026-06-28

This document is the implementation plan for showing the transactions inside a
monthly cap from Dashboard. Each milestone below is a standalone milestone
intended to be executed in a separate Codex thread. Stop after completing and
documenting the current milestone; do not automatically continue to the next
milestone.

## Target Behavior

Dashboard monthly cap rows open a dedicated cap transaction screen for the
selected dashboard month. This screen is not Activity with filters applied.

- A user taps a cap row in Dashboard's Monthly caps section and lands on a new
  Dashboard-context page for that cap and month.
- The page shows all transactions that contributed to the cap for that month.
- Cap membership uses the existing monthly-cap semantics: a transaction matches
  when its category matches any selected category target or any of its labels
  matches any selected label target.
- A transaction appears once inside a cap even when both category and label
  targets match it.
- The same transaction may still appear in multiple different caps when caps
  overlap.
- Rows with an open Review queue item are highlighted and show an
  `Under review` warning chip.
- The cap drilldown is view-only. It does not expose transaction edit, label
  edit, or delete actions; those remain owned by Activity and Review.
- Back navigation returns to Dashboard when there is navigation history, or
  falls back to Dashboard when opened directly.
- The UI uses the existing DESIGN.md-backed app design system and shared
  primitives.

## Existing Foundation

- Dashboard cap UI lives in
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`.
- App routing lives in `apps/mobile/lib/src/app/router.dart`; the shell treats
  child paths under `/dashboard/...` as Dashboard context.
- Monthly cap progress uses `MonthlyCapProgress` and
  `public.get_monthly_cap_progress(...)` through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`.
- Recurring cap target matching already exists in the `matched_transactions`
  CTE inside the carry-forward progress migration.
- Current Activity filters cannot represent mixed multi-category and multi-label
  cap membership, so cap drilldown must not reuse Activity route filters.
- Transaction rows and detail behavior currently live in
  `apps/mobile/lib/src/features/transactions/transactions_screen.dart`.
- Open review state is represented by `public.review_items` rows with
  `status = 'open'`; `public.v_review_queue` exposes those rows for app
  review surfaces.
- Shared app primitives include `AppPage`, `AppContentCard`, `StatusChip`,
  `AppActionPill`, `LargeAmountText`, and responsive helpers.
- Widget and repository tests for finance features live in
  `apps/mobile/test/finance_features_test.dart`.
- Monthly cap database regression coverage lives in `supabase/tests/monthly_caps.sql`.

## Global Rules For M78-M81

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Do not redirect cap drilldowns to Activity or encode cap targets as Activity
  query filters.
- Keep cap membership calculation in the backend contract. Do not build
  membership client-side by issuing multiple category or label queries.
- Define `under review` as an open `review_items` row for the transaction.
  Low confidence alone is not enough to show the review highlight.
- Use the Supabase skill before Supabase schema/RPC work. Check relevant
  Supabase CLI help before migrations and use
  `supabase migration new <descriptive_name>` for schema changes.
- Keep app-facing database work authenticated, household-scoped, RLS-safe, and
  free of service-role credentials in Flutter.
- Use DESIGN.md and existing shared primitives for all visible UI.
- Cap transaction drilldown remains Android-first. Do not add iOS, web,
  hosted rollout, push notifications, or transaction-management expansion in
  this sequence.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M78 - Monthly Cap Drilldown Planning and Reference Readiness

Status: Completed on 2026-06-28.

Purpose: Create this companion plan and wire M79-M81 into durable planning
docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `DATA_MODEL.md`, `MONTHLY_CAPS.md`, `MILESTONES.md`, and
  `SESSION_HANDOFF.md` so a fresh session can start M79 from docs alone.
- Preserve M18-M21 push-notification deferral.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, web, or runtime implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `MONTHLY_CAP_DRILLDOWN.md` describes M78-M81 as serial standalone
  milestones.
- M79 is the next recommended non-deferred implementation milestone.
- The docs state that implementation remains planned only.

Verification:

```bash
rg -n "MONTHLY_CAP_DRILLDOWN|Milestone 7[8-9]|Milestone 8[0-1]|get_monthly_cap_transactions|Under review" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Monthly Cap Drilldown companion plan and routed future
  implementation through M79-M81.
- Confirmed cap drilldown must be a dedicated Dashboard-context screen, not
  Activity with filters applied.
- Confirmed the transaction list is view-only, rows open no edit/delete/label
  actions, and transaction management remains in Activity and Review.
- Confirmed `Under review` means an open Review queue row for the transaction.
- Confirmed each cap row is the entry point, with Edit and Stop remaining
  separate controls.
- M79 was not started.
- Assumptions made:
  - Cap drilldown should show the dashboard's currently selected month.
  - The first implementation should use paginated backend reads rather than a
    large unbounded list.
  - Cap progress and carry-forward summary values remain sourced from existing
    monthly cap progress contracts.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M79 - Monthly Cap Transaction Data Contract

Status: Completed on 2026-06-28.

Purpose: Add the backend and Flutter repository contract needed to read the
transactions that belong to one cap for one month.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `MONTHLY_CAPS.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`,
  `supabase/migrations/20260613131821_carry_forward_progress_semantics.sql`,
  `supabase/tests/monthly_caps.sql`,
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`, and
  `apps/mobile/test/finance_features_test.dart`.
- Use the Supabase skill. Check `supabase --version`,
  `supabase migration --help`, `supabase db --help`, and relevant Supabase
  changelog/docs before schema work.
- Create the migration with
  `supabase migration new monthly_cap_transactions_drilldown`.
- Add `public.get_monthly_cap_transactions(...)` as a read-only
  `security invoker` RPC with this shape:
  - `p_household_id uuid`
  - `p_monthly_cap_id uuid`
  - `p_period_month date`
  - `p_limit integer default 25`
  - `p_offset integer default 0`
- Validate a signed-in profile, active household membership, a first-day
  `p_period_month`, and bounded pagination. Use a maximum limit of 100.
- Resolve the cap version active for `p_monthly_cap_id` in `p_period_month`
  using the same selected-month-forward recurring semantics as
  `get_monthly_cap_progress(...)`.
- Return only transactions that match that active version's category OR label
  targets in the requested month.
- Return each matching transaction once, ordered by `transaction_date desc`,
  `created_at desc`, and `id desc`.
- Return the fields needed by a view-only row:
  - transaction id, date, statement merchant, merchant id/name, category
    id/name, subcategory id/name, source account id, transaction type, amount,
    gross spend, refund amount, net expense, currency code, confidence,
    cardholder name, notes
  - ordered label ids/names attached to the transaction
  - `is_under_review`, true when an open `review_items` row exists for the
    transaction
  - `review_item_id`, the newest open review item id for that transaction, or
    null
- Do not expose service-only diagnostics, raw Gmail data, parser payloads, or
  privileged credentials.
- Add pgTAP coverage proving category-only, label-only, mixed category+label,
  duplicate target match counted once, overlapping cap independence,
  selected-month filtering, pagination ordering, and open-review highlighting.
- Add Flutter repository request/page/row models and a
  `monthlyCapTransactionsProvider` family.
- Keep `TransactionQuery` and Activity route parsing unchanged.
- Add focused Dart tests for request equality, JSON parsing, repository calls,
  pagination values, labels, and `isUnderReview`.
- Do not build the visible Dashboard route or screen in this milestone.

Expected code shape:

- The RPC owns exact cap membership for the requested cap/month.
- Flutter receives a purpose-built cap transaction page instead of coercing
  Activity filters.
- The repository keeps this feature additive and does not change existing
  transaction search/filter behavior.

Acceptance criteria:

- A household member can fetch the transactions inside one visible active cap
  for one month.
- The RPC returns no duplicates when one transaction matches both category and
  label targets.
- `is_under_review` is true only for transactions with open review rows.
- Non-members and invalid households cannot read cap transactions.
- Existing monthly cap progress, Activity filters, label filters, and
  transaction pagination remain unchanged.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/monthly_caps.sql
supabase test db --local supabase/tests/rls_isolation.sql
supabase db lint --local --schema app_private,public --fail-on error
cd apps/mobile && flutter test test/finance_features_test.dart --name "monthly cap transaction|MonthlyCapTransaction"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added `public.get_monthly_cap_transactions(...)` as a read-only
  `security invoker` RPC for one active recurring cap series and first-day
  reporting month.
- The RPC validates signed-in profile access, active household membership,
  first-day month input, required cap id, and bounded pagination with a maximum
  limit of 100.
- Cap membership stays backend-owned and matches the active selected-month
  version's category OR label targets; rows are returned once per transaction
  even when both target types match.
- Returned row fields include merchant/category/subcategory names, ordered
  label ids/names, and open-review state with the newest open review item id.
- Added pgTAP coverage for category-only, label-only, mixed, duplicate,
  overlapping cap, month-filtered, paginated, open-review, viewer, and
  non-member behavior.
- Added Flutter repository request/page/row models,
  `monthlyCapTransactionsProvider`, a Supabase RPC implementation, disabled
  repository handling, and focused Dart tests without changing Activity filters
  or adding the Dashboard route/screen.
- Milestone 80 was not started.
- Verification run:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/monthly_caps.sql`
  - `supabase test db --local supabase/tests/rls_isolation.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "monthly cap transaction|MonthlyCapTransaction"`
- Assumptions made:
  - `p_monthly_cap_id` is the recurring cap-series id from Dashboard monthly
    cap progress.
  - The M79 backend contract should normalize pagination bounds rather than
    fail requests with out-of-range limit/offset values.
  - M79 should support active recurring cap series only; legacy compatibility
    cap rows remain outside the new drilldown contract.
- Mocks created:
  - None.
- Mocks used:
  - Extended the existing `_FakeFinanceRepository` test double for focused
    Flutter repository/provider tests.

## M80 - Dashboard Cap Drilldown Route and View-Only Screen

Status: Completed on 2026-06-28.

Purpose: Make Dashboard cap rows open the new cap transaction screen and render
the paginated view-only transaction list.

Instructions:

- Before editing, inspect this plan, `DESIGN.md`, `README.md`,
  `MILESTONES.md`, `SESSION_HANDOFF.md`,
  `apps/mobile/lib/src/app/router.dart`,
  `apps/mobile/lib/src/app/app_shell.dart`,
  `apps/mobile/lib/src/features/dashboard/dashboard_screen.dart`,
  `apps/mobile/lib/src/features/transactions/transactions_screen.dart`,
  `apps/mobile/lib/src/shared/widgets/app_primitives.dart`, and
  `apps/mobile/test/finance_features_test.dart`.
- Add a Dashboard-context route such as
  `/dashboard/monthly-caps/:capId/transactions?month=YYYY-MM-DD`.
- Parse the month query as a first-day-of-month date. If it is missing or
  invalid, show an error/empty state rather than falling through to Activity.
- Fetch the household context, selected-month Dashboard snapshot, and the
  matching cap summary by cap id. Use existing `MonthlyCapProgress` values for
  title, target chips, spent, available, remaining/over, percent, and matched
  count.
- Fetch the paginated rows through the M79 repository provider.
- Add a Back action using the existing Settings-style router pattern:
  `pop()` when possible, otherwise `go(DashboardScreen.routePath)`.
- Make each Dashboard monthly cap row tappable with a clear view affordance
  such as a chevron and semantic label. Keep Edit and Stop as separate
  IconButtons that do not trigger row navigation.
- Preserve existing Add cap, Edit cap, Stop cap, carry-forward, and top
  category/merchant Activity drilldown behavior.
- Render the new screen with existing design-system primitives:
  - `AppPage` with Dashboard-context title/subtitle
  - cap summary card using `AppContentCard`, `LargeAmountText`, `StatusChip`,
    and target chips
  - view-only transaction cards using App colors, typography, and spacing
  - `Under review` warning `StatusChip` plus a warning border/surface when
    `isUnderReview` is true
  - empty, loading, error, previous page, and next page states
- Do not expose transaction detail, edit metadata, edit labels, or delete
  actions from this cap drilldown screen.
- Do not add subcategory, merchant, source-account, amount-range, export, or
  Activity-filter behavior in this milestone.

Expected code shape:

- The route belongs to Dashboard navigation, so the shell highlights Dashboard
  rather than Activity.
- The cap screen uses the M79 contract directly and remains view-only.
- Any shared transaction-row extraction must preserve Activity's current
  management actions and avoid widening this screen's scope.

Acceptance criteria:

- Tapping a monthly cap row opens the cap transaction route, not `/activity`.
- The page shows the selected cap's summary, targets, and paginated matching
  transactions for the selected month.
- Under-review transactions are visibly highlighted and marked.
- Edit/Stop cap controls still work and do not navigate to the drilldown.
- Back returns to Dashboard.
- Narrow 390px layout has no overflow and keeps action text/buttons readable.

Verification:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "monthly cap drilldown|Dashboard cap"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added the Dashboard-context route
  `/dashboard/monthly-caps/:capId/transactions?month=YYYY-MM-DD` and parse
  handling for first-day reporting months.
- Made Dashboard monthly cap rows tappable cards with a chevron view
  affordance, semantic labels, and separate Edit/Stop icon buttons that keep
  their existing cap-management behavior.
- Added a view-only cap transaction screen that fetches household context, the
  selected Dashboard month snapshot, the matching `MonthlyCapProgress` summary,
  and paginated rows from `monthlyCapTransactionsProvider`.
- Rendered the cap summary with existing design primitives, target chips,
  spent/base/available/remaining/matched metrics, and paginated transaction
  cards with no transaction detail, metadata edit, label edit, or delete
  actions.
- Highlighted open-review transactions with an `Under review` warning chip and
  warning border while keeping low confidence alone out of the UI marker.
- Added loading, empty, invalid-month, stale-cap, error, previous page, next
  page, and Back-to-Dashboard states, including 390px widget coverage.
- Milestone 81 was not started.
- Verification run:
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "monthly cap drilldown|Dashboard cap"`
  - `git diff --check`
- Assumptions made:
  - The Dashboard route should keep using `month=YYYY-MM-DD` with a first-day
    date and show a Dashboard-context error for missing or invalid values.
  - A 10-row UI page size keeps the drilldown readable on narrow phones while
    the M79 backend/repository contract remains the source of truth for cap
    membership and pagination normalization.
  - Direct stale links to inactive caps should show an empty state with a
    Dashboard fallback rather than redirecting to Activity.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` test double for Dashboard route,
    pagination, open-review highlighting, invalid-month, and 390px widget
    coverage.

## M81 - Monthly Cap Drilldown Regression, Docs, and Cleanup

Status: Planned.

Purpose: Verify the complete cap drilldown workflow and fold final behavior
back into durable docs.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `MONTHLY_CAPS.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`,
  `supabase/tests/monthly_caps.sql`, `apps/mobile/test/finance_features_test.dart`,
  and the M79/M80 implementation diffs.
- Run the focused local regression path for monthly cap progress, cap
  transactions, Activity filters, Review highlighting, Dashboard cap controls,
  and Flutter responsive layout.
- Update durable docs with final behavior:
  - `README.md`
  - `DATA_MODEL.md`
  - `MONTHLY_CAPS.md`
  - `MILESTONES.md`
  - `SESSION_HANDOFF.md`
  - this plan
- Mark this plan completed-only after M81 completes.
- Confirm hosted Supabase migration push and app release work remain separate
  explicit rollout operations unless the user asks for them.
- Do not start push notifications, iOS, web, Activity export, cap reports, cap
  notifications, transaction editing from cap drilldown, or any unrelated
  cleanup.

Expected code shape:

- Regression fixes only. Do not introduce new cap targets or new transaction
  management capabilities during closeout.
- Durable docs should describe the final implemented contract and remove stale
  "planned" wording for M79-M81.

Acceptance criteria:

- Focused Supabase and Flutter verification passes locally or documents an
  environment limitation with compensating evidence.
- Dashboard cap drilldown, existing cap edit/delete, Activity filters, and
  Review semantics work together without route or provider regressions.
- Durable docs describe the cap transaction drilldown and under-review
  highlighting behavior.
- `MONTHLY_CAP_DRILLDOWN.md` is marked completed-only.
- No unrelated deferred work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/monthly_caps.sql
supabase test db --local supabase/tests/rls_isolation.sql
supabase db lint --local --schema app_private,public --fail-on error
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
