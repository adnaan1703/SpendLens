# SpendLens Data Model

## Principles

- Use Postgres as the source of truth.
- Use UUID primary keys.
- Use `household_id` on every user-owned finance table.
- Use numeric money columns, not floating point.
- Keep source data and enriched data separate enough to audit.
- Make summaries queryable from views, not manually maintained app state.
- Preserve enough import metadata to debug without storing raw email bodies.

## Enumerations

Use Postgres enums or checked text values for these concepts:

- `member_role`: `owner`, `admin`, `member`, `viewer`
- `transaction_type`: `debit_spend`, `refund_reversal`, `bill_payment_credit`, `adjustment`, `unknown`
- `confidence`: `high`, `medium`, `low`, `manual`
- `source_type`: `workbook`, `gmail`, `manual`, `api`
- `source_account_type`: `credit_card`, `upi`, `netbanking_imps`, `bank_account`, `wallet`, `cash`, `other`
- `review_status`: `open`, `resolved`, `dismissed`
- `piggy_entry_type`: `deposit`, `withdrawal`, `adjustment`
- `job_status`: `queued`, `processing`, `completed`, `failed`, `cancelled`

Milestone 67 added `netbanking_imps` to `source_account_type` for HDFC
Netbanking IMPS Gmail candidates.

## Identity and Household

### `profiles`

App-level user profile linked to Supabase Auth.

Important fields:

- `id uuid primary key`
- `auth_user_id uuid unique not null`
- `display_name text`
- `email text`
- `created_at timestamptz`
- `updated_at timestamptz`

### `households`

Finance workspace. v1 can create one household per user, but the schema must support family/household sharing.

Important fields:

- `id uuid primary key`
- `name text not null`
- `currency_code text not null default 'INR'`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

### `household_members`

Membership and permissions.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `role member_role not null`
- `is_active boolean not null default true`
- `created_at timestamptz`

Unique constraint:

- `(household_id, profile_id)`

## Sources

### `source_accounts`

Represents a card, UPI handle, bank account, wallet, or manual source.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `type source_account_type not null`
- `display_name text not null`
- `institution_name text`
- `masked_identifier text`
- `cardholder_name text`
- `is_active boolean not null default true`
- `created_at timestamptz`
- `updated_at timestamptz`

Workbook mapping:

- `Cardholder` values should become `cardholder_name` or associated source-account metadata.

### `linked_mailboxes`

Gmail connector state for ingestion.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `email text not null`
- `provider text not null default 'gmail'`
- `oauth_secret_ref text`
- `gmail_history_id text`
- `watched_gmail_label_id text`
- `watched_gmail_label_name text`
- `watched_gmail_label_resolved_at timestamptz`
- `watch_expires_at timestamptz`
- `last_sync_at timestamptz`
- `last_error text`
- `is_active boolean not null default true`
- `created_at timestamptz`
- `updated_at timestamptz`

Milestone 66 added the watched-label fields for the nested Gmail label
`Banking/HDFC Transactions`, shown in Gmail UI as `HDFC Transactions` under
`Banking`. Store the resolved Gmail label id/name on the mailbox so watch
renewal, history sync, and backfill use the same label without increasing Gmail
permissions. Do not expose decrypted OAuth tokens to the client.

### `import_batches`

Tracks workbook, email backfill, or manual imports.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `source_type source_type not null`
- `source_label text`
- `status job_status not null`
- `started_at timestamptz`
- `completed_at timestamptz`
- `row_count integer`
- `inserted_count integer`
- `updated_count integer`
- `duplicate_count integer`
- `validation_summary jsonb`
- `error_message text`
- `created_by uuid references profiles(id)`

## Categories and Monthly Caps

### `categories`

Top-level category list.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `name text not null`
- `sort_order integer`
- `is_system boolean not null default false`
- `created_at timestamptz`

Unique constraint:

- `(household_id, lower(name))`

### `subcategories`

