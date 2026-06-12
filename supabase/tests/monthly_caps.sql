begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(24);

insert into auth.users (id)
values
  ('19000000-0000-0000-0000-000000000001'),
  ('19000000-0000-0000-0000-000000000002'),
  ('19000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '29000000-0000-0000-0000-000000000001',
    '19000000-0000-0000-0000-000000000001',
    'Cap Owner',
    'cap-owner@example.test'
  ),
  (
    '29000000-0000-0000-0000-000000000002',
    '19000000-0000-0000-0000-000000000002',
    'Cap Viewer',
    'cap-viewer@example.test'
  ),
  (
    '29000000-0000-0000-0000-000000000003',
    '19000000-0000-0000-0000-000000000003',
    'Cap Outsider',
    'cap-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '39000000-0000-0000-0000-000000000001',
    'Monthly Cap Household',
    '29000000-0000-0000-0000-000000000001'
  ),
  (
    '39000000-0000-0000-0000-000000000002',
    'Other Cap Household',
    '29000000-0000-0000-0000-000000000003'
  );

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '49000000-0000-0000-0000-000000000001',
    '39000000-0000-0000-0000-000000000001',
    '29000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '49000000-0000-0000-0000-000000000002',
    '39000000-0000-0000-0000-000000000001',
    '29000000-0000-0000-0000-000000000002',
    'viewer'
  ),
  (
    '49000000-0000-0000-0000-000000000003',
    '39000000-0000-0000-0000-000000000002',
    '29000000-0000-0000-0000-000000000003',
    'owner'
  );

delete from public.subcategories
where household_id in (
  '39000000-0000-0000-0000-000000000001',
  '39000000-0000-0000-0000-000000000002'
);

delete from public.categories
where household_id in (
  '39000000-0000-0000-0000-000000000001',
  '39000000-0000-0000-0000-000000000002'
);

insert into public.categories (id, household_id, name, sort_order)
values
  ('59000000-0000-0000-0000-000000000001', '39000000-0000-0000-0000-000000000001', 'Food', 1),
  ('59000000-0000-0000-0000-000000000002', '39000000-0000-0000-0000-000000000001', 'Travel', 2),
  ('59000000-0000-0000-0000-000000000003', '39000000-0000-0000-0000-000000000002', 'Other Food', 1);

insert into public.labels (id, household_id, name, created_by)
values
  ('89000000-0000-0000-0000-000000000001', '39000000-0000-0000-0000-000000000001', 'Groceries', '29000000-0000-0000-0000-000000000001'),
  ('89000000-0000-0000-0000-000000000002', '39000000-0000-0000-0000-000000000001', 'Reimburse', '29000000-0000-0000-0000-000000000001'),
  ('89000000-0000-0000-0000-000000000003', '39000000-0000-0000-0000-000000000002', 'Other Label', '29000000-0000-0000-0000-000000000003');

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
  confidence,
  source_fingerprint
)
values
  (
    '79000000-0000-0000-0000-000000000001',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-05-05',
    'GROCERY MART',
    'grocery mart',
    '59000000-0000-0000-0000-000000000001',
    'debit_spend',
    1000.00,
    1000.00,
    0.00,
    1000.00,
    'high',
    'monthly-cap-food-label'
  ),
  (
    '79000000-0000-0000-0000-000000000002',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-05-08',
    'AIRLINE',
    'airline',
    '59000000-0000-0000-0000-000000000002',
    'debit_spend',
    500.00,
    500.00,
    0.00,
    500.00,
    'medium',
    'monthly-cap-travel'
  ),
  (
    '79000000-0000-0000-0000-000000000003',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-06-02',
    'JUNE GROCERY',
    'june grocery',
    '59000000-0000-0000-0000-000000000001',
    'debit_spend',
    700.00,
    700.00,
    0.00,
    700.00,
    'medium',
    'monthly-cap-next-month'
  );

insert into public.transaction_labels (
  household_id,
  transaction_id,
  label_id,
  created_by
)
values
  (
    '39000000-0000-0000-0000-000000000001',
    '79000000-0000-0000-0000-000000000001',
    '89000000-0000-0000-0000-000000000001',
    '29000000-0000-0000-0000-000000000001'
  );

set local role authenticated;
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

create temporary table category_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Food cap',
  p_period_month => '2026-05-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
);

select is((select name from category_cap), 'Food cap', 'upsert creates a named category cap');
select is((select category_target_names[1] from category_cap), 'Food', 'upsert returns ordered category targets');

create temporary table label_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Grocery label',
  p_period_month => '2026-05-01',
  p_cap_amount => 900.00,
  p_label_ids => array['89000000-0000-0000-0000-000000000001'::uuid]
);

select is((select label_target_names[1] from label_cap), 'Groceries', 'upsert returns ordered label targets');

create temporary table mixed_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Food or grocery',
  p_period_month => '2026-05-01',
  p_cap_amount => 1500.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_label_ids => array['89000000-0000-0000-0000-000000000001'::uuid]
);

select is(
  (
    select matched_transaction_count
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from mixed_cap)
  ),
  1,
  'mixed category and label cap counts one matching transaction once'
);

select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from mixed_cap)
  ),
  1000.00::numeric(14,2),
  'mixed category and label cap uses net expense once'
);

create temporary table overlapping_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Food overlap',
  p_period_month => '2026-05-01',
  p_cap_amount => 2000.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
);

