# Merchant Autocomplete Plan

Last updated: 2026-06-15

This document is the completed-only implementation record for merchant
autocomplete and save-time duplicate guarding. Milestones 56-60 were executed
as standalone milestones in separate Codex threads.

## Target Behavior

Wherever SpendLens asks the user to type a merchant group, the app should help
reuse existing household merchant names instead of accidentally creating
near-duplicate merchant groups.

- Activity List keeps free-text merchant search, but selecting an autocomplete
  suggestion filters by canonical `merchant_id`.
- The shared transaction metadata editor, opened from Activity transaction
  details or Review resolution, replaces the plain Merchant group text field
  with an autocomplete field.
- Existing merchant selection fills the canonical display name and, when known,
  preselects the merchant's category/subcategory while still letting the user
  override before saving.
- New merchant names remain allowed.
- Before saving a new merchant group, if the typed name is close to one clear
  existing merchant group, the editor asks whether to use the existing merchant
  or keep the typed name.

## Existing Foundation

- `apps/mobile/lib/src/features/transaction_metadata/transaction_metadata_editor.dart`
  is the shared metadata editor used by both Activity and Review.
- `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  owns Activity List filtering and opens the shared metadata editor.
- `apps/mobile/lib/src/features/merchant_review/merchant_review_screen.dart`
  opens the same metadata editor with a `reviewItemId`.
- `apps/mobile/lib/src/data/repositories/finance_repository.dart` already has
  `MerchantOption`, `merchantOptionsProvider`, `fetchMerchants(...)`,
  `TransactionQuery`, `fetchTransactions(...)`, and
  `applyTransactionMetadataCorrection(...)`.
- `public.apply_transaction_metadata_correction(...)` already reuses exact
  case-insensitive merchant display names and the database enforces
  `unique (household_id, lower(display_name))`.
- The Activity route query parameter `merchant` currently maps to statement
  merchant text search, not a canonical merchant id.

## Global Rules For M56-M60

- Implement only the requested milestone. After it is complete, verified,
  cleaned up, and documented, stop and report the result.
- Do not start, partially implement, or prepare code for a later milestone
  unless the user explicitly asks.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Do not add a Supabase migration for this feature unless implementation proves
  the full household merchant list is too large for client-side autocomplete.
- Preserve freeform merchant entry and today's statement merchant text search
  behavior unless an existing merchant suggestion is selected.
- Use existing Flutter Material autocomplete primitives or a small local shared
  widget; do not add a package for fuzzy matching or typeahead.
- Fuzzy matching compares existing canonical merchant display names only. Do
  not compare merchant aliases or raw statement merchant strings in this plan.
- Keep close-match thresholds as named constants and lock behavior through
  tests; do not scatter numeric literals through UI code.
- Update `docs/implementation-plan/MILESTONES.md` and
  `docs/implementation-plan/SESSION_HANDOFF.md` when each milestone starts or
  completes.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M56 - Merchant Autocomplete Planning and Reference Readiness

Status: Completed on 2026-06-15.

Purpose: Create the companion plan and wire the new milestone sequence into
the durable planning docs.

Instructions:

- Create `MERCHANT_AUTOCOMPLETE.md` with the target behavior, current
  foundation, global rules, implementation milestones, acceptance criteria, and
  verification expectations.
- Add the companion plan to `README.md`, `MILESTONES.md`, and
  `SESSION_HANDOFF.md`.
- Mark implementation as planned only; do not change Flutter or Supabase code.

Expected code shape:

- Documentation-only milestone. No app, repository, SQL, importer, Edge
  Function, hosted rollout, iOS, or web changes.

Acceptance criteria:

- A fresh implementation thread can start at M57 from the docs alone.
- The next recommended milestone is M57.
- Milestones 18-21 remain explicitly deferred.

Verification:

```bash
rg -n "MERCHANT_AUTOCOMPLETE|Milestone 5[6-9]|Milestone 60|Merchant Autocomplete" docs/implementation-plan
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M57 - Merchant Repository and Activity Filter Foundation

