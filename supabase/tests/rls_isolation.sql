begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(11);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname = any (array[
        'profiles',
        'households',
        'household_members',
        'source_accounts',
        'linked_mailboxes',
        'import_batches',
        'categories',
        'subcategories',
        'category_caps',
        'labels',
        'transaction_labels',
        'monthly_caps',
        'monthly_cap_categories',
        'monthly_cap_labels',
        'merchants',
        'merchant_aliases',
        'merchant_mapping_rules',
        'transactions',
        'deleted_transaction_sources',
        'transaction_sources',
        'review_items',
        'piggy_banks',
        'piggy_bank_entries',
        'ai_feature_settings',
        'ai_usage_events',
        'ai_jobs'
      ])
      and not c.relrowsecurity
  ),
  0,
  'all app-accessible finance tables have RLS enabled'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
      and c.relname = any (array[
        'v_monthly_spend',
        'v_category_monthly_spend',
        'v_budget_progress',
        'v_label_usage',
        'v_monthly_cap_progress',
        'v_merchant_summary',
        'v_review_queue',
        'v_piggy_bank_balances',
        'v_linked_mailbox_status',
        'v_ai_budget_status'
      ])
      and not (coalesce(c.reloptions, array[]::text[]) @> array['security_invoker=true'])
  ),
  0,
  'client summary views are security_invoker views'
);

insert into auth.users (id)
values
  ('10000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'RLS User A', 'rls-a@example.test'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'RLS User B', 'rls-b@example.test');

insert into public.households (id, name, created_by)
values
  ('30000000-0000-0000-0000-000000000001', 'Household A', '20000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000002', 'Household B', '20000000-0000-0000-0000-000000000002');

insert into public.household_members (id, household_id, profile_id, role)
values
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'owner'),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'owner');

insert into public.categories (id, household_id, name, sort_order)
values
  ('50000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Dining', 1),
  ('50000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'Dining', 1);

insert into public.transactions (
  id,
  household_id,
  source_type,
  transaction_date,
  statement_merchant,
  normalized_statement_merchant,
  category_id,
  transaction_type,
  amount,
  gross_spend,
  refund_amount,
  net_expense,
  source_fingerprint
)
values
  (
    '60000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'manual',
    '2026-01-05',
    'A DINING ONE',
    'a dining one',
    '50000000-0000-0000-0000-000000000001',
    'debit_spend',
    120.00,
    120.00,
    0.00,
    120.00,
    'rls-a-1'
  ),
  (
    '60000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    'manual',
    '2026-01-06',
    'A DINING TWO',
    'a dining two',
    '50000000-0000-0000-0000-000000000001',
    'debit_spend',
    80.00,
    80.00,
    0.00,
    80.00,
    'rls-a-2'
  ),
  (
    '60000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000002',
    'manual',
    '2026-01-07',
    'B DINING ONE',
    'b dining one',
    '50000000-0000-0000-0000-000000000002',
    'debit_spend',
    300.00,
    300.00,
    0.00,
    300.00,
    'rls-b-1'
  );

set local role authenticated;
set local request.jwt.claim.sub = '10000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is((select count(*)::integer from public.transactions), 2, 'user A reads only their household transactions');
select is((select count(*)::integer from public.transactions where household_id = '30000000-0000-0000-0000-000000000002'), 0, 'user A cannot read household B transactions');
select is((select count(*)::integer from public.households), 1, 'user A reads one household');
select is((select count(*)::integer from public.v_monthly_spend), 1, 'user A summary view is scoped by RLS');
select is((select count(*)::integer from public.v_monthly_spend where household_id = '30000000-0000-0000-0000-000000000002'), 0, 'user A cannot read household B summary rows');

set local request.jwt.claim.sub = '10000000-0000-0000-0000-000000000002';

select is((select count(*)::integer from public.transactions), 1, 'user B reads only their household transactions');
select is((select count(*)::integer from public.transactions where household_id = '30000000-0000-0000-0000-000000000001'), 0, 'user B cannot read household A transactions');
select is((select gross_spend from public.v_monthly_spend), 300.00::numeric(14,2), 'user B summary totals include only household B');
select is(
  (
    select count(*)::integer
    from public.categories
    where household_id = '30000000-0000-0000-0000-000000000001'
  ),
  0,
  'user B cannot read household A categories'
);

select * from finish();

rollback;
