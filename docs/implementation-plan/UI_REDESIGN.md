# SpendLens UI Redesign Plan

Last updated: 2026-06-13

This document is the implementation plan for the SpendLens UI redesign. Each
milestone below is a standalone milestone intended to be executed in a separate
Codex thread. Stop after completing and documenting the current milestone; do
not automatically continue to the next milestone.

## Target Behavior

- Redesign the Flutter Android app around `DESIGN.md`, using the stored Stitch
  mocks as screen hierarchy and layout reference.
- Use a four-item primary navigation model: Dashboard, Activity, Review, and
  Vaults.
- Consolidate the current Transactions and Trends experiences into one
  Activity destination with List and Charts modes.
- Remove Settings from primary bottom navigation and expose it as a focused
  page opened from a global shell settings action.
- Add light, dark, and system theme support. The default must be system, and the
  selected mode must persist locally on the device.
- Preserve all existing finance, ingestion, category, label, review,
  transaction metadata, AI, Gmail connector, and piggy-bank behavior unless a
  milestone explicitly changes visible information architecture or copy.

## Existing Foundation

- Flutter app source lives under `apps/mobile/lib/src`.
- Current shell and routes live in `apps/mobile/lib/src/app/app_shell.dart` and
  `apps/mobile/lib/src/app/router.dart`.
- Current theme lives in `apps/mobile/lib/src/core/theme/app_theme.dart` and
  only exposes `AppTheme.light()`.
- Current primary destinations are Dashboard, Transactions, Trends, Review,
  Piggy Banks, and Settings. This is intentionally replaced by the UI redesign.
- Current feature screens:
  - `features/dashboard/dashboard_screen.dart`
  - `features/transactions/transactions_screen.dart`
  - `features/trends/trends_screen.dart`
  - `features/merchant_review/merchant_review_screen.dart`
  - `features/piggy_banks/piggy_banks_screen.dart`
  - `features/settings/settings_screen.dart`
  - `features/transaction_metadata/transaction_metadata_editor.dart`
  - `features/ai/ai_screen.dart`
  - `features/auth/sign_in_screen.dart`
- Current shared UI widgets are small and should be expanded or replaced:
  `AppPage`, `MetricCard`, `EmptyState`, and `PeriodFilterDropdown`.
- Existing Flutter regression coverage is concentrated in
  `apps/mobile/test/finance_features_test.dart`, with app smoke coverage in
  `apps/mobile/test/widget_test.dart` and `apps/mobile/integration_test/app_test.dart`.
- `flutter analyze` passed on 2026-06-13 before creating this plan.

## Design Sources

- `DESIGN.md` is the source of truth for tokens, component rules, and brand
  behavior.
- Stitch references are stored under
  `docs/design-references/stitch/themed-dashboard-ui-redesign/`.
- Stitch HTML must not be copied into Flutter. Use it only for visual structure,
  hierarchy, spacing, and copy reference.
- Screen mapping:
  - Dashboard: `screens/dashboard-unified-navigation.jpg`
  - Activity List: `screens/activity-scandi-fintech-refinement.jpg`
  - Activity Charts: `screens/activity-unified-navigation.jpg`
  - Review: `screens/review-unified-navigation.jpg`
  - Vaults: `screens/vaults-scandi-fintech-refinement.jpg`
  - Settings: `screens/settings-focused-view-no-nav.jpg`
  - Transaction details: `screens/transactions-details-refined-shapes.jpg`
  - Transaction metadata editor: `screens/transactions-edit-metadata.jpg`

## Global Rules For M36-M51

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 deferred unless the user explicitly resumes push
  notification work.
- Do not introduce Supabase schema, Edge Function, RLS, or repository-query
  changes for purely visual work.
- Theme mode persistence is local device state only; do not add a backend field
  for it.
- Preserve finance semantics: use `net_expense`, exclude card bill payments
  from spend, refunds reduce net spend, transaction labels stay separate from
  categories, and monthly caps keep category/label OR matching, one-count-per-cap
  semantics, overlap support, recurring series identity, and positive/negative
  carry-forward behavior.
- Use `LayoutBuilder`, `MediaQuery.sizeOf`, constrained max widths, lazy list or
  grid builders for long/unknown lists, and valid `Expanded`/`Flexible`
  placement.