Status: Completed on 2026-06-15.

Purpose: Add canonical merchant filtering to Activity while preserving current
free-text search behavior.

Instructions:

- Inspect `finance_repository.dart`, `transactions_screen.dart`, and existing
  Activity filter tests before editing.
- Extend `MerchantOption` to include nullable `categoryId` and `subcategoryId`.
- Update `fetchMerchants(...)` to select and map `category_id` and
  `subcategory_id` from `public.merchants`.
- Extend `TransactionQuery` with nullable `merchantId`.
- In `fetchTransactions(...)`, apply `.eq('merchant_id', merchantId)` when
  `merchantId` is present. Keep existing `statement_merchant ilike` search for
  free-text search when no merchant id is selected.
- Watch `merchantOptionsProvider(householdId)` in Activity List and pass
  merchant options into the filter surface.
- Add Activity filter state for the selected merchant id.
- Selecting a merchant suggestion should set the search controller text to the
  canonical display name, set `merchantId`, clear the page to 0, and filter by
  `merchant_id`.
- Typing after a suggestion should clear `merchantId`, keep the typed text, and
  use the current statement merchant text search.
- Clear filters should reset both typed search text and selected merchant id.
- Do not change the shared metadata editor in this milestone.
- Do not change Dashboard drilldown route semantics in this milestone; existing
  `merchant` query params should continue to seed statement merchant text.

Expected code shape:

- Activity keeps one visible Merchant search control.
- Repository contract supports both `searchText` and `merchantId`, with
  `merchantId` taking precedence for canonical filtering.
- Existing fake repository data includes merchant category/subcategory fields
  when useful for later tests.

Acceptance criteria:

- Activity still supports typing arbitrary merchant text.
- Selecting an existing merchant filters by canonical merchant id.
- Editing the text after selecting a suggestion returns to free-text search.
- Clear filters clears canonical merchant selection.

Verification:

```bash
cd apps/mobile && flutter test test/finance_features_test.dart --name "Activity"
cd apps/mobile && flutter analyze
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Implemented canonical merchant filtering in Activity with one visible merchant
  search control backed by existing household merchant options.
- Extended repository models/queries so `merchantId` takes precedence over
  free-text `statement_merchant` search and merchant suggestions carry nullable
  category/subcategory ids for later milestones.
- Preserved Dashboard drilldown route semantics: existing `merchant` query
  params still seed free-text statement merchant search.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Activity"`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "transaction query supports label filter equality and copyWith"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing `public.merchants` reads are sufficient for M57; no Supabase
    migration was needed.
  - Canonical merchant selection should remain Activity-local state until a
    later milestone explicitly expands routing.
  - Milestones 18-21 remain deferred, and M58-M60 were not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with merchant
    category/subcategory fields and canonical merchant id filtering.

## M58 - Shared Merchant Autocomplete in Metadata Editor

Status: Completed on 2026-06-15.

Purpose: Reuse existing merchant groups while editing transaction metadata from
Activity or Review.

Instructions:

- Inspect `transaction_metadata_editor.dart`, `merchant_review_screen.dart`,
  `transactions_screen.dart`, and metadata editor widget tests before editing.
- Replace the metadata editor's plain Merchant group `TextFormField` with a
  reusable merchant autocomplete field.
- Load suggestions from `merchantOptionsProvider(initialValue.householdId)`.
- Keep freeform merchant entry enabled when the typed value does not match a
  suggestion.
- Selecting a merchant suggestion fills the canonical display name.
- If the selected merchant has `categoryId` and `subcategoryId` values that are
  present in the editor's available category/subcategory lists, select them.
  If either id is missing or unavailable, keep the current category/subcategory
  choices unchanged.
