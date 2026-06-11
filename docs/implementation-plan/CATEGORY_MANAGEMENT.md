# Category Management Plan

Last updated: 2026-06-11

This document is the implementation plan for full category management in
SpendLens. Each milestone below is a standalone milestone intended to be
executed in a separate Codex thread. Stop after completing and documenting the
current milestone; do not automatically continue to the next milestone.

## Target Behavior

SpendLens should let household writers manage the household taxonomy from
Settings without using privileged client credentials. The category manager
should support:

- Viewing categories with subcategories grouped below each category.
- Viewing usage summaries and recent transactions for a selected category or
  subcategory.
- Renaming categories and subcategories.
- Adding more subcategories to an existing category.
- Deleting categories or subcategories without deleting transactions.
- Merging categories after explicitly mapping source subcategories into the
  surviving category.

Renames and additions should preserve existing category/subcategory IDs where
possible so transactions, caps, merchants, mapping rules, review rows, and
reports naturally show the updated wording. Destructive taxonomy actions must
be explicit, confirmed, and reversible through the existing merchant review
workflow where practical.

When a category is deleted, affected transactions must be unclassified and sent
back to Review so the user can choose the correct category/subcategory and
persist the future mapping through the existing correction flow. When
categories are merged, the merge is treated as a deliberate migration, so
affected rows move to the surviving category instead of going to Review.

## Existing Foundation

- Settings already has a Categories card in
  `apps/mobile/lib/src/features/settings/settings_screen.dart`.
- In-app category creation already uses
  `apps/mobile/lib/src/features/categories/category_creation_dialog.dart` and
  the RLS-safe `public.create_household_category(...)` RPC.