Child category list.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `category_id uuid references categories(id)`
- `name text not null`
- `sort_order integer`
- `created_at timestamptz`

Unique constraint:

- `(category_id, lower(name))`

### Category Management Rules

Category management writes are app-facing, authenticated, household-scoped, and
implemented through `security invoker` RPCs. Flutter must not use service-role
credentials or privileged backend functions for taxonomy management.

`public.create_household_category(...)` creates one category plus its first
subcategory. `public.update_household_category_taxonomy(...)` renames an
existing category, renames existing subcategories under that category, and adds
new subcategories while preserving existing IDs.

`public.delete_household_subcategory(...)` removes a subcategory without
deleting transactions. Affected transactions keep their parent `category_id`,
clear `subcategory_id`, receive classification audit metadata, and return to
Review for reassignment. Category-level future mapping rules may remain active;
subcategory-specific references are cleared.

`public.delete_household_category(...)` removes a category only after dependent
references are handled. Affected transactions keep merchant/source context but
clear category, subcategory, and classification-rule references, current
category caps for the deleted category are removed, future mapping rules that
referenced the deleted taxonomy are deactivated, merchant/review suggestions are
cleared, and affected transactions return to Review. After Milestones 29-31,
category deletion removes the deleted category from monthly cap targets and
deletes any cap left with no category or label targets.

`public.merge_household_categories(...)` merges one or more source categories
into a surviving destination category. Every source subcategory must be mapped
to an existing or newly named destination subcategory before save. The merge
repoints transactions, merchants, active future mapping rules, open review
items, and current category caps to surviving taxonomy, sums matching monthly
caps, and does not create Review items. After Milestones 29-31, merge repoints
monthly cap category targets to the surviving category and dedupes targets
without summing independent named caps.

Dashboard summaries, monthly caps, transaction filters, trend tables, merchant
review, metadata editor selectors, workbook imports, and Gmail future mapping
continue to use taxonomy IDs. Settings category detail links to Transactions
with the selected category filter applied. Subcategory detail keeps its
subcategory context in Settings; M25 does not introduce a subcategory-specific
Transactions filter.

### `category_caps` (legacy migrated history)

Legacy monthly cap per category. The app-facing cap model is now
`monthly_caps` with category and label targets; `category_caps` remains in
the migration history for backfill and compatibility only.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `category_id uuid references categories(id)`
- `period_month date not null`
- `cap_amount numeric(14,2) not null`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- `period_month` is the first day of the month.
- Active app reads and writes use recurring cap series through
  `monthly_cap_series`, `monthly_cap_versions`,
  `monthly_cap_version_categories`, `monthly_cap_version_labels`,
  `upsert_monthly_cap`, `delete_monthly_cap`, `get_monthly_cap_progress`, and
  `get_available_reporting_months`.
- `v_budget_progress` is retained only as a category-only compatibility view
  over monthly caps.
- `monthly_caps`, `monthly_cap_categories`, and `monthly_cap_labels` are
  retained as compatibility snapshot tables for migrated history, older summary
  views, and category/label lifecycle bridging. New Flutter reads do not use
  `category_caps`.

Unique constraint:

- `(household_id, category_id, period_month)`

### `monthly_caps`

Compatibility snapshot for named monthly caps from the completed M29-M31
implementation. After M32, the stable app-facing cap identity is
`monthly_cap_series.id`; RPC writes keep this table usable for legacy views and
tests while exact-month app progress comes from recurring series/version rows.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `name text not null`
- `period_month date not null`
- `cap_amount numeric(14,2) not null`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- `name` is required, trimmed, nonblank, and case-insensitively unique per
  household and month.
- `period_month` is the first day of the month.
- `cap_amount` cannot be negative.
- A cap must have at least one category or label target.
- A transaction contributes to a cap when any selected category or label target
  matches.
- A transaction counts once within a cap even when multiple targets match.
- Overlapping caps are allowed, so the same transaction can count toward
  multiple caps.