- Preserve Suggest, Create category, confidence, notes, validation, loading,
  save, cancel, and error behavior.
- Keep both entrypoints covered: Activity transaction detail edit and Review
  Resolve edit use the same editor.
- Do not add the close-match confirmation popup in this milestone.

Expected code shape:

- A small shared autocomplete widget or helper lives near the metadata editor
  unless another existing shared-widget location is clearly better.
- Text controller lifecycle is explicit and does not break Suggest updates,
  initial values, or form validation.
- Autocomplete overlay remains usable at narrow mobile widths.

Acceptance criteria:

- Typing in the metadata editor shows existing merchant suggestions.
- Selecting an existing merchant updates the field and compatible taxonomy
  selections.
- Freeform merchant names can still be saved.
- Review and Activity edit flows both keep working through the shared editor.

Verification:

```bash
cd apps/mobile && flutter test test/finance_features_test.dart --name "metadata|merchant review"
cd apps/mobile && flutter analyze
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Replaced the shared metadata editor Merchant group text field with a local
  Material autocomplete field backed by `merchantOptionsProvider`.
- Selecting a merchant suggestion fills the canonical display name and selects
  compatible category/subcategory ids only when both ids are present in the
  editor's current option lists.
- Preserved freeform merchant entry, Suggest updates, Create category,
  confidence, notes, validation, loading, save, cancel, and error handling.
- Added Activity detail edit and Review resolve widget coverage for the shared
  editor autocomplete behavior.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "metadata|merchant review"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing merchant option reads are sufficient for M58; no Supabase
    migration was needed.
  - Keeping the helper local to the metadata editor is enough for M58 because
    Activity search already owns its separate filter-specific autocomplete.
  - Milestones 18-21 remain deferred, and M59-M60 were not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options and repository fakes.

## M59 - Close-Match Merchant Save Confirmation

Status: Completed on 2026-06-15.

Purpose: Warn before saving a new merchant group that strongly resembles one
existing merchant group.

Instructions:

- Inspect the final M58 metadata editor code before editing.
- Add a deterministic Dart helper for merchant name normalization and fuzzy
  comparison.
- Normalize by lowercasing, replacing `&` with `and`, removing non-alphanumeric
  separators, and collapsing whitespace.
- Treat exact normalized matches as existing-merchant reuse. Save with the
  canonical existing display name and do not show the confirmation dialog.
- For non-exact names, compute the best close match against existing canonical
  merchant display names only.
- Use named constants for the initial close-match tuning:
  - `closeMatchThreshold = 0.82`
  - `closeMatchLeadMargin = 0.05`
- Implement Levenshtein similarity plus token-prefix handling without adding a
  package dependency. Adjust the constants only if the required test matrix
  proves the initial values are too noisy or too strict, and document that
  choice in the completion notes.
- Show the confirmation dialog only when the best match meets the threshold and
  clearly beats the next candidate by the lead margin.
- Dialog behavior:
  - Title: `Use existing merchant?`
  - Primary action: `Use <merchant name>` saves with the proposed existing
    merchant display name.
  - Secondary action: `Keep new name` saves the typed merchant name.
  - Cancel returns to the editor without saving.
- If the user chooses `Keep new name`, do not re-prompt for the same normalized
  typed value during that editor session.
- Do not compare aliases, raw statement merchants, categories, labels, monthly
  caps, or transaction notes.

Expected code shape:

- Matching logic is pure and unit/widget-testable.
- The save flow remains single-submit safe while the confirmation dialog is
  open.
- Existing backend exact case-insensitive duplicate protection remains the final
  source of truth.

Acceptance criteria:

- `Amazon Shoping` suggests `Amazon Shopping`.
- `Swigy Instamart` suggests `Swiggy Instamart`.
- `Amazon Prime` does not suggest `Amazon Shopping`.
- `Uber Eats` does not suggest `Uber`.
- Exact case-only matches skip the popup and save the canonical display name.
- Choosing `Use existing` and `Keep new name` send the expected merchant group
  to `applyTransactionMetadataCorrection(...)`.

Verification:

```bash
cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant"
cd apps/mobile && flutter analyze
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added a deterministic Dart merchant-name matcher that normalizes names by
  lowercasing, expanding `&` to `and`, replacing non-alphanumeric separators,
  and collapsing whitespace.