- Do not use top-level orientation or hardware-type checks for responsive
  decisions.
- Treat these layout issues as blockers before completing a milestone:
  RenderFlex overflow, unbounded scrollable height, unbounded text-field width,
  incorrect ParentData widgets, and clipped primary actions.
- Every visible icon-only action needs either a tooltip or semantic label.
- Motion must be purposeful and cheap: prefer implicit fade/slide/scale for
  segmented controls, cards, button press states, and loading states. Respect
  `MediaQuery.accessibleNavigation`.
- Each milestone completion update must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M36 - UI Redesign Planning and Reference Readiness

Status: completed on 2026-06-13 by creating this plan.

Purpose: make the redesign executable by future fresh-context sessions without
relying on chat history.

Instructions:

- Confirm the repo has no unresolved conflict markers.
- Confirm Stitch references exist under
  `docs/design-references/stitch/themed-dashboard-ui-redesign/`.
- Create this companion plan and wire it into `README.md`, `MILESTONES.md`, and
  `SESSION_HANDOFF.md`.
- Set the next recommended implementation milestone to M37.
- Do not change Flutter UI code in this milestone.

Expected code shape:

- Documentation-only change.
- The Stitch bundle remains reference material; production UI still comes from
  Flutter widgets and theme tokens.

Acceptance criteria:

- The UI redesign plan is self-contained.
- The implementation tracker lists M36-M51.
- The handoff points new sessions to M37.
- No Flutter UI implementation work starts.

Verification:

```bash
rg -n "^(<<<<<<<|=======|>>>>>>>)" docs apps/mobile supabase tools
git status --short
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M37 - Design Tokens, Themes, and Theme Preference

Status: completed on 2026-06-13.

Purpose: establish the theme foundation that all screen milestones will use.

Instructions:

- Inspect `DESIGN.md`, Stitch project metadata, `app_theme.dart`,
  `spend_lens_app.dart`, and `pubspec.yaml`.
- Replace the seed-color theme with an explicit token layer based on DESIGN.md:
  lime primary CTA `#9fe870`, on-primary ink `#0e0f0c`, sage canvas
  `#e8ebe6`, white cards, ink text, body/mute text, positive/warning/negative
  semantic colors, and 24px canonical card/button radius.
- Add `AppTheme.light()` and `AppTheme.dark()`.
- Add a local `ThemeMode` controller/provider with exactly these modes:
  `system`, `light`, and `dark`.
- Default to `ThemeMode.system`.
- Persist the selected mode locally on the device. Add the smallest appropriate
  Flutter dependency if the current dependency set does not already provide
  local key-value storage.
- Wire `SpendLensApp` to pass `theme`, `darkTheme`, and `themeMode` into
  `MaterialApp.router`.
- Add theme tests that prove the default is system and that changed mode values
  are parsed, saved, loaded, and applied.
- Do not redesign individual screens beyond what is needed to keep current UI
  readable under both themes.

Expected code shape:

- Theme constants should be centralized and referenced by `ThemeData`.
- Dark mode should be token-driven, not an inverted color accident.
- Future screen widgets should not hard-code brand colors except through the
  shared theme/token layer.

Acceptance criteria:

- App boots with system theme mode by default.
- Light and dark themes are both available to `MaterialApp.router`.
- Theme selection persists locally and survives app restart.
- No Supabase schema or repository change is introduced.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Replaced the seed-color-only app theme with centralized `AppThemeTokens`,
  semantic color extension values, explicit `AppTheme.light()`, and explicit
  `AppTheme.dark()`.
- Added a local system/light/dark theme-mode controller and store backed by
  shared preferences, defaulting to `ThemeMode.system` while loading or when no
  valid stored value exists.
- Wired `SpendLensApp` to pass `theme`, `darkTheme`, and `themeMode` into
  `MaterialApp.router`.
- Added focused theme tests for token use, mode parsing, shared-preferences
  save/load, provider default/load/change behavior, and app-level theme-mode
  application.
