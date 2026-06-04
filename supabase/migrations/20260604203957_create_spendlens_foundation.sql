create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;
revoke all on schema app_private from public;

create type public.member_role as enum ('owner', 'admin', 'member', 'viewer');
create type public.transaction_type as enum (
  'debit_spend',
  'refund_reversal',
  'bill_payment_credit',
  'adjustment',
  'unknown'
);
create type public.confidence as enum ('high', 'medium', 'low', 'manual');
create type public.source_type as enum ('workbook', 'gmail', 'manual', 'api');
create type public.source_account_type as enum (
  'credit_card',
  'upi',
  'bank_account',
  'wallet',
  'cash',
  'other'
);
create type public.review_status as enum ('open', 'resolved', 'dismissed');
create type public.piggy_entry_type as enum ('deposit', 'withdrawal', 'adjustment');
create type public.job_status as enum ('queued', 'processing', 'completed', 'failed', 'cancelled');

create or replace function app_private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users (id) on delete cascade,
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_email_nonempty check (email is null or btrim(email) <> '')
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency_code text not null default 'INR',
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint households_name_nonempty check (btrim(name) <> ''),
  constraint households_currency_code_format check (currency_code ~ '^[A-Z]{3}$')
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role public.member_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (household_id, profile_id)
);

create table public.default_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null,
  is_system boolean not null default true,
  include_in_spend boolean not null default true,
  source_workbook_sheet text not null default 'Category Summary',
  created_at timestamptz not null default now(),
  constraint default_categories_name_nonempty check (btrim(name) <> ''),
  constraint default_categories_sort_order_positive check (sort_order > 0)
);

create table public.default_subcategories (
  id uuid primary key default gen_random_uuid(),
  default_category_id uuid not null references public.default_categories (id) on delete cascade,
  name text not null,
  sort_order integer not null,
  created_at timestamptz not null default now(),
  constraint default_subcategories_name_nonempty check (btrim(name) <> ''),
  constraint default_subcategories_sort_order_positive check (sort_order > 0)
);

create table public.source_accounts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  type public.source_account_type not null,
  display_name text not null,
  institution_name text,
  masked_identifier text,
  cardholder_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint source_accounts_display_name_nonempty check (btrim(display_name) <> '')
);

create table public.linked_mailboxes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  email text not null,
  provider text not null default 'gmail',
  oauth_secret_ref text,
  gmail_history_id text,
  watch_expires_at timestamptz,
  last_sync_at timestamptz,
  last_error text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint linked_mailboxes_email_nonempty check (btrim(email) <> ''),
  constraint linked_mailboxes_provider_supported check (provider in ('gmail'))
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  source_type public.source_type not null,
  source_label text,
  status public.job_status not null default 'queued',
  started_at timestamptz,
  completed_at timestamptz,
  row_count integer not null default 0,
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  duplicate_count integer not null default 0,
  validation_summary jsonb not null default '{}'::jsonb,
  error_message text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint import_batches_counts_nonnegative check (
    row_count >= 0
    and inserted_count >= 0
    and updated_count >= 0
    and duplicate_count >= 0
  ),
  constraint import_batches_completed_after_started check (
    completed_at is null
    or started_at is null
    or completed_at >= started_at
  )
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  sort_order integer,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, household_id),
  constraint categories_name_nonempty check (btrim(name) <> '')
);

create table public.subcategories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  category_id uuid not null,
  name text not null,
  sort_order integer,
  created_at timestamptz not null default now(),
  unique (id, household_id),
  unique (id, category_id, household_id),
  constraint subcategories_category_household_fk foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete cascade,
  constraint subcategories_name_nonempty check (btrim(name) <> '')
);

create table public.category_caps (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  category_id uuid not null,
  period_month date not null,
  cap_amount numeric(14,2) not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, category_id, period_month),
  constraint category_caps_category_household_fk foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete cascade,
  constraint category_caps_period_month_first_day check (
    period_month = date_trunc('month', period_month)::date
  ),
  constraint category_caps_cap_amount_nonnegative check (cap_amount >= 0)
);

create table public.merchants (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  display_name text not null,
  category_id uuid,
  subcategory_id uuid,
  confidence public.confidence not null default 'medium',
  notes text,
  source_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint merchants_category_household_fk foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete set null (category_id),
  constraint merchants_subcategory_category_household_fk foreign key (subcategory_id, category_id, household_id)
    references public.subcategories (id, category_id, household_id) on delete set null (subcategory_id),
  constraint merchants_display_name_nonempty check (btrim(display_name) <> ''),
  constraint merchants_subcategory_requires_category check (
    subcategory_id is null or category_id is not null
  )
);