- Implemented Levenshtein similarity plus token-prefix scoring with the planned
  `merchantCloseMatchThreshold = 0.82` and
  `merchantCloseMatchLeadMargin = 0.05` constants unchanged.
- Updated the shared transaction metadata editor save flow so exact normalized
  matches save the existing canonical display name without prompting.
- Added the close-match confirmation dialog with `Use <merchant name>`, `Keep
  new name`, and dismiss/cancel behavior while keeping the editor
  single-submit safe.
- Remembered `Keep new name` choices by normalized typed value for the current
  editor session so a failed save can be retried without prompting again.
- Added focused helper and widget coverage for the documented typo, non-match,
  exact, use-existing, keep-new, and cancel paths.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing household merchant options are sufficient for client-side
    close-match comparison; no Supabase migration was needed.
  - The initial threshold and lead-margin constants satisfy the documented test
    matrix, so no tuning change was made.
  - Close-match comparison remains limited to canonical merchant display names;
    aliases, raw statement merchants, categories, labels, caps, and notes were
    not compared.
  - Milestones 18-21 remain deferred, and Milestone 60 was not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with an `Uber` merchant option
    and a one-save failure hook for the keep-new retry test.

## M60 - Merchant Autocomplete Regression, Docs, and Cleanup

Status: Completed on 2026-06-15.

Purpose: Verify the full merchant autocomplete flow and fold the final behavior
into durable docs.

Instructions:

- Run focused and full Flutter checks for Activity filters, Review resolution,
  transaction metadata editing, narrow layout behavior, and existing transaction
  search behavior.
- Fix regressions found during verification only when they are within the
  M57-M59 merchant autocomplete scope.
- Update `README.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md` with final
  behavior and completion notes.
- If implementation discovered that no schema migration was needed, state that
  explicitly in the completion notes.
- If implementation required a schema or RPC change, update
  `DATA_MODEL.md` and add the relevant Supabase verification commands.
- Mark this companion plan completed-only when M60 closes.
- Do not perform hosted rollout, push notification work, iOS work, or web work.

Expected code shape:

- No new product surface beyond Activity merchant filtering, metadata editor
  autocomplete, and close-match confirmation.
- Documentation accurately describes final client and backend behavior.

Acceptance criteria:

- Activity supports free-text merchant search and canonical merchant selection.
- Activity, Review, and transaction detail metadata edits all share the same
  merchant autocomplete behavior.
- Close-match confirmation catches the documented typo cases without prompting
  for documented non-match cases.
- Full Flutter verification passes locally.

Verification:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Ran focused and full Flutter checks for Activity filters, Review resolution,
  transaction metadata editing, narrow metadata editor layout, existing
  transaction search behavior, and the close-match merchant guard.
- Confirmed the final behavior: Activity supports free-text statement merchant
  search plus canonical merchant selection, Activity and Review metadata edits
  share the same autocomplete editor, close-match typos prompt only for the
  documented clear matches, and freeform merchant names remain valid.
- No regressions were found, so no app-code fix was needed during M60.
- No Supabase schema, RPC, importer, Edge Function, hosted rollout, iOS, web,
  or push-notification work was needed or started.
- Marked this companion plan completed-only after folding final behavior into
  `README.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md`.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|review|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Existing household merchant option reads and backend exact duplicate
    protection are sufficient for the final implementation; no schema or RPC
    migration was needed.
  - Close-match comparison remains limited to canonical merchant display names.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options, query capture, and
    metadata correction test hooks.