- Verification:
  - `cd apps/mobile && flutter pub get`
  - `cd apps/mobile && dart format lib/src/core/theme/app_theme.dart lib/src/core/theme/theme_mode_controller.dart lib/src/app/spend_lens_app.dart test/theme_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
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

## M38 - Shared Responsive UI Primitives

Status: completed on 2026-06-13.

Purpose: create reusable UI building blocks before individual screen redesigns.

Instructions:

- Inspect current shared widgets and the screen code that uses them.
- Replace or extend `AppPage`, `MetricCard`, and `EmptyState` with
  DESIGN.md-aware primitives.
- Add reusable primitives for:
  - responsive page scaffold with safe-area and bottom-nav spacing awareness
  - large display heading
  - section heading with divider rhythm
  - white content card
  - sage feature card
  - dark feature card
  - metric card
  - filter pill
  - status chip
  - icon chip
  - large amount text
  - primary/secondary/destructive action pills
  - modal or bottom-sheet card shell
  - loading and error states
- Encode responsive breakpoints from DESIGN.md:
  mobile below 768px, tablet 768-1023px, desktop at 1024px and above.
- Use `LayoutBuilder` for parent-constraint decisions and `MediaQuery.sizeOf`
  for app-window size when needed.
- Constrain large-screen content widths so lists and forms do not stretch
  edge-to-edge.
- Add small focused widget tests for representative primitives.
- Do not change app navigation or screen behavior in this milestone.

Expected code shape:

- Shared primitives should be small composable widgets, not one large UI
  kitchen-sink widget.
- Lists with unknown length should stay lazy.
- Forms embedded in rows must constrain text fields with `Expanded`,
  `Flexible`, or explicit max width.

Acceptance criteria:

- Shared widgets visually reflect sage canvas, white rounded cards, bold display
  text, and pill actions.
- Shared widgets render in both light and dark themes.
- Existing feature tests keep passing.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added shared breakpoint helpers for mobile below 768px, tablet 768-1023px,
  and desktop at 1024px and above.
- Extended `AppPage` into a responsive, safe-area-aware page scaffold with
  constrained desktop content width and mobile bottom-navigation spacing.
- Added reusable shared primitives for display headings, section headings,
  white content cards, sage and dark feature cards, metric cards, filter pills,
  status chips, icon chips, large amount text, primary/secondary/destructive
  action pills, modal/bottom-sheet card shells, and loading/error states.
- Added `app_primitives.dart` as a shared-widget barrel for upcoming screen
  milestones.
- Added focused primitive tests covering breakpoint classification, page
  padding/content width behavior, and representative light/dark rendering.
- Existing screen constructors for `AppPage`, `MetricCard`, and `EmptyState`
  remain compatible.
- Verification:
  - `cd apps/mobile && dart format lib/src/shared/widgets/action_pill.dart lib/src/shared/widgets/amount_text.dart lib/src/shared/widgets/app_card.dart lib/src/shared/widgets/app_page.dart lib/src/shared/widgets/app_primitives.dart lib/src/shared/widgets/chips.dart lib/src/shared/widgets/empty_state.dart lib/src/shared/widgets/metric_card.dart lib/src/shared/widgets/responsive.dart test/shared_primitives_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/shared_primitives_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The checked-in root `DESIGN.md` and the M37 tokenized `AppTheme` layer are
    the current design-system source for M38 primitives.
  - Current screen behavior and navigation should remain unchanged; screen
    redesign starts in later milestones.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M39 - App Shell, Navigation IA, and Routes

Status: completed on 2026-06-13.

Purpose: implement the new app information architecture before screen-specific
redesign.

Instructions:

- Inspect `app_shell.dart`, `router.dart`, dashboard drilldown routing, settings
  category drilldown routing, and route-related tests.
- Add a primary Activity destination at `/activity`.
- Remove active `/transactions` and `/trends` routes instead of redirecting or
  aliasing them.
- Replace the primary destination list with exactly:
  Dashboard, Activity, Review, Vaults.
- Remove Settings from bottom navigation and primary rail/sidebar navigation.
- Add a global shell settings action that opens `/settings`.
- Keep `/settings` as a focused route inside authenticated app context.
- Keep Ask/AI as a non-primary route unless the user later asks to promote it.
- Update internal navigation:
  - Dashboard category and merchant drilldowns go to Activity list mode.
  - Settings category detail drilldowns go to Activity list mode.
  - Existing transaction label/category/date query semantics remain available
    through Activity.