create table public.merchant_aliases (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  merchant_id uuid not null,
  raw_name text not null,
  normalized_name text not null,
  source_type public.source_type,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  constraint merchant_aliases_merchant_household_fk foreign key (merchant_id, household_id)
    references public.merchants (id, household_id) on delete cascade,
  constraint merchant_aliases_raw_name_nonempty check (btrim(raw_name) <> ''),
  constraint merchant_aliases_normalized_name_nonempty check (btrim(normalized_name) <> ''),
  constraint merchant_aliases_seen_order check (
    first_seen_at is null
    or last_seen_at is null
    or last_seen_at >= first_seen_at
  )
);

create table public.merchant_mapping_rules (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  pattern text not null,
  match_type text not null,
  merchant_id uuid,
  category_id uuid,
  subcategory_id uuid,
  priority integer not null default 100,
  confidence public.confidence not null default 'manual',
  apply_to_future boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint merchant_mapping_rules_merchant_household_fk foreign key (merchant_id, household_id)
    references public.merchants (id, household_id) on delete set null (merchant_id),
  constraint merchant_mapping_rules_category_household_fk foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete set null (category_id),
  constraint merchant_mapping_rules_subcategory_category_household_fk foreign key (subcategory_id, category_id, household_id)
    references public.subcategories (id, category_id, household_id) on delete set null (subcategory_id),
  constraint merchant_mapping_rules_pattern_nonempty check (btrim(pattern) <> ''),
  constraint merchant_mapping_rules_match_type_supported check (
    match_type in ('exact', 'contains', 'prefix', 'suffix', 'regex')
  ),
  constraint merchant_mapping_rules_subcategory_requires_category check (
    subcategory_id is null or category_id is not null
  )
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  source_account_id uuid,
  source_type public.source_type not null,
  occurred_at timestamptz,
  transaction_date date not null,
  transaction_time time,
  statement_month text,
  cardholder_name text,
  statement_merchant text not null,
  normalized_statement_merchant text not null,
  merchant_id uuid,
  category_id uuid,
  subcategory_id uuid,
  transaction_type public.transaction_type not null,
  amount numeric(14,2) not null,
  gross_spend numeric(14,2) not null default 0,
  refund_amount numeric(14,2) not null default 0,
  net_expense numeric(14,2) not null default 0,
  currency_code text not null default 'INR',
  confidence public.confidence not null default 'medium',
  notes text,
  source_fingerprint text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  unique (household_id, source_fingerprint),
  constraint transactions_source_account_household_fk foreign key (source_account_id, household_id)
    references public.source_accounts (id, household_id) on delete set null (source_account_id),
  constraint transactions_merchant_household_fk foreign key (merchant_id, household_id)
    references public.merchants (id, household_id) on delete set null (merchant_id),
  constraint transactions_category_household_fk foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete set null (category_id),
  constraint transactions_subcategory_category_household_fk foreign key (subcategory_id, category_id, household_id)
    references public.subcategories (id, category_id, household_id) on delete set null (subcategory_id),
  constraint transactions_statement_merchant_nonempty check (btrim(statement_merchant) <> ''),
  constraint transactions_normalized_statement_merchant_nonempty check (btrim(normalized_statement_merchant) <> ''),
  constraint transactions_source_fingerprint_nonempty check (btrim(source_fingerprint) <> ''),
  constraint transactions_currency_code_format check (currency_code ~ '^[A-Z]{3}$'),
  constraint transactions_money_components_nonnegative check (
    gross_spend >= 0 and refund_amount >= 0
  ),
  constraint transactions_net_expense_matches_components check (
    net_expense = gross_spend - refund_amount
  ),
  constraint transactions_type_money_shape check (
    (
      transaction_type = 'debit_spend'
      and gross_spend > 0
      and refund_amount = 0
      and net_expense = gross_spend
    )
    or (
      transaction_type = 'refund_reversal'
      and gross_spend = 0
      and refund_amount > 0
      and net_expense = -refund_amount
    )
    or (
      transaction_type = 'bill_payment_credit'
      and gross_spend = 0
      and refund_amount = 0
      and net_expense = 0
    )
    or transaction_type in ('adjustment', 'unknown')
  ),
  constraint transactions_subcategory_requires_category check (
    subcategory_id is null or category_id is not null
  )
);

