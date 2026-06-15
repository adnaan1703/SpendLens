# Merchant Group Management Plan

Last updated: 2026-06-15

This document is the completed-only implementation plan for Settings merchant
group management. Milestones 61-64 are complete. Each milestone below was a
standalone milestone intended to be executed in a separate Codex thread. Stop
after completing and documenting the current milestone; do not automatically
continue to the next milestone.

## Target Behavior

SpendLens should expose a Settings merchant group management section beside the
existing Categories and Labels sections.

- Household writers can rename an existing canonical merchant group.
- Renaming updates `merchants.display_name` globally while preserving the
  merchant id and all linked aliases, mapping rules, transactions, review
  suggestions, and summaries.
- Household writers can merge one or more source merchant groups into a
  surviving destination merchant group.
- Merging moves linked aliases, mapping rules, transaction `merchant_id`
  references, and open review suggested merchant references to the destination
  merchant.
- During merge, the user chooses the category strategy:
  - Preserve categories: keep existing transaction, mapping-rule, and review
    category/subcategory fields unchanged.
  - Destination category: apply the destination merchant category/subcategory to
    moved source transactions, active mapping rules, and open review
    suggestions.
- Dashboard, Activity, Review, Trends/Activity Charts, and merchant
  autocomplete should refresh to the canonical merged/renamed merchant groups.

## Existing Foundation

- `public.merchants` is the household-scoped canonical merchant group table.
- `public.merchant_aliases` stores normalized statement merchant aliases that
  point to canonical merchants.
- `public.merchant_mapping_rules` stores past/future classification rules and
  can point to merchants plus category/subcategory.
- `public.transactions.merchant_id` points to canonical merchants while
  `statement_merchant` and `normalized_statement_merchant` preserve source
  statement text.
- `public.review_items.suggested_merchant_id` may point to a merchant for open
  Review rows.
- `public.apply_transaction_metadata_correction(...)` already creates/reuses a
  merchant, exact alias, and exact future mapping rule for one normalized
  statement merchant.
- `apps/mobile/lib/src/data/repositories/finance_repository.dart` already has
  `MerchantOption`, `merchantOptionsProvider`, `fetchMerchants(...)`,
  `TransactionQuery.merchantId`, and merchant autocomplete support.
- `apps/mobile/lib/src/features/settings/settings_screen.dart` already has
  collapsible Settings cards for Categories and Labels, including usage rows,
  rename dialogs, merge dialogs, provider refreshes, and narrow-layout tests.
- `apps/mobile/test/finance_features_test.dart` has the existing fake
  repository and focused Settings/category/label/merchant tests.

## Global Rules For M61-M64

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Treat `public.merchants` as the merchant group source of truth. Do not add a
  new merchant-group table.
- Keep merchant aliases as backend ingestion memory. Do not add alias editing,
  raw statement merchant editing, or statement-merchant-level reassignment in
  this sequence.
- Do not delete transactions during merchant rename or merge.
- Keep all writes household-scoped, RLS-safe, and app-facing through
  `security invoker` RPCs.
- Use `supabase migration new <name>` for new migrations. Do not invent
  migration filenames by hand.
- Provider refreshes after rename/merge must cover merchant manager data,
  merchant options, transactions, trend reports, dashboard snapshots, and the
  Review queue.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M61 - Merchant Group Management Planning and Reference Readiness

Status: Completed on 2026-06-15.

Purpose: Create the companion plan and wire the new M62-M64 implementation
sequence into durable planning docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `DATA_MODEL.md`, `MILESTONES.md`, and
  `SESSION_HANDOFF.md` so a fresh session can start M62 from docs alone.
- Preserve M18-M21 push-notification deferral.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, or web implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `MERCHANT_GROUP_MANAGEMENT.md` describes M61-M64 as serial standalone
  milestones.
- M62 is the next recommended non-deferred implementation milestone.
- The docs state that implementation remains planned only.

Verification:

