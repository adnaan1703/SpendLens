begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(25);

insert into auth.users (id)
values
  ('16000000-0000-0000-0000-000000000001'),
  ('16000000-0000-0000-0000-000000000002'),
  ('16000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '26000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000001',
    'Label Owner',
    'label-owner@example.test'
  ),
  (
    '26000000-0000-0000-0000-000000000002',
    '16000000-0000-0000-0000-000000000002',
    'Label Viewer',
    'label-viewer@example.test'
  ),
  (
    '26000000-0000-0000-0000-000000000003',
    '16000000-0000-0000-0000-000000000003',
    'Label Outsider',
    'label-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '36000000-0000-0000-0000-000000000001',
    'Label Household',
    '26000000-0000-0000-0000-000000000001'
  ),
  (
    '36000000-0000-0000-0000-000000000002',
    'Other Label Household',
    '26000000-0000-0000-0000-000000000003'
  );

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '46000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '46000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000002',
    'viewer'
  ),
  (
    '46000000-0000-0000-0000-000000000003',
    '36000000-0000-0000-0000-000000000002',
    '26000000-0000-0000-0000-000000000003',
    'owner'
  );

insert into public.transactions (
  id,
  household_id,
  source_type,
  transaction_date,
  statement_merchant,
  normalized_statement_merchant,
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
    '76000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-01',
    'INDIGO AIRLINES',
    'indigo airlines',
    'debit_spend',
    5000.00,
    5000.00,
    0.00,
    5000.00,
    'high',
    'label-txn-1'
  ),
  (
    '76000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-02',
    'AMAZON PAY',
    'amazon pay',
    'debit_spend',
    1200.00,
    1200.00,
    0.00,
    1200.00,
    'medium',
    'label-txn-2'
  ),
  (
    '76000000-0000-0000-0000-000000000003',
    '36000000-0000-0000-0000-000000000002',
    'workbook',
    '2026-04-03',
    'OTHER HOUSEHOLD SHOP',
    'other household shop',
    'debit_spend',
    700.00,
    700.00,
    0.00,
    700.00,
    'medium',
    'label-txn-other'
  );

insert into public.labels (id, household_id, name, created_by)
values (
  '86000000-0000-0000-0000-000000000004',
  '36000000-0000-0000-0000-000000000002',
  'Secret Other Label',
  '26000000-0000-0000-0000-000000000003'
);

set local role authenticated;
set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

create temporary table first_label_set as
select *
from public.set_transaction_labels(
  p_household_id => '36000000-0000-0000-0000-000000000001',
  p_transaction_id => '76000000-0000-0000-0000-000000000001',
  p_new_label_names => array['  Travel  ', 'Work']
);

select is(
  (select count(*)::integer from first_label_set),
  2,
  'set_transaction_labels creates and returns new labels'
);

select is(
  (select string_agg(name, ',' order by name) from first_label_set),
  'Travel,Work',
  'set_transaction_labels trims label names'
);

select is(
  (
    select count(*)::integer
    from public.transaction_labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and transaction_id = '76000000-0000-0000-0000-000000000001'
  ),
  2,
  'set_transaction_labels assigns all returned labels to the transaction'
);

create temporary table label_ids as
select
  (
    select id
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and name = 'Travel'
  ) as travel_id,
  (
    select id
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and name = 'Work'
  ) as work_id;

create temporary table second_label_set as
select *
from public.set_transaction_labels(
  p_household_id => '36000000-0000-0000-0000-000000000001',
  p_transaction_id => '76000000-0000-0000-0000-000000000002',
  p_new_label_names => array['travel']
);

select is(
  (select id from second_label_set),
  (select travel_id from label_ids),
  'set_transaction_labels reuses existing labels case-insensitively'
);

