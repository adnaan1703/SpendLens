begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(55);

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

create temporary table recurring_edit_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Recurring food',
  p_period_month => '2026-05-01',
  p_cap_amount => 1100.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
);

select ok(
  (select monthly_cap_version_id is not null from recurring_edit_cap),
  'upsert returns the active monthly cap version id'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_series
    where id = (select monthly_cap_id from recurring_edit_cap)
  ),
  1,
  'upsert creates a stable recurring cap series'
);

create temporary table recurring_edit_june as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_monthly_cap_id => (select monthly_cap_id from recurring_edit_cap),
  p_name => 'Recurring food',
  p_period_month => '2026-06-01',
  p_cap_amount => 600.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid]
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_versions
    where monthly_cap_series_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  2,
  'editing a future month creates a new cap version'
);

select is(
  (
    select cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-05-01'
    )
    where monthly_cap_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  1100.00::numeric(14,2),
  'future-month edits leave prior-month cap amount unchanged'
);

select is(
  (
    select cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  600.00::numeric(14,2),
  'future-month edits apply the new cap amount in the selected month'
);

select is(
  (
    select spent_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  700.00::numeric(14,2),
  'exact-month recurring progress uses transactions from the requested month'
);

create temporary table future_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Future travel',
  p_period_month => '2026-07-01',
  p_cap_amount => 300.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000002'::uuid]
);

select is(
  (
    select spent_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-07-01'
    )
    where monthly_cap_id = (select monthly_cap_id from future_cap)
  ),
  0.00::numeric(14,2),
  'exact-month recurring progress returns caps even without transactions'
);

select ok(
  exists (
    select 1
    from public.get_available_reporting_months(
      '39000000-0000-0000-0000-000000000001'
    )
    where period_month = '2026-07-01'
  ),
  'available reporting months include recurring cap months without transactions'
);

insert into public.categories (id, household_id, name, sort_order)
values
  ('59000000-0000-0000-0000-000000000004', '39000000-0000-0000-0000-000000000001', 'Unused', 10),
  ('59000000-0000-0000-0000-000000000005', '39000000-0000-0000-0000-000000000001', 'Source Merge', 11),
  ('59000000-0000-0000-0000-000000000006', '39000000-0000-0000-0000-000000000001', 'Destination Merge', 12);

create temporary table unused_category_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Unused category cap',
  p_period_month => '2026-08-01',
  p_cap_amount => 100.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000004'::uuid]
);

create temporary table deleted_unused_category as
select *
from public.delete_household_category(
  '39000000-0000-0000-0000-000000000001',
  '59000000-0000-0000-0000-000000000004'
);

select is((select deleted_cap_count from deleted_unused_category), 1, 'category delete removes versioned caps left without targets');
select is(
  (
    select count(*)::integer
    from public.monthly_cap_series
    where id = (select monthly_cap_id from unused_category_cap)
  ),
  0,
  'category delete prunes orphan recurring cap series'
);

create temporary table source_merge_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Source merge cap',
  p_period_month => '2026-08-01',
  p_cap_amount => 100.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000005'::uuid]
);

create temporary table merged_unused_category as
select *
from public.merge_household_categories(
  '39000000-0000-0000-0000-000000000001',
  '59000000-0000-0000-0000-000000000006',
  'Destination Merge',
  array['59000000-0000-0000-0000-000000000005'::uuid],
  '[]'::jsonb
);

select is((select merged_cap_count from merged_unused_category), 1, 'category merge reports versioned cap target repoints');
select is(
  (
    select count(*)::integer
    from public.monthly_cap_version_categories
    where monthly_cap_version_id = (
      select monthly_cap_version_id from source_merge_cap
    )
      and category_id = '59000000-0000-0000-0000-000000000006'
  ),
  1,
  'category merge repoints versioned category targets'
);

create temporary table reimburse_label_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Reimburse label cap',
  p_period_month => '2026-08-01',
  p_cap_amount => 100.00,
  p_label_ids => array['89000000-0000-0000-0000-000000000002'::uuid]
);

create temporary table deleted_reimburse_label as
select *
from public.delete_household_label(
  '39000000-0000-0000-0000-000000000001',
  '89000000-0000-0000-0000-000000000002'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_version_labels
    where monthly_cap_version_id = (
      select monthly_cap_version_id from reimburse_label_cap
    )
  ),
  0,
  'label delete removes versioned label targets'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_series
    where id = (select monthly_cap_id from reimburse_label_cap)
  ),
  0,
  'label delete prunes orphan recurring cap series'
);

create temporary table stopped_recurring_cap as
select *
from public.delete_monthly_cap(
  '39000000-0000-0000-0000-000000000001',
  (select monthly_cap_id from recurring_edit_cap),
  '2026-06-01'
);

select is(
  (
    select count(*)::integer
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-05-01'
    )
    where monthly_cap_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  1,
  'delete_monthly_cap preserves prior recurring months'
);

select is(
  (
    select count(*)::integer
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from recurring_edit_cap)
  ),
  0,
  'delete_monthly_cap hides the selected month and future months'
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
  6,
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

set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000001';

create temporary table positive_carry_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Positive carry',
  p_period_month => '2026-05-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select carry_forward_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from positive_carry_cap)
  ),
  200.00::numeric(14,2),
  'positive prior-month remainder carries forward'
);