```bash
rg -n "MERCHANT_GROUP_MANAGEMENT|Milestone 6[1-4]|Merchant Group Management|merchant group management" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the merchant group management companion plan and routed future
  implementation through M62-M64.
- Decided this needs multiple milestones because it changes persisted merchant
  contracts, repository APIs, Settings UI, dashboard grouping, provider
  refreshes, and regression docs.
- Implementation remains planned only; M62 was not started.
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

## M62 - Merchant Group Data and Repository Contract

Status: Completed on 2026-06-15.

Purpose: Add the RLS-safe Supabase and Flutter repository contract needed for
merchant group rename and merge before building the Settings UI.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `MILESTONES.md`, `SESSION_HANDOFF.md`, `finance_repository.dart`, current
  merchant migrations, and merchant/category/label pgTAP tests.
- Use the Supabase skill for this milestone. Check `supabase --help`,
  relevant command help, Supabase changelog/docs, and create the migration with
  `supabase migration new merchant_group_management`.
- Add `public.v_merchant_group_usage` as a `security_invoker` read view for
  Settings. It should include merchant id/name, category/subcategory ids and
  names, transaction count, net spend, alias count, active mapping-rule count,
  open review suggestion count, and last transaction date.
- Add `public.rename_household_merchant(...)`:
  - Requires signed-in household writer access.
  - Trims and validates non-empty display names.
  - Rejects case-insensitive duplicate destination names in the same household.
  - Updates only `merchants.display_name` and returns the renamed merchant.
- Add `public.merge_household_merchants(...)`:
  - Requires signed-in household writer access.
  - Requires one destination merchant and at least one source merchant, all in
    the same household.
  - Rejects duplicate or missing ids and rejects source ids that include the
    destination.
  - Accepts `p_category_strategy` with exactly `preserve` or `destination`.
  - Saves the final destination display name using the same duplicate
    validation as rename.
  - Repoints source `merchant_aliases`, `merchant_mapping_rules`,
    `transactions.merchant_id`, and `review_items.suggested_merchant_id` to
    the destination merchant.
  - Deletes source merchant rows after references are moved.
  - For `preserve`, leave category/subcategory fields unchanged.
  - For `destination`, require destination category/subcategory, apply them to
    moved source transactions, active mapping rules, and open review
    suggestions, and stamp transaction classification audit fields.
  - Return counts for moved transactions, aliases, mapping rules, review
    suggestions, deleted source merchants, and category-updated rows.
- Add pgTAP coverage in `supabase/tests/merchant_group_management.sql` for
  rename, duplicate/blank rejection, merge preserve, merge destination,
  household isolation, and viewer/non-member denial.
- Extend `FinanceRepository` and `SupabaseFinanceRepository` with merchant
  group manager snapshot, rename, and merge methods plus request/result models.
- Add `merchantGroupManagerSnapshotProvider`.
- Update dashboard top merchant aggregation in the repository so canonical
  `merchant_id`/display names are grouped when available instead of raw
  statement merchant strings.
- Add focused repository/fake tests for the new models, RPC parameters, result
  parsing, and canonical dashboard merchant grouping.
- Do not build the Settings merchant group card in this milestone.
- Do not add alias editing, merchant deletion, import changes, Edge Function
  changes, hosted rollout, iOS, web, or push notification work.

Expected code shape:

- New app-facing writes go through RPCs rather than direct client updates.
- The Flutter repository mirrors existing category/label manager patterns:
  snapshot provider, request/result value objects, fake repository hooks, and
  explicit provider invalidation left for the UI milestone.
- Merge category strategy is represented by a small Dart enum/string mapper,
  with only `preserve` and `destination` accepted.

Acceptance criteria:

- Database tests prove merchant rename and merge are household-scoped,
  duplicate-safe, role-safe, and preserve or apply taxonomy according to the
  selected strategy.
- Repository tests prove Flutter can fetch merchant group usage, call rename,
  call merge, parse counts, and group dashboard top merchants canonically.
- Existing merchant autocomplete and transaction metadata correction behavior
  still works.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/merchant_group_management.sql
supabase test db --local supabase/tests/merchant_review_corrections.sql
supabase test db --local supabase/tests/transaction_metadata_editing.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|dashboard|repository"
cd apps/mobile && flutter analyze
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added `public.v_merchant_group_usage` as a security-invoker Settings usage
  view with transaction, net spend, alias, active-rule, open-review, category,
  subcategory, and last-transaction fields.
- Added RLS-safe app-facing `rename_household_merchant(...)` and
  `merge_household_merchants(...)` RPCs for household writers. Merge supports
  Preserve categories and Destination category strategies, moves source
  aliases/rules/transactions/open review suggestions to the destination, and
  deletes source merchant rows after references move.
- Extended the Flutter finance repository with merchant group manager snapshot,
  rename, merge request/result models, fake repository hooks, and canonical
  dashboard top-merchant grouping by `merchant_id` when available.
- Added focused pgTAP and Flutter coverage for rename, duplicate/blank
  rejection, merge preserve, merge destination, isolation/role denial, result
  parsing, request capture, and canonical dashboard grouping.
- Milestones 18-21 remain deferred by user request, and M63 Settings UI work
  was not started.
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
  - Destination-strategy merge requires the surviving destination merchant to
    have both category and subcategory values before applying taxonomy to moved
    source references.
  - Direct merchant deletion remains out of scope; the source-merchant delete
    path is only opened during the merge RPC via a transaction-local RLS guard.
  - Closed historical review suggestions that reference deleted source
    merchants may follow existing foreign-key `on delete set null` behavior;
    M62 explicitly moves open review suggestions.
  - Hosted Supabase migration push is outside this local milestone.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` data was extended with merchant-group
    snapshot, rename, merge, alias-count, and canonical dashboard grouping
    hooks.