- Cap edits do not change transaction categories, labels, merchant mappings,
  review state, importer behavior, or future Gmail classification.
- Dashboard-created caps are recurring by default after M32. This table is no
  longer the source of truth for historical versioning.

### `monthly_cap_categories`

Many-to-many target list between monthly caps and top-level categories.

Important fields:

- `household_id uuid references households(id)`
- `monthly_cap_id uuid references monthly_caps(id)`
- `category_id uuid references categories(id)`
- `created_at timestamptz`

Rules:

- A category can be selected once per cap.
- Category deletion removes this target. If a cap has no remaining category or
  label targets, the cap is deleted.
- Category merge repoints source category targets to the surviving category and
  dedupes targets; independent named caps are not summed.

### `monthly_cap_labels`

Many-to-many target list between monthly caps and transaction labels.

Important fields:

- `household_id uuid references households(id)`
- `monthly_cap_id uuid references monthly_caps(id)`
- `label_id uuid references labels(id)`
- `created_at timestamptz`

Rules:

- A label can be selected once per cap.
- Label deletion removes this target. If a cap has no remaining category or
  label targets, the cap is deleted.
- Label rename preserves target behavior because caps reference label IDs.

### `monthly_cap_series`

Stable household-scoped identity for a recurring monthly cap.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `created_by uuid references profiles(id)`
- `stopped_from_month date null`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- Recurring cap identity is explicit; do not infer recurrence from matching
  names, amounts, or target sets.
- `stopped_from_month` is the first month hidden by a delete/stop action. Prior
  months remain readable through their active version.

### `monthly_cap_versions`

Month-effective cap configuration for a recurring cap series.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `monthly_cap_series_id uuid references monthly_cap_series(id)`
- `effective_month date not null`
- `name text not null`
- `base_amount numeric(14,2) not null`
- `carry_forward_enabled boolean not null default false`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- `effective_month` is the first day of the month.
- A series can have only one version for a given effective month.
- Edits create or replace the selected month's version and leave older months
  readable through older versions.
- Carry-forward defaults off. When enabled, Postgres derives the next active
  month's carry-forward amount from the previous month's effective cap minus
  spend, and Dashboard displays the returned carried/effective amounts without
  recomputing them in Flutter.
- Category/label matching semantics stay unchanged: category OR label target
  match, one transaction counted once per cap, and overlap allowed across
  separate caps.

### `monthly_cap_version_categories`

Versioned category targets for recurring monthly caps.

Important fields:

- `household_id uuid references households(id)`
- `monthly_cap_version_id uuid references monthly_cap_versions(id)`
- `category_id uuid references categories(id)`
- `created_at timestamptz`

Rules:

- Targets belong to a specific cap version so historical months can retain the
  targets active for that version.
- Category delete removes affected targets and prunes cap versions/series left
  without any category or label targets.
- Category merge repoints source category targets to the surviving category and
  dedupes duplicates.

### `monthly_cap_version_labels`

Versioned label targets for recurring monthly caps.

Important fields:

- `household_id uuid references households(id)`
- `monthly_cap_version_id uuid references monthly_cap_versions(id)`
- `label_id uuid references labels(id)`
- `created_at timestamptz`

Rules:

- Targets belong to a specific cap version.
- Label delete removes affected targets and prunes cap versions/series left
  without any category or label targets.
- Label rename preserves target behavior because caps reference label IDs.

### Carry-forward semantics

Recurring cap progress calculates carry-forward in Postgres and Dashboard
renders the returned base, carried, effective cap, spent, remaining/over, and
matched-count values.

- Carry-forward is optional per recurring cap and defaults off.
- Carry-forward can be positive or negative. It is derived as previous month's
  effective cap minus previous month's spend for the same active cap series.
- Effective cap equals base monthly cap plus carry-forward amount.
- Remaining amount equals effective cap minus current-month spend.
- Over-budget state is based on negative remaining amount, not only current
  spend compared with the base cap.