- Update route tests and any helper routers in tests.
- Do not redesign screen content beyond shell/navigation requirements.

Expected code shape:

- Add an `ActivityScreen` integration point that can host list and charts modes
  in later milestones.
- The old transactions and trends screen classes may remain temporarily as
  private implementation widgets only if that reduces risk, but they must not
  remain as app routes after this milestone.
- Wide layouts should use adaptive shell chrome; mobile uses the four-item
  bottom navigation.

Acceptance criteria:

- Mobile bottom navigation has exactly Dashboard, Activity, Review, Vaults.
- Settings is reachable from a global gear action and is not a primary tab.
- `/transactions` and `/trends` are not active routes.
- All internal app navigation targets valid routes.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

- Added `/activity` as the authenticated Activity destination through a new
  `ActivityScreen` integration point that can host list and charts modes in
  later milestones.
- Removed active `/transactions` and `/trends` app routes rather than
  redirecting or aliasing them.
- Replaced primary shell destinations with exactly Dashboard, Activity, Review,
  and Vaults on mobile bottom navigation and wide navigation rail.
- Removed Settings from primary navigation and added a global shell settings
  action that opens `/settings`; Ask/AI remains a non-primary route.
- Updated Dashboard category/merchant drilldowns and Settings category-detail
  drilldowns to target Activity while preserving existing category, label,
  merchant, `startDate`, and `endDate` query semantics.
- Added/updated route and shell tests for Activity, the four primary
  destinations, and the settings action.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_route.dart lib/src/features/activity/activity_screen.dart lib/src/app/router.dart lib/src/app/app_shell.dart lib/src/features/dashboard/dashboard_screen.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart test/widget_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The visible Vaults destination can continue to use the existing
    `/piggy-banks` route until later Vaults-specific work.
  - Existing transaction-list implementation remains the temporary Activity list
    implementation; full list/charts migration remains deferred to M41-M42.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M40 - Dashboard Screen

Status: completed on 2026-06-14.

Purpose: rebuild Dashboard to match the Stitch dashboard mock while preserving
finance behavior.

Instructions:

- Inspect the Dashboard Stitch screenshot and HTML, current
  `dashboard_screen.dart`, dashboard tests, and monthly-cap docs.
- Use the Stitch hierarchy:
  - large `Dashboard` display title
  - settings affordance in the shell/top area
  - month pill
  - Spending section
  - large net-spend card
  - month-change card
  - Review section with queue card
  - Monthly caps compact progress rows
  - Top categories list cards
- Preserve Dashboard data behavior:
  - selected reporting month
  - current month net spend
  - month-over-month value and percent
  - review queue count
  - recurring monthly caps
  - cap add/edit/delete
  - carry-forward display
  - top category and merchant drilldowns
- Update drilldowns to Activity route and list mode.
- Keep the cap form behavior intact unless M50 later restyles the sheet.
- Make long cap names, target chips, and money amounts fit mobile width.
- Do not change monthly-cap backend semantics.

Expected code shape:

- Dashboard should use shared primitives from M38.
- Prefer stacked mobile-first sections with adaptive grids only when width
  allows.
- White cards sit on sage canvas; no legacy 8px card chrome should remain in
  the Dashboard surface.

Acceptance criteria:

- Existing Dashboard cap workflow tests pass after route/copy updates.
- Dashboard matches the Stitch visual hierarchy.
- Top category and merchant taps open Activity with equivalent filters.
- No overflow at 390px width.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion notes:

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
- Added a 390px Dashboard hierarchy widget regression test.
- No Activity List mode migration, Activity Charts migration,
  Review/Vaults/Settings visual redesign, cap backend/schema/RPC work, hosted
  rollout, push notification, M41, or later-milestone work was started.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
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

## M41 - Activity List Mode

Purpose: migrate transaction list behavior into Activity List mode.

Instructions:

- Inspect Activity List Stitch screenshot and HTML, current
  `transactions_screen.dart`, transaction tests, and filter providers.
- Implement Activity page with a `List` / `Charts` segmented control.
- Make List the default mode.
- Move transaction search and filtering into Activity List:
  merchant search, category, label, source type, source account, period, custom
  date range, clear filters, and pagination.
