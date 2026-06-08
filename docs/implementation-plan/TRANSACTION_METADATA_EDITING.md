# Transaction Metadata Editing Plan

Last updated: 2026-06-09

This document is the implementation plan for Milestone 15, Transaction Metadata
Editing. It is intended for execution in a separate fresh Codex thread. Stop
after completing and documenting Milestone 15; do not automatically continue to
another milestone.

## Target Behavior

SpendLens users can edit transaction classification metadata from both places
where they already inspect uncertain or detailed transactions:

- The Review tab lets the user edit the current/suggested merchant metadata and
  resolve the review item on save.
- The Transactions tab detail bottom sheet has an Edit action that opens the
  same metadata editor.
- Editable fields are merchant group/readable merchant name, category,
  subcategory, confidence, and optional notes.
- Saving a metadata edit applies to every transaction in the same household that
  matches the edited transaction's normalized statement merchant, not only the
  selected row.
- Saving creates or updates the durable exact merchant mapping rule, merchant
  alias, and canonical merchant record so future workbook/Gmail/UPI ingestions
  for the same normalized merchant use the new merchant/category/subcategory and
  confidence.
- Review saves resolve matching open review items immediately.

Important scope nuance: the apply scope is the normalized statement merchant and
its exact mapping rule. It is not every alias under a broader merchant group
unless those aliases share the same normalized rule. The UI should make this
clear with concise copy such as "Applies to matching statement merchant and
future imports."

## Existing Foundation

- `public.transactions` already stores `merchant_id`, `category_id`,
  `subcategory_id`, `confidence`, `notes`, `normalized_statement_merchant`, and
  classification audit fields.
- `public.merchant_mapping_rules`, `public.merchant_aliases`, and
  `public.merchants` already support durable manual exact-match corrections.
- `public.apply_merchant_review_correction(...)` already resolves review items,
  creates/updates an exact manual mapping rule, updates matching historical
  transactions, and applies the rule to future imports.
- `public.v_review_queue` already exposes current/suggested merchant, category,
  subcategory, and confidence context for the Review tab.
- Flutter has a shared repository in
  `apps/mobile/lib/src/data/repositories/finance_repository.dart`, a Review tab
  in `apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart`,
  a Transactions detail bottom sheet in
  `apps/mobile/lib/src/features/transactions/transactions_screen.dart`, and
  shared inline category creation in
  `apps/mobile/lib/src/features/categories/category_creation_dialog.dart`.
- Existing local verification uses Supabase pgTAP tests plus Flutter widget
  tests in `apps/mobile/test/finance_features_test.dart`.

## Global Rules For M15

- Implement only Milestone 15. Do not begin iOS, web, category taxonomy admin,
  amount/date editing, source-account editing, raw statement merchant editing,
  source fingerprint editing, or unrelated cleanup.
- Keep all finance writes scoped to `household_id`.
- Use Supabase Auth, RLS, and `security invoker` Postgres RPCs. Do not add
  service-role credentials or a new Edge Function for this client workflow.
- Use the existing exact normalized merchant matching model unless the user
  explicitly asks for merchant-group-wide alias merging.
- Preserve money semantics: do not edit `amount`, `gross_spend`,
  `refund_amount`, `net_expense`, `transaction_type`, or source metadata in this
  milestone.
- Preserve import idempotency and raw-email retention rules.
- Update `docs/implementation-plan/MILESTONES.md`,
  `docs/implementation-plan/DATA_MODEL.md` if the data contract changes, and
  `docs/implementation-plan/SESSION_HANDOFF.md` when the milestone starts and
  completes.
- Completion summaries must include:
  - Assumptions made
  - Mocks created
  - Mocks used
  Use `None` for empty categories.

## M15 - Transaction Metadata Editing

Purpose: allow household writers to correct merchant/category metadata from
Review and Transactions while keeping historical and future ingestion behavior
consistent.

Instructions:

- Before editing, inspect:
  - `supabase/migrations/20260605111702_merchant_review_corrections.sql`
  - `supabase/tests/merchant_review_corrections.sql`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/test/finance_features_test.dart`
- Add a new migration using the Supabase CLI, for example
  `supabase migration new transaction_metadata_editing`, rather than inventing a
  timestamped filename manually.
- Add `public.apply_transaction_metadata_correction(...)` as a
  `security invoker` RPC with an empty `search_path`. Parameters should include:
  - `p_household_id uuid`
  - `p_transaction_id uuid`
  - `p_review_item_id uuid default null`
  - `p_merchant_group text`
  - `p_category_id uuid`
  - `p_subcategory_id uuid`
  - `p_confidence public.confidence default 'manual'`
  - `p_notes text default null`
- The RPC must:
  - Require `app_private.current_profile_id()`.
  - Require `p_household_id in (select app_private.write_household_ids())`.
  - Load and lock the selected transaction in the household.
  - If `p_review_item_id` is provided, require it to be an open review item for
    the selected transaction and household.
  - Trim and reject blank merchant group.
  - Validate category and subcategory belong to the household and selected
    category.
  - Normalize the selected transaction's statement merchant using
    `public.normalize_merchant_name`.
  - Upsert or update the canonical merchant by case-insensitive display name for
    the household.
  - Upsert the merchant alias for the selected normalized statement merchant.
  - Create or update the manual exact mapping rule for the normalized statement
    merchant with the selected merchant/category/subcategory/confidence, priority
    10, `apply_to_future = true`, `created_by` populated when missing, and notes
    stored when provided.
  - Update all transactions in the same household with that normalized statement
    merchant, setting merchant/category/subcategory/confidence and
    classification audit fields.
  - Resolve open review items for matching transactions.
  - Return rule id, merchant id, category id, subcategory id,
    updated transaction count, and resolved review item count.
- Either keep `public.apply_merchant_review_correction(...)` intact as a
  compatibility wrapper around the new RPC or leave it unchanged and migrate only
  the Flutter app to the new RPC. Prefer avoiding duplicate correction logic.
- Extend `FinanceTransaction` to expose merchant id/display name and
  subcategory id/name so the Transactions editor can prefill correctly.
- Add a shared Flutter metadata editor component or helper used by both Review
  and Transactions. It should:
  - Prefill from current metadata first, then suggestions, then statement
    merchant.
  - Include merchant group, category, subcategory, confidence enum, and notes.
  - Reuse inline category creation from Milestone 14.
  - Show a concise scope hint that the save affects matching statement merchant
    rows and future imports.
  - Disable save while submitting and surface RPC errors in a SnackBar.
- Update Review tab behavior:
  - Continue to show current/suggested metadata and confidence.
  - Save through the new transaction metadata correction request.
  - Resolve on save and refresh review queue, merchant research suggestions,
    categories/subcategories when relevant, dashboard snapshot, and affected
    transaction queries.
- Update Transactions behavior:
  - Add an Edit action in the detail bottom sheet.
  - Open the shared metadata editor from the sheet.
  - Refresh transaction list, dashboard snapshot, trends, and review queue after
    a successful edit.
- Keep app UI Android-first and consistent with the existing Material style.

Expected code shape:

- Prefer a single shared Dart request/result model for transaction metadata
  correction instead of separate Review and Transactions request types.
- Prefer one backend RPC for both entrypoints.
- Keep direct table updates inside the RPC so the client does not sequence
  writes across `transactions`, `merchants`, `merchant_aliases`,
  `merchant_mapping_rules`, and `review_items`.
- Use existing category/subcategory providers; do not create new taxonomy
  management screens.

Acceptance criteria:

- From Review, a user can edit merchant group, category, subcategory,
  confidence, and notes, then save. The review item disappears and matching open
  review items for that normalized statement merchant are resolved.
- From Transactions detail, a user can edit the same metadata fields and save.
  Matching past transactions for the normalized statement merchant show the new
  merchant/category/subcategory/confidence.
- Future imports for that normalized statement merchant use the edited mapping
  rule.
- Viewer and non-member users cannot apply metadata corrections.
- Invalid category/subcategory combinations and blank merchant names are
  rejected.
- No privileged credentials are introduced into Flutter.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
pnpm --dir tools/workbook-import test
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## Test Cases

- Database: selected transaction edit updates every transaction with the same
  normalized statement merchant.
- Database: future matching uses the created/updated exact mapping rule.
- Database: editable confidence persists for transactions, merchant, and mapping
  rule.
- Database: review save resolves matching open review items.
- Database: viewer and non-member calls fail.
- Database: category from another household, subcategory from another category,
  and blank merchant group fail.
- Flutter: Review tab opens the shared editor, changes confidence/category, and
  submits the expected request.
- Flutter: Transactions detail bottom sheet exposes Edit, opens the shared
  editor, and submits the expected request.
- Flutter: inline category creation in the shared editor selects the newly
  created category/subcategory.

## Deferred Scope

- Editing amounts, dates, source accounts, cardholder, transaction type, source
  fingerprints, raw statement merchant, Gmail source metadata, or parser
  diagnostics.
- Merchant-group-wide alias merge or recategorizing every alias under a broader
  merchant display name.
- Category rename, delete, reorder, merge, or standalone subcategory management.
- iOS and web interface work.