create table public.transaction_sources (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  transaction_id uuid not null,
  import_batch_id uuid,
  source_type public.source_type not null,
  source_message_id text,
  source_thread_id text,
  source_reference text,
  source_received_at timestamptz,
  parser_name text,
  parser_version text,
  parse_status text,
  diagnostics jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint transaction_sources_transaction_household_fk foreign key (transaction_id, household_id)
    references public.transactions (id, household_id) on delete cascade,
  constraint transaction_sources_import_batch_household_fk foreign key (import_batch_id, household_id)
    references public.import_batches (id, household_id) on delete set null (import_batch_id)
);

create table public.review_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  transaction_id uuid,
  reason text not null,
  status public.review_status not null default 'open',
  suggested_merchant_id uuid,
  suggested_category_id uuid,
  suggested_subcategory_id uuid,
  resolved_by uuid references public.profiles (id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint review_items_transaction_household_fk foreign key (transaction_id, household_id)
    references public.transactions (id, household_id) on delete cascade,
  constraint review_items_suggested_merchant_household_fk foreign key (suggested_merchant_id, household_id)
    references public.merchants (id, household_id) on delete set null (suggested_merchant_id),
  constraint review_items_suggested_category_household_fk foreign key (suggested_category_id, household_id)
    references public.categories (id, household_id) on delete set null (suggested_category_id),
  constraint review_items_suggested_subcategory_category_household_fk foreign key (suggested_subcategory_id, suggested_category_id, household_id)
    references public.subcategories (id, category_id, household_id) on delete set null (suggested_subcategory_id),
  constraint review_items_reason_nonempty check (btrim(reason) <> ''),
  constraint review_items_subcategory_requires_category check (
    suggested_subcategory_id is null or suggested_category_id is not null
  ),
  constraint review_items_resolution_shape check (
    (status = 'open' and resolved_at is null)
    or status in ('resolved', 'dismissed')
  )
);

create table public.piggy_banks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  description text,
  target_amount numeric(14,2),
  target_date date,
  currency_code text not null default 'INR',
  is_archived boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint piggy_banks_name_nonempty check (btrim(name) <> ''),
  constraint piggy_banks_target_amount_nonnegative check (
    target_amount is null or target_amount >= 0
  ),
  constraint piggy_banks_currency_code_format check (currency_code ~ '^[A-Z]{3}$')
);

create table public.piggy_bank_entries (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  piggy_bank_id uuid not null,
  entry_type public.piggy_entry_type not null,
  amount numeric(14,2) not null,
  entry_date date not null,
  note text,
  linked_transaction_id uuid,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint piggy_bank_entries_piggy_bank_household_fk foreign key (piggy_bank_id, household_id)
    references public.piggy_banks (id, household_id) on delete cascade,
  constraint piggy_bank_entries_transaction_household_fk foreign key (linked_transaction_id, household_id)
    references public.transactions (id, household_id) on delete set null (linked_transaction_id),
  constraint piggy_bank_entries_amount_shape check (
    (entry_type in ('deposit', 'withdrawal') and amount > 0)
    or (entry_type = 'adjustment' and amount <> 0)
  )
);

create unique index default_categories_lower_name_key
  on public.default_categories (lower(name));
create unique index default_subcategories_category_lower_name_key
  on public.default_subcategories (default_category_id, lower(name));
create unique index categories_household_lower_name_key
  on public.categories (household_id, lower(name));
create unique index subcategories_category_lower_name_key
  on public.subcategories (category_id, lower(name));
create unique index merchant_aliases_household_normalized_name_key
  on public.merchant_aliases (household_id, normalized_name);

create index households_created_by_idx on public.households (created_by);
create index household_members_household_id_idx on public.household_members (household_id);
create index household_members_profile_id_idx on public.household_members (profile_id);
create index household_members_active_profile_idx
  on public.household_members (profile_id, household_id)
  where is_active;
create index source_accounts_household_id_idx on public.source_accounts (household_id);
create index linked_mailboxes_household_id_idx on public.linked_mailboxes (household_id);
create index linked_mailboxes_profile_id_idx on public.linked_mailboxes (profile_id);
create index import_batches_household_id_idx on public.import_batches (household_id);
create index import_batches_status_idx on public.import_batches (status);
create index categories_household_id_idx on public.categories (household_id);
create index subcategories_household_id_idx on public.subcategories (household_id);
create index subcategories_category_id_idx on public.subcategories (category_id);
create index category_caps_household_id_idx on public.category_caps (household_id);
create index category_caps_category_id_idx on public.category_caps (category_id);
create index category_caps_monthly_lookup_idx
  on public.category_caps (household_id, period_month, category_id);