- Render filters as pill-like controls with horizontal scrolling or responsive
  wrapping on narrow widths.
- Restyle transaction rows as large rounded cards with:
  - icon chip
  - merchant/group name
  - date and statement/category/subcategory/type metadata
  - amount
  - label chips and overflow chip
  - tap target for detail
- Preserve label edit and metadata edit entry points.
- Update all transaction-list tests to use Activity and `/activity`.
- Do not implement charts mode in this milestone except a placeholder or
  disabled structure required by the segmented control.

Expected code shape:

- Activity state owns the selected mode and list filters.
- Transaction query construction should remain equivalent to current behavior.
- `TransactionInitialFilters` may move or be renamed, but its query semantics
  must survive for Dashboard and Settings drilldowns.

Acceptance criteria:

- Activity List covers current transaction list behavior.
- Existing transaction search/filter/label tests pass after route/copy updates.
- No app code still navigates to `/transactions`.
- Long merchant names and labels do not overflow.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M42 - Activity Charts Mode

Purpose: migrate Trends behavior into Activity Charts mode.

Instructions:

- Inspect Activity Charts Stitch screenshot and HTML, current
  `trends_screen.dart`, trend report providers, CSV copy behavior, and tests.
- Implement Charts mode inside Activity segmented control.
- Use the Stitch hierarchy:
  - Gross spend card
  - Refunds card
  - Net spend card
  - Monthly Net Spend chart card
  - Gross/Refunds/Net monthly table
  - Category Trend card
- Preserve current trend filtering where it still applies.
- Preserve CSV copy behavior unless it no longer has a visible home; if kept,
  expose it as a secondary action, not a primary CTA.
- Remove obsolete standalone Trends route and screen entry points if not already
  removed in M39.
- Update trend tests to open Activity Charts mode.

Expected code shape:

- Charts mode should reuse the same Activity page scaffold and mode control.
- Chart width must be constrained or horizontally scrollable without overflowing
  the page.
- Existing `TrendReport` model and provider contracts should remain unchanged.

Acceptance criteria:

- Activity Charts covers current Trends behavior.
- Existing trend report tests pass after route/copy updates.
- No app code still navigates to `/trends`.
- Chart and table are readable in light and dark mode.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M43 - Transaction Details Surface

Purpose: restyle transaction details as the focused Stitch detail card/sheet.

Instructions:

- Inspect transaction details Stitch screenshot and HTML, current transaction
  detail bottom sheet code, label editor entry, metadata editor entry, and
  tests.
- Use the Stitch hierarchy:
  - close affordance
  - centered merchant/group name
  - date
  - large amount
  - transaction type/status pill
  - detail rows for statement, gross spend, refunds, net expense, source
    amount, category, subcategory, confidence
  - primary Edit action
- Preserve access to metadata editing and label editing.
- Keep sheet width constrained on tablet/desktop and keyboard safe on mobile.
- Do not change transaction model semantics.

Expected code shape:

- Use a shared modal/sheet primitive from M38.
- Detail rows should wrap or align responsively without clipping labels or
  values.
- The surface may stay a bottom sheet on mobile and become a centered modal on
  wider widths if that fits the shared primitive.

Acceptance criteria:

- Transaction details open from Activity List.
- Metadata editor and label editor entry tests pass.
- No overflow at 390px width.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M44 - Transaction Metadata Editor

Purpose: restyle metadata editing as the Stitch modal form while preserving
correction behavior.

Instructions:

- Inspect metadata editor Stitch screenshot and HTML,
  `transaction_metadata_editor.dart`, Review and Activity callers, category
  creation dialog, AI Suggest tests, and metadata correction tests.
- Use the Stitch hierarchy:
  - modal card
  - `Edit metadata` display title
  - outlined merchant group field
  - category and subcategory selectors
  - create category affordance
  - confidence selector
  - notes field
  - explanatory copy
  - Suggest, Cancel, Save actions
- Preserve:
  - merchant group editing
  - category/subcategory selection
  - confidence editing
  - notes editing
  - category creation
  - AI Suggest request and failure handling
  - transaction and review item correction behavior
  - provider invalidation after save
- Make the form keyboard-safe and width-constrained.

Expected code shape:

- Reuse shared modal/form primitives.
- Text fields inside horizontal layouts must be constrained.
- Do not change RPC request shape unless current code already requires it.

Acceptance criteria:

- Metadata editor tests pass from both Activity and Review.
- Suggest failure keeps form values.
- Form renders correctly in light and dark mode.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M45 - Review Screen

Purpose: rebuild Review around the Stitch review queue design.

Instructions:

- Inspect Review Stitch screenshot and HTML,
  `merchant_review_screen.dart`, Gmail parse failure rendering, metadata editor
  integration, and Review tests.
- Use the Stitch hierarchy:
  - large `Review` display title
  - supporting copy
  - Open Reviews metric card
  - Correction Data metric card
  - queue card with warning rail
  - merchant/source/date line
  - amount
  - needs-attention status
  - classification chips
  - confidence chip
  - full-width Resolve action
  - caught-up empty state
- Preserve:
  - Gmail parse failure visibility
  - review queue loading/error states
  - correction flow through metadata editor
  - provider invalidation after save
- Do not change review RPCs or merchant correction semantics.

Expected code shape:

- Review cards should use shared card/chip primitives.
- The queue list should remain performant and avoid nesting unbounded
  scrollables.

Acceptance criteria:

- Review queue and correction tests pass.
- Empty state matches the redesigned surface.
- Cards fit 390px mobile width and wider layouts.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M46 - Vaults Screen

Purpose: restyle Piggy Banks as the visible Vaults destination.

Instructions:

- Inspect Vaults Stitch screenshot and HTML, `piggy_banks_screen.dart`,
  piggy-bank repository contracts, and tests.
- Keep existing data/repository naming unless a small UI-facing rename is
  necessary; visible user-facing destination copy should say Vaults.
- Use the Stitch hierarchy:
  - `Vaults` display title
  - New Vault action
  - Active ledgers card
  - Total balance card
  - selected vault hero card
  - deposit and withdraw actions
  - current balance card
  - target progress card
  - remaining card
  - empty entries card
- Preserve:
  - create/edit vault
  - deposit, withdraw, and adjustment entries
  - no-overdraft validation
  - selected ledger behavior
  - ledger-derived balance/progress reads
- Update tests from visible Piggy Banks copy to Vaults where appropriate.

Expected code shape:

- Public route path may remain `/piggy-banks` only if M39 intentionally kept it
  as an implementation detail; visible navigation and screen copy must be
  Vaults.
- Prefer adaptive stacked cards on mobile and constrained/grid cards on wider
  layouts.

Acceptance criteria:

- Bottom nav label is Vaults.
- Existing piggy-bank behavior tests pass after copy updates.
- Vault detail and actions do not overflow on mobile.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M47 - Settings Focused Screen and Theme Selector

Purpose: rebuild Settings as a focused non-tab page and expose theme selection.

Instructions:

- Inspect Settings Stitch screenshot and HTML, `settings_screen.dart`, auth,
  category manager, label manager, Gmail connector, AI settings, runtime config,
  and Settings tests.
- Use a focused page layout:
  - Back affordance
  - large `Settings` display title
  - Account and Runtime card
  - Theme card or row with System default, Light, Dark
  - Categories card
  - Labels card if present in current code
  - Gmail Importer card
  - AI Core dark feature card
  - System Environment card
- Preserve:
  - sign out
  - category create/rename/delete/merge flows
  - label create/rename/delete flows
  - Gmail connect/disconnect/status flows
  - AI budget/status display
  - environment and Supabase status display
- Wire theme selector to the M37 theme controller.
- Settings must not appear in primary bottom navigation.

Expected code shape:

- Break large settings subsections into smaller widgets if needed; avoid
  expanding the existing monolithic screen further.
- Theme selector uses local state provider from M37, not Supabase.
- Category detail drilldowns route to Activity list mode.

Acceptance criteria:

- Settings is reachable through the global gear and direct `/settings`.
- Theme selector defaults to System default and persists changes.
- Existing Settings tests pass after route/copy updates.
- Dark AI Core card follows DESIGN.md polarity-flipped treatment.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M48 - Sign-In and Household Gate States

Purpose: bring auth entry, loading, and error states into the redesign.

Instructions:

- Inspect `sign_in_screen.dart`, `router.dart` household loading/error widgets,
  auth repository, app bootstrap states, and app smoke tests.