select is(
  (
    select count(*)::integer
    from public.v_monthly_cap_progress
    where monthly_cap_id in (
      (select monthly_cap_id from category_cap),
      (select monthly_cap_id from overlapping_cap)
    )
      and spent_amount = 1000.00
  ),
  2,
  'overlapping caps can both include the same transaction'
);

select is(
  (
    select is_over_budget
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from label_cap)
  ),
  true,
  'label-only cap can be over budget'
);

select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from category_cap)
  ),
  1000.00::numeric(14,2),
  'category-only cap progress excludes other categories and months'
);

update public.categories
set name = 'Meals'
where id = '59000000-0000-0000-0000-000000000001';

select is(
  (
    select category_target_names[1]
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from mixed_cap)
  ),
  'Meals',
  'monthly cap progress reflects category target renames'
);

create temporary table renamed_grocery_label as
select *
from public.rename_household_label(
  '39000000-0000-0000-0000-000000000001',
  '89000000-0000-0000-0000-000000000001',
  'Pantry'
);

select is(
  (
    select label_target_names[1]
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from label_cap)
  ),
  'Pantry',
  'monthly cap progress reflects label target renames'
);

create temporary table travel_label_assignment as
select *
from public.set_transaction_labels(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_transaction_id => '79000000-0000-0000-0000-000000000002',
  p_label_ids => array['89000000-0000-0000-0000-000000000001'::uuid]
);

select is(
  (
    select matched_transaction_count
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from label_cap)
  ),
  2,
  'label-only cap progress follows transaction label assignment changes'
);

select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from label_cap)
  ),
  1500.00::numeric(14,2),
  'label-only cap spent follows transaction label assignment changes'
);

create temporary table updated_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_monthly_cap_id => (select monthly_cap_id from category_cap),
  p_name => 'Travel cap',
  p_period_month => '2026-05-01',
  p_cap_amount => 700.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000002'::uuid]
);

select is((select category_target_names[1] from updated_cap), 'Travel', 'upsert replaces category targets');
select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = (select monthly_cap_id from updated_cap)
  ),
  500.00::numeric(14,2),
  'updated cap progress uses replacement targets'
);

select throws_ok(
  $$
    select *
    from public.upsert_monthly_cap(
      p_household_id => '39000000-0000-0000-0000-000000000001',
      p_name => 'No targets',
      p_period_month => '2026-05-01',
      p_cap_amount => 100.00
    )
  $$,
  'P0001',
  'At least one category or label target is required.',
  'upsert rejects caps without targets'
);

select throws_ok(
  $$
    select *
    from public.upsert_monthly_cap(
      p_household_id => '39000000-0000-0000-0000-000000000001',
      p_name => 'Wrong category',
      p_period_month => '2026-05-01',
      p_cap_amount => 100.00,
      p_category_ids => array['59000000-0000-0000-0000-000000000003'::uuid]
    )
  $$,
  'P0001',
  'Categories must belong to this household.',
  'upsert rejects cross-household category targets'
);

select throws_ok(
  $$
    select *
    from public.upsert_monthly_cap(
      p_household_id => '39000000-0000-0000-0000-000000000001',
      p_name => 'Wrong label',
      p_period_month => '2026-05-01',
      p_cap_amount => 100.00,
      p_label_ids => array['89000000-0000-0000-0000-000000000003'::uuid]
    )
  $$,
  'P0001',
  'Labels must belong to this household.',
  'upsert rejects cross-household label targets'
);

select throws_ok(
  $$
    select *
    from public.upsert_monthly_cap(
      p_household_id => '39000000-0000-0000-0000-000000000001',
      p_name => 'Bad month',
      p_period_month => '2026-05-02',
      p_cap_amount => 100.00,
      p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
    )
  $$,
  'P0001',
  'Monthly cap period must be the first day of the month.',
  'upsert validates first-day period month'
);

create temporary table deleted_cap as
select *
from public.delete_monthly_cap(
  '39000000-0000-0000-0000-000000000001',
  (select monthly_cap_id from overlapping_cap)
);

select is((select monthly_cap_id from deleted_cap), (select monthly_cap_id from overlapping_cap), 'delete_monthly_cap returns deleted cap id');
select is(
  (
    select count(*)::integer
    from public.monthly_cap_categories
    where monthly_cap_id = (select monthly_cap_id from overlapping_cap)
  ),
  0,
  'delete_monthly_cap removes targets through cascade'
);

set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000002';

select throws_ok(
  $$
    select *
    from public.upsert_monthly_cap(
      p_household_id => '39000000-0000-0000-0000-000000000001',
      p_name => 'Viewer blocked',
      p_period_month => '2026-05-01',
      p_cap_amount => 100.00,
      p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
    )
  $$,
  'P0001',
  'You do not have permission to save monthly caps for this household.',
  'viewers cannot mutate monthly caps'
);

select is(
  (
    select count(*)::integer
    from public.v_monthly_cap_progress
    where household_id = '39000000-0000-0000-0000-000000000001'
  ),
  3,
  'household viewers can select monthly cap progress'
);

set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.delete_monthly_cap(
      '39000000-0000-0000-0000-000000000001',
      (select monthly_cap_id from label_cap)
    )
  $$,
  'P0001',
  'You do not have permission to delete monthly caps for this household.',
  'non-members cannot delete monthly caps'
);

select is(
  (
    select count(*)::integer
    from public.v_monthly_cap_progress
    where household_id = '39000000-0000-0000-0000-000000000001'
  ),
  0,
  'RLS hides monthly cap progress from non-members'
);

select * from finish();

rollback;
