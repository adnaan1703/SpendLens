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
- `source_account_type`: `credit_card`, `upi`, `bank_account`, `wallet`, `cash`, `other`
- `review_status`: `open`, `resolved`, `dismissed`
- `piggy_entry_type`: `deposit`, `withdrawal`, `adjustment`
- `job_status`: `queued`, `processing`, `completed`, `failed`, `cancelled`

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
- `watch_expires_at timestamptz`
- `last_sync_at timestamptz`
- `last_error text`
- `is_active boolean not null default true`
- `created_at timestamptz`
- `updated_at timestamptz`

Do not expose decrypted OAuth tokens to the client.

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

## Categories and Budgets

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

### `category_caps`

Monthly cap per category.

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
- Caps are category-level in v1, not subcategory-level.
- A missing cap means no cap has been set.

Unique constraint:

- `(household_id, category_id, period_month)`

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

- User corrections create `manual` confidence rules.
- v1 correction behavior applies to past and future matching transactions.
- Matching implementation should prefer exact normalized matches before pattern matches.

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
- Dashboard and budgets use `net_expense`.

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
- `candidate_type source_account_type` for `upi` or `credit_card`
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

Rules:

- Month reconciliation uses `source_received_at`.
- Raw email bodies and body snippets are not stored.
- Rows are service-role only and are not exposed to the Flutter app.

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

These tables support backend-mediated Gemini expense Q&A and merchant research suggestions.

### `ai_feature_settings`

Important fields:

- `household_id uuid primary key references households(id)`
- `provider text not null default 'gemini'`
- `model text not null default 'gemini-3.5-flash'`
- `monthly_spend_cap_usd numeric(12,6) not null default 0`
- `expense_qa_enabled boolean not null default true`
- `merchant_research_enabled boolean not null default true`
- `merchant_research_web_search_enabled boolean not null default false`
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

### `merchant_research_suggestions`

Important fields:

- `id uuid primary key`
- `household_id uuid references households(id)`
- `review_item_id uuid references review_items(id)`
- `normalized_merchant_name text not null`
- `statement_merchant text`
- `suggested_display_name text`
- `suggested_category_id uuid references categories(id)`
- `suggested_subcategory_id uuid references subcategories(id)`
- `evidence jsonb`
- `confidence confidence`
- `status review_status not null default 'open'`
- `ai_job_id uuid references ai_jobs(id)`
- `usage_event_id uuid references ai_usage_events(id)`
- `created_at timestamptz`
- `updated_at timestamptz`

## Summary Views

Create these views for app reads:

- `v_monthly_spend`: monthly gross, refunds, net spend, bill payments.
- `v_category_monthly_spend`: category spend per month.
- `v_budget_progress`: category cap, spent, remaining, percent used, over-budget flag.
- `v_merchant_summary`: merchant spend, refunds, net, transaction counts.
- `v_review_queue`: open review items with transaction and suggestions.
- `v_piggy_bank_balances`: piggy-bank balance and target progress.

Views exposed to clients must either obey RLS through underlying tables or be created as `security_invoker` where supported.