- Restyle sign-in as a DESIGN.md auth card on sage canvas.
- Restyle household loading as a branded card or focused loading state.
- Restyle household error with retry and sign-out actions using shared modal
  primitives.
- Preserve:
  - Supabase readiness messaging
  - Google sign-in behavior
  - route guard behavior
  - retry household load
  - sign out from error state
- Do not change auth repository logic or external setup requirements.

Expected code shape:

- Entry states should use the same token layer as authenticated screens.
- Loading/error states should be responsive and width-constrained.

Acceptance criteria:

- Widget and integration auth smoke tests pass.
- Sign-in, loading, and error states render in light/dark/system modes.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/widget_test.dart integration_test/app_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M49 - Ask / AI Screen

Purpose: redesign the non-primary Ask route consistently with the new system.

Instructions:

- Inspect `ai_screen.dart`, AI repository/provider contracts, Settings AI card,
  and AI tests.
- Keep Ask outside the four primary tabs.
- Restyle Ask using DESIGN.md card/input/action primitives.
- Preserve:
  - prompt input
  - backend-mediated expense Q&A
  - AI budget status
  - loading/error/result states
  - provider invalidation after calls
- Do not change Edge Function behavior or AI budget semantics.

Expected code shape:

- Ask should be reachable by existing non-primary route or action path.
- The screen should be responsive and dark-theme safe.

Acceptance criteria:

- Existing AI tests pass.
- Ask input/result states are readable in light and dark mode.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test test/finance_features_test.dart
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M50 - Dialogs, Forms, Empty States, and Motion Pass

Purpose: normalize remaining shared surfaces after the main screen redesigns.

Instructions:

- Inspect all remaining dialogs, sheets, snackbars, empty states, delete/merge
  confirmations, cap form, category creation, label dialogs, piggy-bank dialogs,
  and transaction label editor.
- Restyle remaining surfaces using shared modal/card/form primitives.
- Add purposeful low-cost motion:
  - segmented control state transitions
  - card entrance fade/slide where appropriate
  - button press scale where appropriate
  - loading state transitions
- Respect accessible navigation and avoid expensive chart/list animations.
- Add or update semantic labels and tooltips for icon-only actions.
- Fix any layout issues discovered during prior milestones.
- Do not introduce new product behavior in this pass.

Expected code shape:

- Shared primitives should remove duplicated dialog chrome.
- Remaining legacy 8px card/dialog chrome should be retired from core flows.

Acceptance criteria:

- Core dialogs/sheets/forms visually match the redesign.
- Important icon-only actions have tooltips or semantics.
- No known overflow/unbounded-layout issues remain in redesigned flows.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M51 - Final Regression, Responsive QA, and Docs Closeout

Purpose: verify the full redesign and document the final UI state.

Instructions:

- Run full Flutter verification.
- Perform responsive QA at representative widths:
  - 390px mobile
  - 768px tablet
  - 1024px desktop/large window
- Verify light, dark, and system theme mode across:
  Dashboard, Activity List, Activity Charts, Review, Vaults, Settings,
  transaction details, metadata editor, sign-in, household states, and Ask.
- Update durable docs with final UI behavior:
  - `README.md`
  - `MILESTONES.md`
  - `SESSION_HANDOFF.md`
  - this plan if implementation details materially changed
- Confirm deferred scope remains documented.
- Do not start push notification, iOS, or web work.

Expected code shape:

- Final milestone should be mostly verification, small fixes, and docs.
- Any functional regression found here should be fixed only if it belongs to
  the UI redesign sequence; otherwise document and ask before expanding scope.

Acceptance criteria:

- `flutter analyze` passes.
- `flutter test` passes.
- New navigation, Activity consolidation, Vaults naming, Settings focus mode,
  and theme behavior are documented.
- Milestones 18-21 remain deferred.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## Deferred Scope

- Push notification implementation in M18-M21.
- iOS app work.
- Web interface work.
- Supabase-hosted rollout or production deployment.
- Renaming database tables, RPCs, or repository models from piggy-bank wording
  to vault wording.
- New finance calculations or monthly-cap semantics.
- New AI capabilities beyond visual redesign of existing Ask and AI status
  surfaces.