- Carry-forward chains only across active months for the same cap series while
  carry-forward remains enabled.
- App-facing progress responses already expose base cap amount, carry-forward
  enabled state, carry-forward amount, effective cap amount, spent amount,
  remaining amount, percent used, over-budget state, matched transaction count,
  and target names/IDs.

### Monthly cap transaction drilldown (M79-M81)

Milestone 79 adds the read-only cap transaction drilldown data contract for the
Dashboard Monthly caps section. Milestones 80-81 add the visible Dashboard
route/screen and final regression/docs closeout.

App-facing read path:

- `get_monthly_cap_transactions(p_household_id, p_monthly_cap_id,
  p_period_month, p_limit, p_offset)`.

Rules:

- The RPC returns the transactions that match one active recurring cap series
  for one first-day reporting month.
- Matching uses the same category OR label semantics as monthly cap progress.
- A transaction is returned once even when it matches both category and label
  targets inside the cap.
- Pagination is bounded, ordered by newest transaction date, then deterministic
  creation/id tiebreakers.
- `is_under_review` means an open `review_items` row exists for the
  transaction. Low confidence alone is not an under-review marker.
- Returned rows include view-only transaction fields, merchant/category/
  subcategory names, ordered transaction label ids/names, `is_under_review`,
  and the newest open `review_item_id`.
- The Flutter screen is view-only and must not route to Activity with filters
  applied.

## Merchants and Mapping

### `merchants`

Canonical merchant groups/companies.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `display_name text not null`
- `category_id uuid references categories(id)`
- `subcategory_id uuid references subcategories(id)`
- `confidence confidence not null default 'medium'`
- `notes text`
- `source_url text`
- `created_at timestamptz`
- `updated_at timestamptz`

Workbook mapping:

- `Merchant Group`, `Category`, `Subcategory`, `Confidence`, `Notes`, and `Source URL`.

Merchant group management rules from Milestones 61-64:

- `merchants.display_name` is the canonical merchant group name exposed in
  Settings.
- Renaming a merchant group updates `display_name` globally while preserving the
  merchant id and existing links from aliases, mapping rules, transactions,
  review suggestions, summaries, and autocomplete.
- Merchant group merge uses one surviving destination merchant id. Source
  merchant aliases, mapping rules, transaction `merchant_id` references, and
  open review suggested merchant references move to the destination merchant.
- Merge never deletes transactions.
- Merge category handling is explicit: preserve existing transaction/rule/review
  category fields, or apply the destination merchant category/subcategory to
  moved source references.
- Statement-merchant-level reassignment, alias editing, merchant deletion, and
  raw statement merchant editing remain out of scope for the Settings manager.
- Milestone 62 added the app-facing data contract:
  `public.v_merchant_group_usage`, `rename_household_merchant(...)`, and
  `merge_household_merchants(...)`. Milestone 63 added the visible Settings
  rename/merge UI on top of this contract. Milestone 64 verified the final
  local regression path and confirmed Settings rename/merge writes stay
  RPC-backed.
- After Settings rename or merge, Flutter invalidates merchant group manager
  data, merchant options, transactions, trend reports, Dashboard snapshots, and
  the Review queue.

### `merchant_aliases`

Observed statement names that map to canonical merchants.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `merchant_id uuid references merchants(id)`
- `raw_name text not null`
- `normalized_name text not null`
- `source_type source_type`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `created_at timestamptz`

Unique constraint:

- `(household_id, normalized_name)`

### `merchant_mapping_rules`

Rules created by import heuristics or user review.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `pattern text not null`
- `match_type text not null`
- `merchant_id uuid references merchants(id)`
- `category_id uuid references categories(id)`
- `subcategory_id uuid references subcategories(id)`
- `priority integer not null default 100`
- `confidence confidence not null default 'manual'`
- `apply_to_future boolean not null default true`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- User corrections create exact mapping rules for the edited normalized
  statement merchant. The selected confidence persists on the rule so future
  imports can apply the same confidence as the historical correction.