select is(
  (
    select effective_cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from positive_carry_cap)
  ),
  1400.00::numeric(14,2),
  'positive carry-forward increases the next effective cap'
);

select is(
  (
    select remaining_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from positive_carry_cap)
  ),
  700.00::numeric(14,2),
  'remaining amount is derived from the effective cap'
);

select is(
  (
    select effective_cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-07-01'
    )
    where monthly_cap_id = (select monthly_cap_id from positive_carry_cap)
  ),
  1900.00::numeric(14,2),
  'carry-forward chains across active months'
);

create temporary table negative_carry_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Negative carry',
  p_period_month => '2026-05-01',
  p_cap_amount => 800.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select carry_forward_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from negative_carry_cap)
  ),
  -200.00::numeric(14,2),
  'negative prior-month remainder carries forward'
);

select is(
  (
    select effective_cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from negative_carry_cap)
  ),
  600.00::numeric(14,2),
  'negative carry-forward reduces the next effective cap'
);

select is(
  (
    select remaining_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from negative_carry_cap)
  ),
  -100.00::numeric(14,2),
  'negative carry-forward can make the selected month over budget'
);

select ok(
  (
    select is_over_budget
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from negative_carry_cap)
  ),
  'over-budget state is based on negative effective remaining'
);

create temporary table disabled_carry_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Disabled carry chain',
  p_period_month => '2026-05-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

create temporary table disabled_carry_june as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_monthly_cap_id => (select monthly_cap_id from disabled_carry_cap),
  p_name => 'Disabled carry chain',
  p_period_month => '2026-06-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => false
);

create temporary table disabled_carry_july as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_monthly_cap_id => (select monthly_cap_id from disabled_carry_cap),
  p_name => 'Disabled carry chain',
  p_period_month => '2026-07-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select carry_forward_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from disabled_carry_cap)
  ),
  0.00::numeric(14,2),
  'disabled carry-forward resets the selected month carry amount'
);

select is(
  (
    select carry_forward_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-07-01'
    )
    where monthly_cap_id = (select monthly_cap_id from disabled_carry_cap)
  ),
  0.00::numeric(14,2),
  'the month after a disabled carry-forward version starts from zero'
);

create temporary table edited_target_carry_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Edited target carry',
  p_period_month => '2026-05-01',
  p_cap_amount => 1200.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

create temporary table edited_target_carry_june as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_monthly_cap_id => (select monthly_cap_id from edited_target_carry_cap),
  p_name => 'Edited target carry',
  p_period_month => '2026-06-01',
  p_cap_amount => 600.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000002'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select base_cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from edited_target_carry_cap)
  ),
  600.00::numeric(14,2),
  'selected-month amount edits affect the selected month'
);

select is(
  (
    select carry_forward_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from edited_target_carry_cap)
  ),
  200.00::numeric(14,2),
  'selected-month edits keep prior-month carry-forward history'
);

select is(
  (
    select spent_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-06-01'
    )
    where monthly_cap_id = (select monthly_cap_id from edited_target_carry_cap)
  ),
  0.00::numeric(14,2),
  'selected-month target edits affect matching from that month onward'
);

insert into public.categories (id, household_id, name, sort_order)
values
  (
    '59000000-0000-0000-0000-000000000007',
    '39000000-0000-0000-0000-000000000001',
    'Utilities',
    13
  );

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
    '79000000-0000-0000-0000-000000000101',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-08-05',
    'POWER BILL',
    'power bill',
    '59000000-0000-0000-0000-000000000007',
    'debit_spend',
    100.00,
    100.00,
    0.00,
    100.00,
    'high',
    'monthly-cap-utility-debit'
  ),
  (
    '79000000-0000-0000-0000-000000000102',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-08-08',
    'POWER REFUND',
    'power refund',
    '59000000-0000-0000-0000-000000000007',
    'refund_reversal',
    -30.00,
    0.00,
    30.00,
    -30.00,
    'high',
    'monthly-cap-utility-refund'
  ),
  (
    '79000000-0000-0000-0000-000000000103',
    '39000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-08-12',
    'CARD PAYMENT',
    'card payment',
    '59000000-0000-0000-0000-000000000007',
    'bill_payment_credit',
    -500.00,
    0.00,
    0.00,
    0.00,
    'high',
    'monthly-cap-utility-bill-payment'
  );

create temporary table net_semantics_carry_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '39000000-0000-0000-0000-000000000001',
  p_name => 'Net semantics carry',
  p_period_month => '2026-08-01',
  p_cap_amount => 500.00,
  p_category_ids => array['59000000-0000-0000-0000-000000000007'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select spent_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-08-01'
    )
    where monthly_cap_id = (select monthly_cap_id from net_semantics_carry_cap)
  ),
  70.00::numeric(14,2),
  'carry-forward progress uses net expense for refunds and bill payments'
);

select is(
  (
    select effective_cap_amount
    from public.get_monthly_cap_progress(
      '39000000-0000-0000-0000-000000000001',
      '2026-09-01'
    )
    where monthly_cap_id = (select monthly_cap_id from net_semantics_carry_cap)
  ),
  930.00::numeric(14,2),
  'refund-adjusted remaining amount carries into the next month'
);

select * from finish();

rollback;