create index merchants_household_id_idx on public.merchants (household_id);
create index merchants_category_id_idx on public.merchants (category_id);
create index merchants_subcategory_id_idx on public.merchants (subcategory_id);
create index merchants_household_display_name_idx on public.merchants (household_id, display_name);
create index merchant_aliases_household_id_idx on public.merchant_aliases (household_id);
create index merchant_aliases_merchant_id_idx on public.merchant_aliases (merchant_id);
create index merchant_aliases_normalized_name_idx on public.merchant_aliases (normalized_name);
create index merchant_mapping_rules_household_id_idx on public.merchant_mapping_rules (household_id);
create index merchant_mapping_rules_merchant_id_idx on public.merchant_mapping_rules (merchant_id);
create index merchant_mapping_rules_category_id_idx on public.merchant_mapping_rules (category_id);
create index merchant_mapping_rules_subcategory_id_idx on public.merchant_mapping_rules (subcategory_id);
create index merchant_mapping_rules_match_idx
  on public.merchant_mapping_rules (household_id, priority, match_type);
create index transactions_household_id_idx on public.transactions (household_id);
create index transactions_source_account_id_idx on public.transactions (source_account_id);
create index transactions_merchant_id_idx on public.transactions (merchant_id);
create index transactions_category_id_idx on public.transactions (category_id);
create index transactions_subcategory_id_idx on public.transactions (subcategory_id);
create index transactions_household_transaction_date_idx
  on public.transactions (household_id, transaction_date desc);
create index transactions_source_fingerprint_idx
  on public.transactions (source_fingerprint);
create index transactions_normalized_merchant_idx
  on public.transactions (household_id, normalized_statement_merchant);
create index transaction_sources_household_id_idx on public.transaction_sources (household_id);
create index transaction_sources_transaction_id_idx on public.transaction_sources (transaction_id);
create index transaction_sources_import_batch_id_idx on public.transaction_sources (import_batch_id);
create index transaction_sources_message_id_idx
  on public.transaction_sources (source_type, source_message_id)
  where source_message_id is not null;
create index review_items_household_id_idx on public.review_items (household_id);
create index review_items_transaction_id_idx on public.review_items (transaction_id);
create index review_items_suggested_merchant_id_idx on public.review_items (suggested_merchant_id);
create index review_items_suggested_category_id_idx on public.review_items (suggested_category_id);
create index review_items_suggested_subcategory_id_idx on public.review_items (suggested_subcategory_id);
create index review_items_open_queue_idx
  on public.review_items (household_id, created_at)
  where status = 'open';
create index piggy_banks_household_id_idx on public.piggy_banks (household_id);
create index piggy_bank_entries_household_id_idx on public.piggy_bank_entries (household_id);
create index piggy_bank_entries_piggy_bank_id_idx on public.piggy_bank_entries (piggy_bank_id);
create index piggy_bank_entries_linked_transaction_id_idx on public.piggy_bank_entries (linked_transaction_id);

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function app_private.set_updated_at();
create trigger set_households_updated_at
  before update on public.households
  for each row execute function app_private.set_updated_at();
create trigger set_source_accounts_updated_at
  before update on public.source_accounts
  for each row execute function app_private.set_updated_at();
create trigger set_linked_mailboxes_updated_at
  before update on public.linked_mailboxes
  for each row execute function app_private.set_updated_at();
create trigger set_import_batches_updated_at
  before update on public.import_batches
  for each row execute function app_private.set_updated_at();
create trigger set_category_caps_updated_at
  before update on public.category_caps
  for each row execute function app_private.set_updated_at();
create trigger set_merchants_updated_at
  before update on public.merchants
  for each row execute function app_private.set_updated_at();
create trigger set_merchant_mapping_rules_updated_at
  before update on public.merchant_mapping_rules
  for each row execute function app_private.set_updated_at();
create trigger set_transactions_updated_at
  before update on public.transactions
  for each row execute function app_private.set_updated_at();
create trigger set_piggy_banks_updated_at
  before update on public.piggy_banks
  for each row execute function app_private.set_updated_at();

create or replace function app_private.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = (select auth.uid())
  limit 1;
$$;