- v1 correction behavior applies to past and future matching transactions.
- Postgres owns backend rule matching for Gmail ingestion and workbook/future
  import clients through `merchant_rule_matches(...)`,
  `match_merchant_mapping_rule(...)`, and
  `classify_statement_merchant(...)`.
- Matching prefers exact, prefix, suffix, contains, then regex rules before
  applying priority ascending and newest-rule tie-breaks.
- Exact, prefix, suffix, and contains rules compare normalized statement
  merchant text against normalized rule patterns. Regex rules evaluate the
  stored pattern against normalized statement merchant text without normalizing
  away regex syntax.
- Blank inputs, blank effective patterns, unknown match types, and invalid
  regex patterns fail closed by returning no match.
- `classify_statement_merchant(...)` is a read-only `security invoker` helper
  that returns the winning rule IDs, display names, confidence, notes, and
  creator for callers that need classification details.
- Milestone 77 verified the final local regression path for backend-owned rule
  semantics across the focused pgTAP suite, Supabase lint, workbook importer
  tests, dry-run validation, and a local import smoke. Hosted migration push
  remains a separate explicit rollout operation.

### Transaction Metadata Correction RPC

`public.apply_transaction_metadata_correction(...)` is the authenticated,
`security invoker` write contract for editing transaction classification
metadata from the app. It requires household write access, validates the
selected transaction and optional open review item, validates
category/subcategory ownership, trims the merchant group, updates every
transaction in the household with the selected transaction's normalized
statement merchant, upserts the canonical merchant and exact alias, creates or
updates the future exact mapping rule, and resolves matching open review items.

Editable fields are merchant group, category, subcategory, confidence, and
notes. Money fields, source fields, transaction dates, raw statement merchant,
source fingerprints, and Gmail/parser diagnostics are not edited by this RPC.

## Transactions

### `transactions`

Canonical expense ledger row.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `source_account_id uuid references source_accounts(id)`
- `source_type source_type not null`
- `occurred_at timestamptz`
- `transaction_date date not null`
- `transaction_time time`
- `statement_month text`
- `cardholder_name text`
- `statement_merchant text not null`
- `normalized_statement_merchant text not null`
- `merchant_id uuid references merchants(id)`
- `category_id uuid references categories(id)`
- `subcategory_id uuid references subcategories(id)`
- `transaction_type transaction_type not null`
- `amount numeric(14,2) not null`
- `gross_spend numeric(14,2) not null default 0`
- `refund_amount numeric(14,2) not null default 0`
- `net_expense numeric(14,2) not null default 0`
- `currency_code text not null default 'INR'`
- `confidence confidence not null default 'medium'`
- `notes text`
- `classification_rule_id uuid references merchant_mapping_rules(id)`
- `classification_review_item_id uuid references review_items(id)`
- `classification_updated_by uuid references profiles(id)`
- `classification_updated_at timestamptz`
- `classification_note text`
- `source_fingerprint text not null`
- `created_at timestamptz`
- `updated_at timestamptz`

Unique constraint:

- `(household_id, source_fingerprint)`

Workbook mapping:

- `Date` -> `transaction_date`
- `Time` -> `transaction_time`
- `Statement Month` -> `statement_month`
- `Cardholder` -> `cardholder_name`
- `Statement Merchant` -> `statement_merchant`
- `Merchant Group` -> `merchants.display_name`
- `Category` -> `categories.name`
- `Subcategory` -> `subcategories.name`
- `Transaction Type` -> `transaction_type`
- `Amount` -> `amount`
- `Gross Spend` -> `gross_spend`
- `Refund/Reversal` -> `refund_amount`
- `Net Expense` -> `net_expense`
- `Confidence` -> `confidence`
- `Notes` -> `notes`

Financial rules:

- Card bill payments and account credits have `net_expense = 0`.
- Refunds are represented as positive `refund_amount`.
- Dashboard summaries and monthly caps use `net_expense`.