## M63 - Settings Merchant Group Manager UX

Status: Completed on 2026-06-15.

Purpose: Add the visible Settings management section for renaming and merging
merchant groups using the M62 repository contract.

Instructions:

- Before editing, inspect M62 completion notes, `settings_screen.dart`,
  `finance_repository.dart`, existing Settings category/label manager widgets,
  `app_primitives.dart`, and the relevant Settings tests.
- Add a collapsible `Merchant groups` card in Settings after Categories and
  before Labels.
- The card should load `merchantGroupManagerSnapshotProvider(householdId)`.
- Render each merchant group row with canonical name, optional
  category/subcategory, transaction count/net spend, alias/rule/review impact,
  and icon actions for rename.
- Add a Refresh icon that invalidates merchant group lookups.
- Add a Merge action that is disabled until at least two merchant groups exist.
- Add a compact rename dialog using the same modal/action style as the label
  rename flow. Save through `renameMerchantGroup`.
- Add a merge dialog using the same modal density and validation style as the
  category merge flow:
  - Choose destination merchant.
  - Edit surviving destination name.
  - Select one or more source merchants.
  - Show aggregate impact chips for selected source transactions, net spend,
    aliases, active rules, and open review suggestions.
  - Let the user choose Preserve categories or Destination category.
  - Default to Preserve categories.
  - Disable Destination category when the destination merchant lacks
    category/subcategory values.
  - Disable Save until destination, source selection, name, and strategy are
    valid.
- After successful rename or merge, invalidate merchant group manager,
  merchant options, transactions, trend reports, dashboard snapshots, and
  merchant review queue providers.
- Add snackbars with concise success counts.
- Add focused widget tests for rendering, rename save, merge validation,
  preserve strategy submission, destination strategy disabling, provider refresh
  effects through the fake repository, and narrow viewport layout.
- Do not add alias editing, merchant deletion, mapping-level reassignment,
  hosted rollout, iOS, web, or push notification work.

Expected code shape:

- Reuse existing Settings primitives and local helper patterns instead of adding
  a new route.
- Keep rows compact and responsive; long merchant names must ellipsize or wrap
  without overflow.
- Use icon buttons/tooltips for refresh, rename, and merge actions.

Acceptance criteria:

- Settings exposes a Merchant groups section beside Categories and Labels.
- A household writer can rename a merchant group from Settings.
- A household writer can merge multiple source merchant groups into one
  destination with an explicit category strategy.
- Empty, loading, error, narrow, and long-name states remain usable.
- Dashboard, Activity, Review, chart/report, and autocomplete data refresh
  after saves.

Verification:

```bash
cd apps/mobile && flutter test test/finance_features_test.dart --name "Settings|merchant group|merchant|dashboard|narrow"
cd apps/mobile && flutter analyze
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added a collapsible Settings `Merchant groups` card after Categories and
  before Labels. The card reads `merchantGroupManagerSnapshotProvider`, renders
  canonical merchant names, taxonomy context, transaction/net-spend usage, alias
  counts, active-rule counts, and open-review counts, and exposes refresh,
  rename, and merge actions through icon/tool controls.
- Added a compact merchant-group rename dialog backed by `renameMerchantGroup`.
- Added a merge dialog backed by `mergeMerchantGroups` with destination
  selection, surviving name editing, multi-source selection, aggregate source
  impact chips, explicit Preserve categories vs Destination category strategy,
  Destination category disabling when the destination lacks taxonomy, validation,
  and concise success snackbars.
- Rename and merge saves invalidate merchant group manager data, merchant
  options, transactions, trend reports, Dashboard snapshots, and Review queue
  providers.
- Added focused widget coverage for rendering, rename save, merge validation,
  preserve-strategy submission, destination-strategy disabling, provider refresh
  effects, and narrow/long-name layout behavior.
- Milestones 18-21 remain deferred by user request, and Milestone 64 regression
  and docs cleanup was not started.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Settings|merchant group|merchant|dashboard|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `git diff --check`
- Assumptions made:
  - The existing M62 repository/provider contract is the source of truth for
    merchant group writes; no new Supabase migration or repository method was
    needed.
  - Destination category remains unavailable when the destination merchant lacks
    both category and subcategory values.
  - Merchant alias editing, statement-merchant reassignment, merchant deletion,
    hosted rollout, iOS, web, and push notifications remain out of scope.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` data and M62 merchant-group hooks, extended
    with a merchant-options fetch counter, provider refresh probe, and long-name
    merchant fixture for M63 widget coverage.

## M64 - Merchant Group Management Regression, Docs, and Cleanup

Status: Completed on 2026-06-15.

Purpose: Verify the full merchant group workflow and fold final behavior into
durable docs.

Instructions:

- Run focused and full local regression for merchant group rename, merge
  preserve, merge destination, merchant autocomplete, metadata editor exact
  canonicalization, Activity filtering, Dashboard merchant grouping, Review,
  Trends/Activity Charts, and Settings narrow layout.
- Confirm no stale direct client writes bypass the new RPCs.
- Confirm docs describe final behavior and deferred scope.
- Update this plan with completion summaries for M62-M64.
- Update `README.md`, `DATA_MODEL.md`, `MILESTONES.md`, and
  `SESSION_HANDOFF.md` with final implemented behavior, next recommended
  milestone, known gaps, and verification.
- If implementation reveals a schema or UI decision not captured here, document
  it explicitly in the completion summary.
- Do not remove completed-only companion plans unless the user explicitly asks
  for cleanup.
- Do not run hosted migration pushes or Edge Function deployments unless the
  user explicitly asks for hosted rollout.

Expected code shape:

- This should mostly be test/docs cleanup. Only make code changes when
  regression finds a concrete issue in the M62-M63 implementation.

Acceptance criteria:

- Full Supabase and Flutter verification passes locally or any environment
  limitation is documented.
- Durable docs explain merchant group rename/merge behavior, category strategy,
  provider refresh expectations, and deferred items.
- The companion plan is marked completed-only after M64 is complete.
- M18-M21 remain deferred unless explicitly resumed.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/merchant_group_management.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|Review|Settings|dashboard|narrow"
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Verified the full merchant group workflow across the local Supabase schema,
  focused merchant-group pgTAP coverage, full pgTAP coverage, schema lint,
  focused Flutter coverage for merchant, metadata, Activity, Review, Settings,
  Dashboard, and narrow-layout paths, Flutter analysis, and the full Flutter
  test suite.
- Confirmed Settings merchant group rename and merge use the
  `rename_household_merchant(...)` and `merge_household_merchants(...)` RPCs;
  no stale direct client writes bypass the Settings manager contract.
- Folded final merchant group rename/merge behavior, category strategy,
  provider refresh expectations, deferred scope, and verification results into
  durable docs and marked this companion plan completed-only.
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
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant group, merchant option,
    metadata correction, Activity query, Dashboard summary, Review queue, and
    provider refresh test hooks.