create or replace function app_private.active_household_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.household_id
  from public.household_members hm
  join public.profiles p on p.id = hm.profile_id
  where p.auth_user_id = (select auth.uid())
    and hm.is_active;
$$;

create or replace function app_private.write_household_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.household_id
  from public.household_members hm
  join public.profiles p on p.id = hm.profile_id
  where p.auth_user_id = (select auth.uid())
    and hm.is_active
    and hm.role in ('owner', 'admin', 'member');
$$;

create or replace function app_private.admin_household_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.household_id
  from public.household_members hm
  join public.profiles p on p.id = hm.profile_id
  where p.auth_user_id = (select auth.uid())
    and hm.is_active
    and hm.role in ('owner', 'admin');
$$;

create or replace function app_private.owner_household_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.household_id
  from public.household_members hm
  join public.profiles p on p.id = hm.profile_id
  where p.auth_user_id = (select auth.uid())
    and hm.is_active
    and hm.role = 'owner';
$$;

create or replace function app_private.active_household_profile_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select distinct hm.profile_id
  from public.household_members hm
  where hm.is_active
    and hm.household_id in (select app_private.active_household_ids());
$$;

create or replace function app_private.household_has_members(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
  );
$$;

create or replace function app_private.household_created_by_current_user(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.households h
    where h.id = target_household_id
      and h.created_by = app_private.current_profile_id()
  );
$$;

revoke all on all functions in schema app_private from public;
grant usage on schema app_private to authenticated, service_role;
grant execute on function app_private.current_profile_id() to authenticated, service_role;
grant execute on function app_private.active_household_ids() to authenticated, service_role;
grant execute on function app_private.write_household_ids() to authenticated, service_role;
grant execute on function app_private.admin_household_ids() to authenticated, service_role;
grant execute on function app_private.owner_household_ids() to authenticated, service_role;
grant execute on function app_private.active_household_profile_ids() to authenticated, service_role;
grant execute on function app_private.household_has_members(uuid) to authenticated, service_role;
grant execute on function app_private.household_created_by_current_user(uuid) to authenticated, service_role;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.default_categories enable row level security;
alter table public.default_subcategories enable row level security;
alter table public.source_accounts enable row level security;
alter table public.linked_mailboxes enable row level security;
alter table public.import_batches enable row level security;
alter table public.categories enable row level security;
alter table public.subcategories enable row level security;
alter table public.category_caps enable row level security;
alter table public.merchants enable row level security;
alter table public.merchant_aliases enable row level security;
alter table public.merchant_mapping_rules enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_sources enable row level security;
alter table public.review_items enable row level security;
alter table public.piggy_banks enable row level security;
alter table public.piggy_bank_entries enable row level security;

create policy "profiles_select_household_or_self"
  on public.profiles
  for select
  to authenticated
  using (
    auth_user_id = (select auth.uid())
    or id in (select app_private.active_household_profile_ids())
  );

create policy "profiles_insert_self"
  on public.profiles
  for insert
  to authenticated
  with check (auth_user_id = (select auth.uid()));

create policy "profiles_update_self"
  on public.profiles
  for update
  to authenticated
  using (auth_user_id = (select auth.uid()))
  with check (auth_user_id = (select auth.uid()));

create policy "households_select_members"
  on public.households
  for select
  to authenticated
  using (id in (select app_private.active_household_ids()));

create policy "households_insert_creator"
  on public.households
  for insert
  to authenticated
  with check (created_by = app_private.current_profile_id());

create policy "households_update_admins"
  on public.households
  for update
  to authenticated
  using (id in (select app_private.admin_household_ids()))
  with check (id in (select app_private.admin_household_ids()));

create policy "households_delete_owners"
  on public.households
  for delete
  to authenticated
  using (id in (select app_private.owner_household_ids()));

create policy "household_members_select_self_or_admins"
  on public.household_members
  for select
  to authenticated
  using (
    profile_id = app_private.current_profile_id()
    or household_id in (select app_private.admin_household_ids())
  );

create policy "household_members_insert_first_owner_or_admins"
  on public.household_members
  for insert
  to authenticated
  with check (
    (
      profile_id = app_private.current_profile_id()
      and role = 'owner'
      and app_private.household_created_by_current_user(household_id)
      and not app_private.household_has_members(household_id)
    )
    or household_id in (select app_private.owner_household_ids())
    or (
      household_id in (select app_private.admin_household_ids())
      and role in ('member', 'viewer')
    )
  );