select is(
  (
    select count(*)::integer
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'case-insensitive reuse does not create duplicate label rows'
);

create temporary table replacement_label_set as
select *
from public.set_transaction_labels(
  p_household_id => '36000000-0000-0000-0000-000000000001',
  p_transaction_id => '76000000-0000-0000-0000-000000000001',
  p_label_ids => array[(select work_id from label_ids)],
  p_new_label_names => array['Needs Reimb']
);

select is(
  (
    select string_agg(name, ',' order by name)
    from replacement_label_set
  ),
  'Needs Reimb,Work',
  'set_transaction_labels atomically replaces labels for the selected transaction'
);

select is(
  (
    select count(*)::integer
    from public.transaction_labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and transaction_id = '76000000-0000-0000-0000-000000000002'
      and label_id = (select travel_id from label_ids)
  ),
  1,
  'replacement leaves other transaction assignments unchanged'
);

select throws_ok(
  $$
    select *
    from public.set_transaction_labels(
      p_household_id => '36000000-0000-0000-0000-000000000001',
      p_transaction_id => '76000000-0000-0000-0000-000000000001',
      p_new_label_names => array['  ']
    )
  $$,
  'P0001',
  'Label name is required.',
  'blank label names are rejected'
);

select throws_ok(
  $$
    select *
    from public.rename_household_label(
      '36000000-0000-0000-0000-000000000001',
      (select work_id from label_ids),
      'travel'
    )
  $$,
  'P0001',
  'A label with this name already exists.',
  'rename rejects case-insensitive duplicates'
);

create temporary table rename_result as
select *
from public.rename_household_label(
  '36000000-0000-0000-0000-000000000001',
  (select work_id from label_ids),
  ' Office '
);

select is(
  (select id from rename_result),
  (select work_id from label_ids),
  'rename preserves the label id'
);

select is(
  (select name from rename_result),
  'Office',
  'rename trims and persists the new label name'
);

select is(
  (
    select transaction_count
    from public.v_label_usage
    where household_id = '36000000-0000-0000-0000-000000000001'
      and name = 'Office'
  ),
  1,
  'label usage view reports attached transaction counts'
);

insert into public.monthly_caps (
  id,
  household_id,
  name,
  period_month,
  cap_amount,
  created_by
)
values (
  '87000000-0000-0000-0000-000000000001',
  '36000000-0000-0000-0000-000000000001',
  'Travel cap',
  '2026-04-01',
  5000.00,
  '26000000-0000-0000-0000-000000000001'
);

insert into public.monthly_cap_labels (
  household_id,
  monthly_cap_id,
  label_id
)
values (
  '36000000-0000-0000-0000-000000000001',
  '87000000-0000-0000-0000-000000000001',
  (select travel_id from label_ids)
);

create temporary table delete_result as
select *
from public.delete_household_label(
  '36000000-0000-0000-0000-000000000001',
  (select travel_id from label_ids)
);

select is(
  (select detached_transaction_count from delete_result),
  1,
  'delete_household_label returns detached transaction count'
);

select is(
  (
    select count(*)::integer
    from public.transaction_labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and label_id = (select travel_id from label_ids)
  ),
  0,
  'delete_household_label detaches assignments'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_labels
    where household_id = '36000000-0000-0000-0000-000000000001'
      and label_id = (select travel_id from label_ids)
  ),
  0,
  'delete_household_label removes monthly cap label targets'
);

select is(
  (
    select count(*)::integer
    from public.monthly_caps
    where id = '87000000-0000-0000-0000-000000000001'
  ),
  0,
  'delete_household_label removes caps left with no targets'
);

select is(
  (
    select count(*)::integer
    from public.transactions
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'delete_household_label preserves transaction rows'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000002';

select is(
  (
    select count(*)::integer
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'household viewers can select household labels'
);

select is(
  (
    select count(*)::integer
    from public.transaction_labels
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'household viewers can select transaction label assignments'
);

select throws_ok(
  $$
    select *
    from public.set_transaction_labels(
      p_household_id => '36000000-0000-0000-0000-000000000001',
      p_transaction_id => '76000000-0000-0000-0000-000000000001',
      p_new_label_names => array['Viewer Blocked']
    )
  $$,
  'P0001',
  'You do not have permission to set labels for this household.',
  'viewers cannot mutate transaction labels'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.rename_household_label(
      '36000000-0000-0000-0000-000000000001',
      (select work_id from label_ids),
      'Outsider Blocked'
    )
  $$,
  'P0001',
  'You do not have permission to rename labels for this household.',
  'non-members cannot mutate household labels'
);

select is(
  (
    select count(*)::integer
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  0,
  'RLS hides another household labels from non-members'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000001';

select throws_ok(
  $$
    select *
    from public.set_transaction_labels(
      p_household_id => '36000000-0000-0000-0000-000000000001',
      p_transaction_id => '76000000-0000-0000-0000-000000000001',
      p_label_ids => array['86000000-0000-0000-0000-000000000004'::uuid]
    )
  $$,
  'P0001',
  'Labels must belong to this household.',
  'cross-household label ids are rejected'
);

select throws_ok(
  $$
    select *
    from public.set_transaction_labels(
      p_household_id => '36000000-0000-0000-0000-000000000001',
      p_transaction_id => '76000000-0000-0000-0000-000000000003',
      p_label_ids => array[(select work_id from label_ids)]
    )
  $$,
  'P0001',
  'Transaction not found for this household.',
  'cross-household transaction ids are rejected'
);

select is(
  (
    select count(*)::integer
    from public.labels
    where household_id = '36000000-0000-0000-0000-000000000002'
  ),
  0,
  'RLS hides other household labels from household members'
);

select * from finish();

rollback;