Final transaction deletion rules from Milestones 52-55:

- Transaction deletion is owner-only and app-facing through an RLS-safe
  authenticated contract.
- Deletion is a hard delete of the `transactions` row.
- Deleting a transaction removes its contribution from monthly spend, merchant
  spend, trends, dashboard totals, labels, review, and monthly caps because
  those reads derive from remaining transaction rows.
- Deleting a transaction records a minimal source tombstone so the same
  workbook row or Gmail email cannot recreate the transaction later.
- Piggy-bank entries and service diagnostics that reference the transaction are
  preserved but unlinked.

### `deleted_transaction_sources` (added in M52)

Minimal household-scoped tombstones for deleted transaction source identities.
This table prevents idempotent import paths from recreating transactions the
owner intentionally removed. Workbook and Gmail ingestion consult these
tombstones before upsert.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `source_type source_type not null`
- `source_fingerprint text not null`
- `deleted_transaction_id uuid not null`
- `source_message_id text`
- `source_reference text`
- `deleted_by uuid references profiles(id)`
- `deleted_at timestamptz`
- `reason text`

Rules:

- Unique `(household_id, source_fingerprint)`.
- Store only minimal source identity. Do not store amount, merchant, category,
  cardholder, notes, raw email body, parsed email body, or full transaction
  payload data.
- Owners can create tombstones through transaction deletion. Service-role
  ingestion code can read tombstones for suppression.
- Tombstones are recorded during owner transaction deletion. Workbook and Gmail
  transaction creation is blocked for matching source fingerprints.

### Transaction labels

SpendLens uses household-shared labels for ad hoc transaction grouping. Labels
are separate from category taxonomy and merchant mapping rules.

#### `labels`

Household label vocabulary.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `name text not null`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- Names are trimmed and nonblank.
- Names are case-insensitively unique within a household.
- Labels are household-shared, not per-profile private.
- Household writers can create labels from Settings or while editing one
  transaction; Settings-created labels can remain unattached until used.
- Renaming a label preserves its ID and updates visible label text wherever that
  label is attached.

#### `transaction_labels`

Many-to-many assignment between transactions and labels.

Important fields:

- `household_id uuid references households(id)`
- `transaction_id uuid references transactions(id)`
- `label_id uuid references labels(id)`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`

Rules:

- A transaction can have many labels.
- A label can be attached to many transactions.
- The same label can be attached to a transaction only once.
- Assigning a label to one transaction does not assign it to other transactions
  from the same merchant, normalized statement merchant, category, source
  account, import, or Gmail thread.
- Label assignment edits never update `category_id`, `subcategory_id`,
  `merchant_id`, `merchant_mapping_rules`, Review rows, monthly cap
  definitions, source metadata, money fields, or future import behavior.
  After Milestones 29-31, cap progress can change when a transaction gains or
  loses a label that is used as a cap target.
- Deleting a label detaches it from all transactions and preserves every
  transaction row. If a deleted label was the active Transactions filter, the
  app clears that stale filter after label lookup refresh.

### `transaction_sources`

Stores source metadata without retaining raw email bodies.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `transaction_id uuid references transactions(id)`
- `import_batch_id uuid references import_batches(id)`
- `source_type source_type not null`
- `source_message_id text`
- `source_thread_id text`
- `source_reference text`
- `source_received_at timestamptz`
- `parser_name text`
- `parser_version text`
- `parse_status text`
- `diagnostics jsonb`
- `created_at timestamptz`

Rules:

- Store Gmail message ID and parser diagnostics only.
- Do not store raw email body by default.

### `gmail_parse_attempts`

Stores service-only diagnostics for Gmail transaction candidates before and
after body parsing. Failed body parses do not always have a `transactions` row,
so they are tracked separately from `transaction_sources`.

Important fields:

- `household_id uuid references households(id)`
- `linked_mailbox_id uuid references linked_mailboxes(id)`
- `transaction_id uuid references transactions(id)` when parsing and ingestion
  succeed
- `candidate_type source_account_type` for `credit_card`, `upi`,
  `netbanking_imps`, or `other`
- `source_message_id text`
- `source_thread_id text`
- `source_received_at timestamptz`
- `sender_email text`
- `subject text`
- `parser_name text`
- `parser_version text`
- `parse_status text` for `parsed`, `parse_failed`, or `outside_date_range`
- `transaction_date date` when body parsing extracts one
- `source_reference text`
- `diagnostics jsonb`
- `ignored_at timestamptz`
- `ignored_by uuid references profiles(id)`

Rules:

- Month reconciliation uses `source_received_at`.
- Raw email bodies and body snippets are not stored.
- Rows are service-role only. The Flutter app sees only sanitized,
  household-scoped parse failures through app-facing RPCs.
- Ignored parse-failure rows stay in `gmail_parse_attempts` for diagnostics but
  are hidden from app-facing Review failure lists.
- Milestone 71 added paginated app-facing access to unignored parse failures
  and authenticated on-demand plain-text body fetch from one visible failure
  row. Milestone 72 added the visible Review pagination and body dialog. The
  body fetch remains transient: authorize through the visible household-scoped
  failure row, fetch from Gmail server-side, return the text to the open
  dialog, and do not persist the body or body snippets in Postgres. Milestone 73
  verified the completed Review workflow and folded the final behavior into
  durable docs.

## Review Queue

### `review_items`

Tracks transactions or merchants needing user review.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `transaction_id uuid references transactions(id)`
- `reason text not null`
- `status review_status not null default 'open'`
- `suggested_merchant_id uuid references merchants(id)`
- `suggested_category_id uuid references categories(id)`
- `suggested_subcategory_id uuid references subcategories(id)`
- `resolved_by uuid references profiles(id)`
- `resolved_at timestamptz`
- `created_at timestamptz`

Create review items for:

- Unknown merchant.
- Unknown category.
- Low confidence mapping.
- Parser ambiguity.
- Duplicate conflict requiring a user decision.

## Piggy Banks

### `piggy_banks`

Manual future-expense accounts.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `name text not null`
- `description text`
- `target_amount numeric(14,2)`
- `target_date date`
- `currency_code text not null default 'INR'`
- `is_archived boolean not null default false`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

### `piggy_bank_entries`

Ledger entries.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `piggy_bank_id uuid references piggy_banks(id)`
- `entry_type piggy_entry_type not null`
- `amount numeric(14,2) not null`
- `entry_date date not null`
- `note text`
- `linked_transaction_id uuid references transactions(id)`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`

Rules:

- Balance is `sum(deposits) - sum(withdrawals) + sum(adjustments)`.
- Do not store editable balance directly.
- Withdrawals cannot exceed balance unless the user explicitly confirms an overdraft adjustment in a future feature.

## AI Tables

These tables support backend-mediated Gemini expense Q&A and transaction metadata suggestions. Historical `ai_jobs` and `ai_usage_events` rows may still contain the retired `merchant_research` feature as audit history.

### `ai_feature_settings`

Important fields:

- `household_id uuid primary key references households(id)`
- `provider text not null default 'gemini'`
- `model text not null default 'gemini-3.5-flash'`
- `monthly_spend_cap_usd numeric(12,6) not null default 0`
- `expense_qa_enabled boolean not null default true`
- `transaction_metadata_suggestion_enabled boolean not null default true`
- `transaction_metadata_suggestion_web_search_enabled boolean not null default false`
- `free_tier_only boolean not null default true`
- `created_by uuid references profiles(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

### `ai_usage_events`

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `feature text not null`
- `provider text not null`
- `model text not null`
- `input_tokens integer`
- `output_tokens integer`
- `estimated_cost_usd numeric(12,6)`
- `status text not null`
- `created_at timestamptz`

### `ai_jobs`

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `job_type text not null`
- `status job_status not null`
- `input jsonb not null`
- `output jsonb`
- `provider text not null`
- `model text not null`
- `usage_event_id uuid references ai_usage_events(id)`
- `error_message text`
- `created_at timestamptz`
- `started_at timestamptz`
- `completed_at timestamptz`

## Planned Push Notification Tables

Milestones 18-21 add Android transaction push notifications. Until those
milestones are implemented, this section is a planned contract rather than an
applied schema.

### `push_devices`

App-facing table for a signed-in user's Android FCM token registrations.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `installation_id text not null`
- `platform text not null`, v1 value `android`
- `fcm_token text not null`
- `token_hash text not null`
- `app_version text`
- `device_label text`
- `is_active boolean not null default true`
- `last_seen_at timestamptz`
- `revoked_at timestamptz`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- A signed-in user may manage only their own devices for households where they
  are an active member.
- Raw FCM tokens must not be logged.
- Service code may read active tokens for dispatch; other household members must
  not see a user's token.

### `notification_preferences`

Per-user, per-household push preferences.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `profile_id uuid references profiles(id)`
- `transaction_push_enabled boolean not null default true`
- `include_sensitive_details boolean not null default true`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- The default shows merchant and amount details in transaction notifications.
- Users can disable transaction push notifications or hide sensitive details for
  their own profile/household preference row.

### `notification_outbox`

Service-only durable notification intent queue.

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `event_type text not null`, v1 value `transaction_batch`
- `source_type source_type not null`
- `source_job_id uuid`
- `idempotency_key text not null`
- `transaction_ids uuid[] not null`
- `transaction_count integer not null`
- `detail_title text not null`
- `detail_body text not null`
- `private_title text not null`
- `private_body text not null`
- `data jsonb not null`
- `status text not null`
- `attempt_count integer not null default 0`
- `max_attempts integer not null default 5`
- `next_attempt_at timestamptz`
- `locked_at timestamptz`
- `locked_by text`
- `sent_at timestamptz`
- `failed_at timestamptz`
- `last_error text`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- Use unique `(household_id, event_type, idempotency_key)` to avoid duplicate
  notification work.
- Gmail sync uses `gmail-job:<ingestion_jobs.id>` idempotency.
- Workbook imports do not enqueue push notifications by default.
- App roles do not read or write this table.

### `notification_deliveries`

Service-only per-device delivery audit.

Important fields:

- `id uuid primary key`
- `outbox_id uuid references notification_outbox(id)`
- `push_device_id uuid references push_devices(id)`
- `profile_id uuid references profiles(id)`
- `fcm_token_hash text`
- `status text not null`
- `attempt_count integer not null default 0`
- `provider_message_id text`
- `provider_error_code text`
- `last_error text`
- `sent_at timestamptz`
- `created_at timestamptz`
- `updated_at timestamptz`

Rules:

- Use unique `(outbox_id, push_device_id)` to avoid resending to the same device
  after retries.
- Permanent FCM token errors should deactivate only the affected device.
- App roles do not read or write this table in v1.

## Summary Views

Create these views for app reads:

- `v_monthly_spend`: monthly gross, refunds, net spend, bill payments.
- `v_category_monthly_spend`: category spend per month.
- `v_budget_progress`: legacy category-only compatibility cap progress over
  monthly caps.
- `v_monthly_cap_progress`: named cap progress for category and label targets,
  with each transaction counted once per cap. After M33, recurring cap progress
  includes positive/negative carry-forward, effective cap amounts, and
  carry-forward-aware remaining/over-budget values.
- `v_merchant_summary`: merchant spend, refunds, net, transaction counts.
- `v_merchant_group_usage`: Settings merchant group manager usage view
  with transaction, alias, active mapping-rule, review-suggestion, taxonomy,
  net spend, and last-transaction context.
- `v_review_queue`: open review items with transaction and suggestions.
- `v_piggy_bank_balances`: piggy-bank balance and target progress.

Views exposed to clients must either obey RLS through underlying tables or be created as `security_invoker` where supported.