create policy "household_members_update_admins"
  on public.household_members
  for update
  to authenticated
  using (
    household_id in (select app_private.owner_household_ids())
    or (
      household_id in (select app_private.admin_household_ids())
      and role in ('member', 'viewer')
    )
  )
  with check (
    household_id in (select app_private.owner_household_ids())
    or (
      household_id in (select app_private.admin_household_ids())
      and role in ('member', 'viewer')
    )
  );

create policy "household_members_delete_admins"
  on public.household_members
  for delete
  to authenticated
  using (
    household_id in (select app_private.owner_household_ids())
    or (
      household_id in (select app_private.admin_household_ids())
      and role in ('member', 'viewer')
    )
  );

create policy "default_categories_select_all"
  on public.default_categories
  for select
  to anon, authenticated
  using (true);

create policy "default_subcategories_select_all"
  on public.default_subcategories
  for select
  to anon, authenticated
  using (true);

create policy "source_accounts_select_members"
  on public.source_accounts
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "source_accounts_insert_writers"
  on public.source_accounts
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "source_accounts_update_writers"
  on public.source_accounts
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "source_accounts_delete_admins"
  on public.source_accounts
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "linked_mailboxes_select_members"
  on public.linked_mailboxes
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "linked_mailboxes_insert_own_profile"
  on public.linked_mailboxes
  for insert
  to authenticated
  with check (
    profile_id = app_private.current_profile_id()
    and household_id in (select app_private.write_household_ids())
  );
create policy "linked_mailboxes_update_own_profile_or_admins"
  on public.linked_mailboxes
  for update
  to authenticated
  using (
    (
      profile_id = app_private.current_profile_id()
      and household_id in (select app_private.write_household_ids())
    )
    or household_id in (select app_private.admin_household_ids())
  )
  with check (
    (
      profile_id = app_private.current_profile_id()
      and household_id in (select app_private.write_household_ids())
    )
    or household_id in (select app_private.admin_household_ids())
  );
create policy "linked_mailboxes_delete_own_profile_or_admins"
  on public.linked_mailboxes
  for delete
  to authenticated
  using (
    (
      profile_id = app_private.current_profile_id()
      and household_id in (select app_private.write_household_ids())
    )
    or household_id in (select app_private.admin_household_ids())
  );

create policy "import_batches_select_members"
  on public.import_batches
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "import_batches_insert_writers"
  on public.import_batches
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "import_batches_update_writers"
  on public.import_batches
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "import_batches_delete_admins"
  on public.import_batches
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "categories_select_members"
  on public.categories
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "categories_insert_writers"
  on public.categories
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "categories_update_writers"
  on public.categories
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "categories_delete_admins"
  on public.categories
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "subcategories_select_members"
  on public.subcategories
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "subcategories_insert_writers"
  on public.subcategories
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "subcategories_update_writers"
  on public.subcategories
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "subcategories_delete_admins"
  on public.subcategories
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "category_caps_select_members"
  on public.category_caps
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "category_caps_insert_writers"
  on public.category_caps
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "category_caps_update_writers"
  on public.category_caps
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "category_caps_delete_admins"
  on public.category_caps
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "merchants_select_members"
  on public.merchants
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "merchants_insert_writers"
  on public.merchants
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchants_update_writers"
  on public.merchants
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchants_delete_admins"
  on public.merchants
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "merchant_aliases_select_members"
  on public.merchant_aliases
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "merchant_aliases_insert_writers"
  on public.merchant_aliases
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchant_aliases_update_writers"
  on public.merchant_aliases
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchant_aliases_delete_admins"
  on public.merchant_aliases
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "merchant_mapping_rules_select_members"
  on public.merchant_mapping_rules
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "merchant_mapping_rules_insert_writers"
  on public.merchant_mapping_rules
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchant_mapping_rules_update_writers"
  on public.merchant_mapping_rules
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "merchant_mapping_rules_delete_admins"
  on public.merchant_mapping_rules
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "transactions_select_members"
  on public.transactions
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "transactions_insert_writers"
  on public.transactions
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "transactions_update_writers"
  on public.transactions
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "transactions_delete_admins"
  on public.transactions
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "transaction_sources_select_members"
  on public.transaction_sources
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "transaction_sources_insert_writers"
  on public.transaction_sources
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "transaction_sources_update_writers"
  on public.transaction_sources
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "transaction_sources_delete_admins"
  on public.transaction_sources
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "review_items_select_members"
  on public.review_items
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "review_items_insert_writers"
  on public.review_items
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "review_items_update_writers"
  on public.review_items
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "review_items_delete_admins"
  on public.review_items
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "piggy_banks_select_members"
  on public.piggy_banks
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "piggy_banks_insert_writers"
  on public.piggy_banks
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "piggy_banks_update_writers"
  on public.piggy_banks
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "piggy_banks_delete_admins"
  on public.piggy_banks
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create policy "piggy_bank_entries_select_members"
  on public.piggy_bank_entries
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "piggy_bank_entries_insert_writers"
  on public.piggy_bank_entries
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "piggy_bank_entries_update_writers"
  on public.piggy_bank_entries
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "piggy_bank_entries_delete_admins"
  on public.piggy_bank_entries
  for delete
  to authenticated
  using (household_id in (select app_private.admin_household_ids()));

