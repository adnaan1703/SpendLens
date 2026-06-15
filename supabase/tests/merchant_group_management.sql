begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(31);

insert into auth.users (id)
values
  ('11000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000002'),
  ('11000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'Merchant Owner', 'merchant-owner@example.test'),
  ('21000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000002', 'Merchant Viewer', 'merchant-viewer@example.test'),
  ('21000000-0000-0000-0000-000000000003', '11000000-0000-0000-0000-000000000003', 'Merchant Outsider', 'merchant-outsider@example.test');

insert into public.households (id, name, created_by)
values
  ('31000000-0000-0000-0000-000000000001', 'Merchant Household', '21000000-0000-0000-0000-000000000001'),
  ('31000000-0000-0000-0000-000000000002', 'Other Merchant Household', '21000000-0000-0000-0000-000000000003');

insert into public.household_members (id, household_id, profile_id, role)
values
  ('41000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'owner'),
  ('41000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000002', 'viewer'),
  ('41000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000003', 'owner');

insert into public.categories (id, household_id, name, sort_order)
values
  ('51000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Food', 1),
  ('51000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'Shopping', 2),
  ('51000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'Travel', 3),
  ('51000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000002', 'Other Food', 1);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('52000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'Delivery', 1),
  ('52000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000002', 'Marketplace', 1),
  ('52000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000003', 'Flights', 1),
  ('52000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000004', 'Other Delivery', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values
  ('61000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Swiggy Instamart', '51000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'manual'),
  ('61000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'Swiggy Grocery', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002', 'manual'),
  ('61000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'Instamart BLR', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 'medium'),
  ('61000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000001', 'Uber', null, null, 'medium'),
  ('61000000-0000-0000-0000-000000000005', '31000000-0000-0000-0000-000000000002', 'Other Swiggy', '51000000-0000-0000-0000-000000000004', '52000000-0000-0000-0000-000000000004', 'medium'),
  ('61000000-0000-0000-0000-000000000010', '31000000-0000-0000-0000-000000000001', 'Amazon Shopping', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002', 'manual'),
  ('61000000-0000-0000-0000-000000000011', '31000000-0000-0000-0000-000000000001', 'Amazon Prime', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 'medium');

insert into public.merchant_aliases (
  id,
  household_id,
  merchant_id,
  raw_name,
  normalized_name,
  source_type
)
values
  ('62000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001', 'SWIGGY INSTAMART', 'swiggy instamart', 'manual'),
  ('62000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002', 'SWIGGY GROCERY', 'swiggy grocery', 'manual'),
  ('62000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000003', 'INSTAMART BLR', 'instamart blr', 'manual'),
  ('62000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000011', 'AMAZON PRIME', 'amazon prime', 'manual');

insert into public.merchant_mapping_rules (
  id,
  household_id,
  pattern,
  match_type,
  merchant_id,
  category_id,
  subcategory_id,
  priority,
  confidence,
  apply_to_future,
  created_by
)
values
  ('63000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'swiggy grocery', 'exact', '61000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002', 10, 'high', true, '21000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'instamart blr', 'exact', '61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 10, 'high', true, '21000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'old instamart', 'contains', '61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 100, 'medium', false, '21000000-0000-0000-0000-000000000001'),
  ('63000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000001', 'amazon prime', 'exact', '61000000-0000-0000-0000-000000000011', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 10, 'high', true, '21000000-0000-0000-0000-000000000001');

insert into public.transactions (
  id,
  household_id,
  source_type,
  transaction_date,
  statement_merchant,
  normalized_statement_merchant,
  merchant_id,
  category_id,
  subcategory_id,
  transaction_type,
  amount,
  gross_spend,
  refund_amount,
  net_expense,
  confidence,
  source_fingerprint
)
values
  ('71000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'workbook', '2026-06-01', 'SWIGGY GROCERY', 'swiggy grocery', '61000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002', 'debit_spend', 1200.00, 1200.00, 0.00, 1200.00, 'medium', 'merchant-group-1'),
  ('71000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'workbook', '2026-06-02', 'INSTAMART BLR', 'instamart blr', '61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 'debit_spend', 300.00, 300.00, 0.00, 300.00, 'medium', 'merchant-group-2'),
  ('71000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'workbook', '2026-06-03', 'SWIGGY INSTAMART', 'swiggy instamart', '61000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'debit_spend', 800.00, 800.00, 0.00, 800.00, 'manual', 'merchant-group-3'),
  ('71000000-0000-0000-0000-000000000004', '31000000-0000-0000-0000-000000000001', 'workbook', '2026-06-04', 'AMAZON PRIME', 'amazon prime', '61000000-0000-0000-0000-000000000011', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', 'debit_spend', 999.00, 999.00, 0.00, 999.00, 'medium', 'merchant-group-4');

insert into public.review_items (
  id,
  household_id,
  transaction_id,
  reason,
  status,
  suggested_merchant_id,
  suggested_category_id,
  suggested_subcategory_id
)
values
  ('81000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'Needs merchant grouping', 'open', '61000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002'),
  ('81000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002', 'Old grouping suggestion', 'resolved', '61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003'),
  ('81000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000004', 'Amazon grouping suggestion', 'open', '61000000-0000-0000-0000-000000000011', '51000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003');

set local role authenticated;
set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select count(*)::integer
    from public.v_merchant_group_usage
    where household_id = '31000000-0000-0000-0000-000000000001'
  ),
  6,
  'merchant group usage lists household merchant groups'
);
select is((select transaction_count from public.v_merchant_group_usage where merchant_id = '61000000-0000-0000-0000-000000000002'), 1, 'usage view counts merchant transactions');
select is((select net_spend from public.v_merchant_group_usage where merchant_id = '61000000-0000-0000-0000-000000000002'), 1200.00::numeric(14,2), 'usage view sums merchant net spend');
select is((select alias_count from public.v_merchant_group_usage where merchant_id = '61000000-0000-0000-0000-000000000002'), 1, 'usage view counts merchant aliases');
select is((select active_mapping_rule_count from public.v_merchant_group_usage where merchant_id = '61000000-0000-0000-0000-000000000002'), 1, 'usage view counts active mapping rules');
select is((select open_review_suggestion_count from public.v_merchant_group_usage where merchant_id = '61000000-0000-0000-0000-000000000002'), 1, 'usage view counts open review suggestions');

create temporary table renamed_merchant as
select *
from public.rename_household_merchant(
  '31000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  '  Swiggy Market  '
);

select is((select display_name from renamed_merchant), 'Swiggy Market', 'rename returns trimmed merchant group name');
select is((select display_name from public.merchants where id = '61000000-0000-0000-0000-000000000001'), 'Swiggy Market', 'rename updates only the canonical merchant row');

select throws_ok(
  $$
    select *
    from public.rename_household_merchant(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      ''
    )
  $$,
  'P0001',
  'Merchant group name is required.',
  'blank merchant group names are rejected'
);

select throws_ok(
  $$
    select *
    from public.rename_household_merchant(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'uber'
    )
  $$,
  'P0001',
  'A merchant group with this name already exists.',
  'case-insensitive duplicate merchant group names are rejected'
);

set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000002';

select throws_ok(
  $$
    select *
    from public.rename_household_merchant(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'Viewer Rename'
    )
  $$,
  'P0001',
  'You do not have permission to rename merchant groups for this household.',
  'household viewers cannot rename merchant groups'
);

set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.merge_household_merchants(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'Swiggy Market',
      array['61000000-0000-0000-0000-000000000002']::uuid[],
      'preserve'
    )
  $$,
  'P0001',
  'You do not have permission to merge merchant groups for this household.',
  'non-members cannot merge merchant groups'
);

set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000001';

select throws_ok(
  $$
    select *
    from public.merge_household_merchants(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'Swiggy Market',
      array['61000000-0000-0000-0000-000000000005']::uuid[],
      'preserve'
    )
  $$,
  'P0001',
  'Source merchant groups must belong to the same household.',
  'merge rejects source merchant groups from another household'
);

create temporary table merge_preserve_result as
select *
from public.merge_household_merchants(
  '31000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000001',
  'Swiggy Market',
  array[
    '61000000-0000-0000-0000-000000000002',
    '61000000-0000-0000-0000-000000000003'
  ]::uuid[],
  'preserve'
);

select is((select moved_transaction_count from merge_preserve_result), 2, 'preserve merge reports moved transactions');
select is((select moved_alias_count from merge_preserve_result), 2, 'preserve merge reports moved aliases');
select is((select moved_mapping_rule_count from merge_preserve_result), 3, 'preserve merge reports moved mapping rules');
select is((select moved_review_suggestion_count from merge_preserve_result), 1, 'preserve merge reports open moved review suggestions');
select is((select deleted_source_merchant_count from merge_preserve_result), 2, 'preserve merge deletes source merchant groups');
select is(
  (
    select count(*)::integer
    from public.transactions
    where merchant_id = '61000000-0000-0000-0000-000000000001'
      and id in (
        '71000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000002'
      )
  ),
  2,
  'preserve merge repoints source transactions to the destination merchant'
);
select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '71000000-0000-0000-0000-000000000001'
      and category_id = '51000000-0000-0000-0000-000000000002'
      and subcategory_id = '52000000-0000-0000-0000-000000000002'
  ),
  1,
  'preserve merge leaves transaction taxonomy unchanged'
);
select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where merchant_id = '61000000-0000-0000-0000-000000000001'
      and id in (
        '63000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-000000000002',
        '63000000-0000-0000-0000-000000000003'
      )
  ),
  3,
  'preserve merge repoints mapping rules'
);
select is(
  (
    select count(*)::integer
    from public.review_items
    where id = '81000000-0000-0000-0000-000000000001'
      and suggested_merchant_id = '61000000-0000-0000-0000-000000000001'
      and suggested_category_id = '51000000-0000-0000-0000-000000000002'
      and suggested_subcategory_id = '52000000-0000-0000-0000-000000000002'
  ),
  1,
  'preserve merge repoints open review suggestions without taxonomy changes'
);
select is(
  (
    select count(*)::integer
    from public.merchants
    where id in (
      '61000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000003'
    )
  ),
  0,
  'source merchants are deleted after references move'
);

create temporary table merge_destination_result as
select *
from public.merge_household_merchants(
  '31000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000010',
  'Amazon Shopping',
  array['61000000-0000-0000-0000-000000000011']::uuid[],
  'destination'
);

select is((select category_updated_transaction_count from merge_destination_result), 1, 'destination merge reports taxonomy-updated transactions');
select is((select category_updated_mapping_rule_count from merge_destination_result), 1, 'destination merge reports taxonomy-updated active mapping rules');
select is((select category_updated_review_suggestion_count from merge_destination_result), 1, 'destination merge reports taxonomy-updated open review suggestions');
select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '71000000-0000-0000-0000-000000000004'
      and merchant_id = '61000000-0000-0000-0000-000000000010'
      and category_id = '51000000-0000-0000-0000-000000000002'
      and subcategory_id = '52000000-0000-0000-0000-000000000002'
      and classification_updated_by = '21000000-0000-0000-0000-000000000001'
      and classification_updated_at is not null
  ),
  1,
  'destination merge applies destination taxonomy and audit fields to transactions'
);
select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where id = '63000000-0000-0000-0000-000000000004'
      and merchant_id = '61000000-0000-0000-0000-000000000010'
      and category_id = '51000000-0000-0000-0000-000000000002'
      and subcategory_id = '52000000-0000-0000-0000-000000000002'
  ),
  1,
  'destination merge applies destination taxonomy to active mapping rules'
);
select is(
  (
    select count(*)::integer
    from public.review_items
    where id = '81000000-0000-0000-0000-000000000003'
      and suggested_merchant_id = '61000000-0000-0000-0000-000000000010'
      and suggested_category_id = '51000000-0000-0000-0000-000000000002'
      and suggested_subcategory_id = '52000000-0000-0000-0000-000000000002'
  ),
  1,
  'destination merge applies destination taxonomy to open review suggestions'
);

select throws_ok(
  $$
    select *
    from public.merge_household_merchants(
      '31000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000004',
      'Uber',
      array['61000000-0000-0000-0000-000000000010']::uuid[],
      'destination'
    )
  $$,
  'P0001',
  'Destination category strategy requires the destination merchant group to have a category and subcategory.',
  'destination strategy requires destination taxonomy'
);

select is(
  (
    select count(*)::integer
    from public.merchants
    where id = '61000000-0000-0000-0000-000000000010'
  ),
  1,
  'destination merchant survives merge'
);

select * from finish();

rollback;