- Flutter finance data flows through
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`, with
  Riverpod providers for categories, subcategories, transactions, dashboard,
  trends, and merchant review.
- `public.categories` and `public.subcategories` are household-owned tables with
  RLS policies for member reads and writer inserts/updates.
- Transactions, merchants, merchant mapping rules, category caps, review items,
  and summary views reference category/subcategory IDs.
- `public.v_category_monthly_spend`, `public.v_budget_progress`,
  `public.v_merchant_summary`, and `public.v_review_queue` already join IDs to
  category/subcategory names.
- Merchant review and transaction metadata editing already persist manual
  corrections through `public.apply_transaction_metadata_correction(...)`,
  update matching historical transactions, and create/update future exact
  mapping rules.
- The repo standard verification path is local Supabase reset/tests/lint,
  local advisors with `--fail-on none`, Flutter analyze, Flutter tests, and a
  debug Android build when UI behavior changes.

## Global Rules For M22-M25

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, or prepare later milestones unless the user
  explicitly asks to proceed.
- Preserve Android-first scope. Do not add iOS or web category-management work
  in this sequence.
- Keep all taxonomy management household-scoped and RLS-safe. Use authenticated
  app-facing `security invoker` RPCs for mutations.
- Do not use service-role credentials, Edge Functions, or privileged Flutter
  client code for category management.
- Create migrations with `supabase migration new <descriptive_name>` when
  implementation starts. Do not invent migration filenames.
- Keep existing transaction money semantics unchanged: `net_expense` is spend,
  refunds reduce spend, and card bill payments do not count as spend.
- Deleting taxonomy rows must never delete transactions or source metadata.
- Category deletion must move affected transactions back to Review by
  unclassifying them and opening review items.
- Category merge must use an explicit subcategory mapping before saving.
  Source subcategories cannot be implicitly dropped.
- Deactivate or repoint future mapping rules intentionally during destructive
  operations. Do not leave active rules pointing at deleted taxonomy.
- Add focused pgTAP and Flutter tests in the same milestone as the behavior
  change.
- At completion, update `SESSION_HANDOFF.md` and include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M22 - Category Manager Foundation And Usage Preview

Purpose: Turn the Settings category card into a real management surface with
safe preview data before introducing destructive operations.

Instructions:

- Start by reading:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `apps/mobile/lib/src/features/settings/settings_screen.dart`
  - `apps/mobile/lib/src/features/categories/category_creation_dialog.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/test/finance_features_test.dart`
  - `supabase/migrations/20260608173706_create_household_category_rpc.sql`
  - `supabase/tests/category_creation.sql`
- Replace the compact Settings category list with a category manager surface
  that keeps the existing grouped visual model:
  - Category rows remain visually grouped with their subcategories.
  - Each row has compact icon actions, including a pencil edit action.
  - Selecting a category opens or expands detail with usage summary and recent
    transactions.
- Add read support for category-management previews:
  - Category and subcategory transaction counts.
  - Category and subcategory net spend.
  - Recent transactions for a selected category or subcategory.
  - Enough merchant/date/amount/category context for the user to understand
    what would be affected by later delete or merge actions.
- Prefer reusing existing transaction query models and repository helpers where
  practical. Add a dedicated preview method only if it keeps Settings simpler.
- Add non-destructive taxonomy editing:
  - Rename the selected category.
  - Rename existing subcategories under the selected category.
  - Add one or more new subcategories under the selected category.
- Implement the save through a single app-facing RPC, for example
  `public.update_household_category_taxonomy(...)`, that:
  - Requires a signed-in profile.
  - Requires household write access.
  - Validates category and existing subcategory ownership.
  - Trims category and subcategory names.
  - Rejects blank names.
  - Rejects case-insensitive duplicate category names within the household.
  - Rejects case-insensitive duplicate subcategory names within the category.
  - Updates existing category/subcategory rows in place.
  - Inserts only genuinely new subcategory rows under the selected category.
  - Returns the edited category and complete ordered subcategory list.
- Refresh category, subcategory, dashboard, transaction, trend, and merchant
  review providers after save so visible labels update across app surfaces.
- Do not implement delete, merge, moving subcategories between categories, or
  reorder controls in this milestone.

Expected code shape:

- Keep the category manager in the existing Settings feature unless the widget
  becomes large enough to justify a small local helper file under
  `apps/mobile/lib/src/features/categories`.
- Keep mutation validation centralized in the RPC rather than only in Flutter.
- Existing transaction/category IDs should remain stable for rename and add.

Acceptance criteria:

- A household owner/admin/member can open a category detail from Settings and
  see usage counts, net spend, and recent associated transactions.
- A household writer can rename a category and existing subcategories.
- A household writer can add new subcategories to an existing category.
- Renamed labels appear in Settings and existing transaction/report surfaces
  after provider refresh without creating duplicate category rows.
- Viewers and non-members cannot mutate taxonomy.
- Delete and merge controls are not active yet.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/categories/category_creation_dialog.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M23 - Taxonomy Delete And Review Requeue

Purpose: Allow category and subcategory deletion while protecting transactions
and routing affected rows through the existing review workflow.

Instructions:

- Start by reading the M22 implementation notes and all files listed in M22,
  plus:
  - `supabase/migrations/20260605111702_merchant_review_corrections.sql`
  - `supabase/migrations/20260608195329_transaction_metadata_editing.sql`
  - `supabase/tests/merchant_review_corrections.sql`
  - `supabase/tests/transaction_metadata_editing.sql`
  - `apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart`
- Add delete affordances to the category manager:
  - Delete subcategory from the selected category detail.
  - Delete category from the selected category detail.
  - Use icon actions plus confirmation dialogs.
  - Show affected transaction counts, active mapping-rule counts, cap counts,
    and recent transaction examples before confirming.
- Implement deletion with app-facing RPCs, for example:
  - `public.delete_household_subcategory(...)`
  - `public.delete_household_category(...)`
- Subcategory deletion must:
  - Require signed-in household write access.
  - Validate the subcategory belongs to the selected household/category.
  - Clear `subcategory_id` on affected transactions, merchants, mapping rules,
    and review suggestions.
  - Open or update review items for affected transactions so they return to the
    Review tab for subcategory reassignment.
  - Preserve `category_id` on transactions unless the whole category is deleted.
  - Mark classification metadata with the acting profile, timestamp, and a
    short note explaining that the subcategory was deleted.
  - Delete the subcategory row only after references are cleared.
- Category deletion must:
  - Require signed-in household write access.
  - Validate category ownership.
  - Clear `category_id`, `subcategory_id`, and `classification_rule_id` on
    affected transactions where those references point at deleted taxonomy.
  - Preserve transaction `merchant_id` and statement merchant fields so Review
    keeps useful merchant context.
  - Open or update review items for every affected transaction with a
    taxonomy-deleted reason.
  - Deactivate active mapping rules that referenced the deleted category or its
    subcategories by setting `apply_to_future = false` and adding/updating notes.
  - Clear category/subcategory references on merchants and review suggestions
    that pointed at deleted taxonomy.
  - Delete category caps for the deleted category.
  - Delete the category row only after dependent references are handled.
- Use the existing open-review uniqueness boundary where practical:
  `(household_id, transaction_id, reason)` for open review items.
- After deletion, refresh Settings category manager data, category/subcategory
  lookups, dashboard, transactions, trends, and merchant review queue providers.
- Do not implement category merge in this milestone.

Expected code shape:

- Deletion is transactional inside the RPC. A failed validation must leave all
  taxonomy and transaction rows unchanged.
- Transactions are never deleted.
- The existing Review screen remains the place where users reclassify affected
  transactions and persist future mapping rules.

Acceptance criteria:

- A household writer can delete an unused subcategory.
- A household writer can delete a used subcategory, and affected transactions
  appear in Review while preserving the parent category.
- A household writer can delete a used category, and affected transactions are
  unclassified and appear in Review.
- Future mapping rules no longer point at deleted taxonomy.
- Monthly caps for deleted categories are removed.
- Viewers and non-members cannot delete taxonomy.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M24 - Category Merge With Explicit Subcategory Mapping

Purpose: Merge categories without losing transaction history or leaving source
subcategories ambiguous.

Instructions:

- Start by reading the M22 and M23 implementation notes and all files listed in
  those milestones.
- Add a merge flow to the category manager:
  - User chooses one destination category that survives.
  - User chooses one or more source categories to merge into it.
  - User may edit the surviving category name before saving.
  - The flow displays affected transaction counts, net spend, caps, mapping
    rules, and recent transaction examples.
- Use the selected merge policy: every source subcategory must be mapped before
  merge.
  - Each source subcategory maps to either an existing destination subcategory
    or a new destination subcategory name.
  - The Save action remains disabled until all source subcategories are mapped.
  - Duplicate destination subcategory names are rejected case-insensitively.
- Implement merge through one app-facing RPC, for example
  `public.merge_household_categories(...)`, that:
  - Requires a signed-in profile.
  - Requires household write access.
  - Validates destination category ownership.
  - Validates each source category belongs to the same household and is not the
    destination category.
  - Validates every source subcategory has exactly one destination mapping.
  - Creates requested destination subcategories before moving references.
  - Repoints transactions, merchants, mapping rules, and review suggestions from
    source category/subcategory IDs to the destination IDs.
  - Repoints active future mapping rules instead of disabling them.
  - Updates classification metadata on affected transactions with acting
    profile, timestamp, and merge note.
  - Merges category caps by summing same-month source cap amounts into the
    destination category cap, creating missing destination cap rows as needed.
  - Deletes merged-away source category/subcategory rows only after all
    references are moved.
  - Returns changed counts for transactions, merchants, mapping rules, review
    suggestions, caps, created subcategories, and deleted taxonomy rows.
- Merge should not create review items. The user has deliberately chosen the
  destination mappings during merge.
- After merge, refresh Settings category manager data, category/subcategory
  lookups, dashboard, transactions, trends, merchant review queue, and monthly
  cap/dashboard providers.

Expected code shape:

- The merge RPC is atomic and validates all mappings before making changes.
- Destination category ID survives; source category IDs are retired.
- Existing transaction rows remain intact and keep their source metadata.

Acceptance criteria:

- A household writer can merge two or more categories into a surviving category.
- The merge dialog requires every source subcategory to be mapped.
- Existing and newly named destination subcategories both work as merge targets.
- Transactions, merchants, mapping rules, review suggestions, and caps point to
  surviving taxonomy after merge.
- Category caps for matching months are summed.
- No review items are created for a successful merge.
- Viewers and non-members cannot merge taxonomy.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M25 - Category Management Regression, Docs, And Cleanup

Purpose: Harden the full category management workflow, document the final
behavior, and verify cross-feature consistency.

Instructions:

- Start by reading M22-M24 completion notes, this plan, and the current
  `SESSION_HANDOFF.md`.
- Review the full category manager UX for:
  - Empty states.
  - Loading states.
  - Error states.
  - Confirmation-copy clarity for delete and merge.
  - Mobile viewport fit.
  - Disabled states during saves.
  - Provider refresh behavior after each mutation.
- Add "View transactions" navigation from category detail where appropriate:
  - Category detail should open Transactions with the category filter applied.
  - Subcategory detail may open category-filtered Transactions and keep
    subcategory context in the originating Settings detail unless a
    subcategory-specific transaction filter has already been implemented.
- Confirm destructive operations do not break:
  - Dashboard category summaries.
  - Monthly caps.
  - Transactions filters.
  - Trends category tables.
  - Merchant review queue.
  - Transaction metadata editor category/subcategory selectors.
  - Workbook importer validation.
  - Gmail ingestion future mapping behavior.
- Update durable docs:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/DATA_MODEL.md` if final behavior introduces data
    model rules not already documented there.
  - `docs/implementation-plan/WORKBOOK_IMPORT.md` only if importer behavior or
    validation commands changed.
  - `docs/implementation-plan/SESSION_HANDOFF.md`.
- Remove stale TODOs, duplicated helper code, and dead models created during
  M22-M24.
- Do not add new taxonomy capabilities in this milestone. Defer reorder,
  cross-household templates, category icons/colors, and bulk AI recategorization
  unless the user explicitly asks.

Expected code shape:

- M25 should mostly be tests, documentation, and small polish fixes. Any major
  new schema/RPC behavior found necessary here should be called out as a scope
  change before implementation.

Acceptance criteria:

- The full category management sequence is documented and consistently reflected
  in the handoff.
- Core finance and review surfaces still behave correctly after rename, add,
  delete, and merge.
- Settings category management has usable loading, empty, error, confirm, and
  success states.
- No stale active mapping rule references deleted taxonomy after the regression
  suite.
- Deferred category features are explicitly named rather than hidden as vague
  future work.

Verification:

```bash
supabase db reset --local
pnpm --dir tools/workbook-import install --frozen-lockfile
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd apps/mobile && dart format lib/src/data/repositories/finance_repository.dart lib/src/features/settings/settings_screen.dart lib/src/features/categories/category_creation_dialog.dart lib/src/features/merchant_review/merchant_review_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/transaction_metadata/transaction_metadata_editor.dart test/finance_features_test.dart
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