create view public.v_monthly_spend
with (security_invoker = true)
as
select
  t.household_id,
  date_trunc('month', t.transaction_date)::date as period_month,
  count(*)::integer as transaction_count,
  count(*) filter (where t.transaction_type = 'debit_spend')::integer as debit_count,
  count(*) filter (where t.transaction_type = 'refund_reversal')::integer as refund_count,
  sum(t.gross_spend)::numeric(14,2) as gross_spend,
  sum(t.refund_amount)::numeric(14,2) as refund_amount,
  sum(t.net_expense)::numeric(14,2) as net_spend,
  sum(
    case
      when t.transaction_type = 'bill_payment_credit' then abs(t.amount)
      else 0
    end
  )::numeric(14,2) as bill_payments
from public.transactions t
group by t.household_id, date_trunc('month', t.transaction_date)::date;

create view public.v_category_monthly_spend
with (security_invoker = true)
as
select
  t.household_id,
  date_trunc('month', t.transaction_date)::date as period_month,
  t.category_id,
  c.name as category_name,
  count(*)::integer as transaction_count,
  sum(t.gross_spend)::numeric(14,2) as gross_spend,
  sum(t.refund_amount)::numeric(14,2) as refund_amount,
  sum(t.net_expense)::numeric(14,2) as net_spend
from public.transactions t
left join public.categories c on c.id = t.category_id and c.household_id = t.household_id
where t.category_id is not null
group by t.household_id, date_trunc('month', t.transaction_date)::date, t.category_id, c.name;

create view public.v_budget_progress
with (security_invoker = true)
as
select
  cc.household_id,
  cc.period_month,
  cc.category_id,
  c.name as category_name,
  cc.cap_amount,
  coalesce(cms.net_spend, 0)::numeric(14,2) as spent_amount,
  (cc.cap_amount - coalesce(cms.net_spend, 0))::numeric(14,2) as remaining_amount,
  case
    when cc.cap_amount > 0 then round(coalesce(cms.net_spend, 0) / cc.cap_amount, 4)
    else null
  end as percent_used,
  coalesce(cms.net_spend, 0) > cc.cap_amount as is_over_budget
from public.category_caps cc
join public.categories c on c.id = cc.category_id and c.household_id = cc.household_id
left join public.v_category_monthly_spend cms
  on cms.household_id = cc.household_id
  and cms.category_id = cc.category_id
  and cms.period_month = cc.period_month;

create view public.v_merchant_summary
with (security_invoker = true)
as
select
  t.household_id,
  t.merchant_id,
  coalesce(m.display_name, t.normalized_statement_merchant) as merchant_name,
  t.category_id,
  c.name as category_name,
  t.subcategory_id,
  sc.name as subcategory_name,
  count(*)::integer as transaction_count,
  min(t.transaction_date) as first_transaction_date,
  max(t.transaction_date) as last_transaction_date,
  sum(t.gross_spend)::numeric(14,2) as gross_spend,
  sum(t.refund_amount)::numeric(14,2) as refund_amount,
  sum(t.net_expense)::numeric(14,2) as net_spend
from public.transactions t
left join public.merchants m on m.id = t.merchant_id and m.household_id = t.household_id
left join public.categories c on c.id = t.category_id and c.household_id = t.household_id
left join public.subcategories sc on sc.id = t.subcategory_id and sc.household_id = t.household_id
group by
  t.household_id,
  t.merchant_id,
  coalesce(m.display_name, t.normalized_statement_merchant),
  t.category_id,
  c.name,
  t.subcategory_id,
  sc.name;

create view public.v_review_queue
with (security_invoker = true)
as
select
  ri.id,
  ri.household_id,
  ri.transaction_id,
  ri.reason,
  ri.status,
  ri.created_at,
  t.transaction_date,
  t.statement_merchant,
  t.normalized_statement_merchant,
  t.amount,
  t.net_expense,
  t.confidence as transaction_confidence,
  ri.suggested_merchant_id,
  sm.display_name as suggested_merchant_name,
  ri.suggested_category_id,
  sc.name as suggested_category_name,
  ri.suggested_subcategory_id,
  ssc.name as suggested_subcategory_name
from public.review_items ri
left join public.transactions t on t.id = ri.transaction_id and t.household_id = ri.household_id
left join public.merchants sm on sm.id = ri.suggested_merchant_id and sm.household_id = ri.household_id
left join public.categories sc on sc.id = ri.suggested_category_id and sc.household_id = ri.household_id
left join public.subcategories ssc on ssc.id = ri.suggested_subcategory_id and ssc.household_id = ri.household_id
where ri.status = 'open';

create view public.v_piggy_bank_balances
with (security_invoker = true)
as
select
  pb.id,
  pb.household_id,
  pb.name,
  pb.description,
  pb.target_amount,
  pb.target_date,
  pb.currency_code,
  pb.is_archived,
  pb.created_by,
  pb.created_at,
  pb.updated_at,
  coalesce(
    sum(
      case pbe.entry_type
        when 'deposit' then pbe.amount
        when 'withdrawal' then -pbe.amount
        when 'adjustment' then pbe.amount
      end
    ),
    0
  )::numeric(14,2) as balance_amount,
  case
    when pb.target_amount is not null and pb.target_amount > 0 then
      round(
        coalesce(
          sum(
            case pbe.entry_type
              when 'deposit' then pbe.amount
              when 'withdrawal' then -pbe.amount
              when 'adjustment' then pbe.amount
            end
          ),
          0
        ) / pb.target_amount,
        4
      )
    else null
  end as target_progress
from public.piggy_banks pb
left join public.piggy_bank_entries pbe
  on pbe.piggy_bank_id = pb.id
  and pbe.household_id = pb.household_id
group by
  pb.id,
  pb.household_id,
  pb.name,
  pb.description,
  pb.target_amount,
  pb.target_date,
  pb.currency_code,
  pb.is_archived,
  pb.created_by,
  pb.created_at,
  pb.updated_at;

revoke select, insert, update, delete on all tables in schema public from anon, authenticated;
revoke usage, select on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated, service_role;

grant usage on schema public to anon, authenticated, service_role;

grant select on public.default_categories to anon, authenticated;
grant select on public.default_subcategories to anon, authenticated;

grant select, insert on public.profiles to authenticated;
grant update (display_name, email) on public.profiles to authenticated;
grant select, insert, delete on public.households to authenticated;
grant update (name, currency_code) on public.households to authenticated;
grant select, insert, delete on public.household_members to authenticated;
grant update (role, is_active) on public.household_members to authenticated;

grant select, insert, update, delete on public.source_accounts to authenticated;
grant select (
  id,
  household_id,
  profile_id,
  email,
  provider,
  gmail_history_id,
  watch_expires_at,
  last_sync_at,
  last_error,
  is_active,
  created_at,
  updated_at
) on public.linked_mailboxes to authenticated;
grant insert (
  household_id,
  profile_id,
  email,
  provider,
  is_active
) on public.linked_mailboxes to authenticated;
grant update (
  email,
  is_active
) on public.linked_mailboxes to authenticated;
grant delete on public.linked_mailboxes to authenticated;
grant select, insert, update, delete on public.import_batches to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.subcategories to authenticated;
grant select, insert, update, delete on public.category_caps to authenticated;
grant select, insert, update, delete on public.merchants to authenticated;
grant select, insert, update, delete on public.merchant_aliases to authenticated;
grant select, insert, update, delete on public.merchant_mapping_rules to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.transaction_sources to authenticated;
grant select, insert, update, delete on public.review_items to authenticated;
grant select, insert, update, delete on public.piggy_banks to authenticated;
grant select, insert, update, delete on public.piggy_bank_entries to authenticated;

grant select on public.v_monthly_spend to authenticated;
grant select on public.v_category_monthly_spend to authenticated;
grant select on public.v_budget_progress to authenticated;
grant select on public.v_merchant_summary to authenticated;
grant select on public.v_review_queue to authenticated;
grant select on public.v_piggy_bank_balances to authenticated;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
