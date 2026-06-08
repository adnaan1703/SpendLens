begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(13);

insert into auth.users (id)
values
  ('15000000-0000-0000-0000-000000000001'),
  ('15000000-0000-0000-0000-000000000002'),
  ('15000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '25000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000001',
    'Metadata Owner',
    'metadata-owner@example.test'
  ),
  (
    '25000000-0000-0000-0000-000000000002',
    '15000000-0000-0000-0000-000000000002',
    'Metadata Viewer',
    'metadata-viewer@example.test'
  ),
  (
    '25000000-0000-0000-0000-000000000003',
    '15000000-0000-0000-0000-000000000003',
    'Metadata Outsider',
    'metadata-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '35000000-0000-0000-0000-000000000001',
    'Metadata Household',
    '25000000-0000-0000-0000-000000000001'
  ),
  (
    '35000000-0000-0000-0000-000000000002',
    'Other Household',
    '25000000-0000-0000-0000-000000000003'
  );

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '45000000-0000-0000-0000-000000000001',
    '35000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '45000000-0000-0000-0000-000000000002',
    '35000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000002',
    'viewer'
  ),
  (
    '45000000-0000-0000-0000-000000000003',
    '35000000-0000-0000-0000-000000000002',
    '25000000-0000-0000-0000-000000000003',
    'owner'
  );

insert into public.categories (id, household_id, name, sort_order)
values
  ('55000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', 'Unclear', 1),
  ('55000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001', 'Shopping', 2),
  ('55000000-0000-0000-0000-000000000003', '35000000-0000-0000-0000-000000000001', 'Travel', 3),
  ('55000000-0000-0000-0000-000000000004', '35000000-0000-0000-0000-000000000002', 'Other Household Category', 1);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('56000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', 'Needs Review', 1),
  ('56000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000002', 'Marketplace', 1),
  ('56000000-0000-0000-0000-000000000003', '35000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000003', 'Flights', 1),
  ('56000000-0000-0000-0000-000000000004', '35000000-0000-0000-0000-000000000002', '55000000-0000-0000-0000-000000000004', 'Other', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values (
  '65000000-0000-0000-0000-000000000001',
  '35000000-0000-0000-0000-000000000001',
  'Unknown Amazon',
  '55000000-0000-0000-0000-000000000001',
  '56000000-0000-0000-0000-000000000001',
  'low'
);

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
  notes,
  source_fingerprint
)
values
  (
    '75000000-0000-0000-0000-000000000001',
    '35000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-01',
    'AMZN MKTP IN',
    'amzn mktp in',
    '65000000-0000-0000-0000-000000000001',
    '55000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    'debit_spend',
    250.00,
    250.00,
    0.00,
    250.00,
    'low',
    'Old note',
    'metadata-amzn-1'
  ),
  (
    '75000000-0000-0000-0000-000000000002',
    '35000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-02',
    'AMZN MKTP IN',
    'amzn mktp in',
    '65000000-0000-0000-0000-000000000001',
    '55000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    'debit_spend',
    300.00,
    300.00,
    0.00,
    300.00,
    'medium',
    null,
    'metadata-amzn-2'
  ),
  (
    '75000000-0000-0000-0000-000000000003',
    '35000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-03',
    'AMAZON PRIME',
    'amazon prime',
    '65000000-0000-0000-0000-000000000001',
    '55000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    'debit_spend',
    999.00,
    999.00,
    0.00,
    999.00,
    'low',
    null,
    'metadata-prime-1'
  );

insert into public.review_items (id, household_id, transaction_id, reason, status)
values
  ('95000000-0000-0000-0000-000000000001', '35000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000001', 'Low-confidence merchant', 'open'),
  ('95000000-0000-0000-0000-000000000002', '35000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000002', 'Matching low-confidence merchant', 'open'),
  ('95000000-0000-0000-0000-000000000003', '35000000-0000-0000-0000-000000000001', '75000000-0000-0000-0000-000000000003', 'Different merchant', 'open');

set local role authenticated;
set local request.jwt.claim.sub = '15000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

create temporary table metadata_correction_result as
select *
from public.apply_transaction_metadata_correction(
  p_household_id => '35000000-0000-0000-0000-000000000001',
  p_transaction_id => '75000000-0000-0000-0000-000000000001',
  p_merchant_group => '  Amazon Shopping  ',
  p_category_id => '55000000-0000-0000-0000-000000000002',
  p_subcategory_id => '56000000-0000-0000-0000-000000000002',
  p_confidence => 'high',
  p_notes => 'Confirmed marketplace',
  p_review_item_id => '95000000-0000-0000-0000-000000000001'
);

select is((select updated_transaction_count from metadata_correction_result), 2, 'metadata edit updates matching normalized merchant transactions');
select is((select resolved_review_item_count from metadata_correction_result), 2, 'metadata edit resolves matching open review items');

select is(
  (
    select count(*)::integer
    from public.transactions t
    join public.merchants m
      on m.id = t.merchant_id
     and m.household_id = t.household_id
    where t.normalized_statement_merchant = 'amzn mktp in'
      and m.display_name = 'Amazon Shopping'
      and t.category_id = '55000000-0000-0000-0000-000000000002'
      and t.subcategory_id = '56000000-0000-0000-0000-000000000002'
      and t.confidence = 'high'
      and t.notes = 'Confirmed marketplace'
      and t.classification_rule_id = (select rule_id from metadata_correction_result)
      and t.classification_review_item_id = '95000000-0000-0000-0000-000000000001'
      and t.classification_updated_by = '25000000-0000-0000-0000-000000000001'
      and t.classification_updated_at is not null
      and t.classification_note = 'Confirmed marketplace'
  ),
  2,
  'matching transaction rows persist selected merchant metadata and audit fields'
);

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '75000000-0000-0000-0000-000000000003'
      and normalized_statement_merchant = 'amazon prime'
      and merchant_id = '65000000-0000-0000-0000-000000000001'
      and category_id = '55000000-0000-0000-0000-000000000001'
      and subcategory_id = '56000000-0000-0000-0000-000000000001'
      and confidence = 'low'
      and classification_rule_id is null
  ),
  1,
  'non-matching normalized merchants remain unchanged'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where id = '95000000-0000-0000-0000-000000000003'
      and status = 'open'
  ),
  1,
  'non-matching review items remain open'
);

select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where id = (select rule_id from metadata_correction_result)
      and household_id = '35000000-0000-0000-0000-000000000001'
      and pattern = 'amzn mktp in'
      and match_type = 'exact'
      and priority = 10
      and confidence = 'high'
      and apply_to_future
      and category_id = '55000000-0000-0000-0000-000000000002'
      and subcategory_id = '56000000-0000-0000-0000-000000000002'
      and created_by = '25000000-0000-0000-0000-000000000001'
      and notes = 'Confirmed marketplace'
  ),
  1,
  'metadata edit creates a future exact mapping rule with selected confidence'
);

select is(
  (
    select confidence::text
    from public.match_merchant_mapping_rule(
      '35000000-0000-0000-0000-000000000001',
      'AMZN MKTP IN'
    )
  ),
  'high',
  'future imports match the edited confidence'
);

select is(
  (
    select count(*)::integer
    from public.merchants
    where id = (select merchant_id from metadata_correction_result)
      and display_name = 'Amazon Shopping'
      and confidence = 'high'
  ),
  1,
  'canonical merchant persists selected confidence'
);

select throws_ok(
  $$
    select *
    from public.apply_transaction_metadata_correction(
      p_household_id => '35000000-0000-0000-0000-000000000001',
      p_transaction_id => '75000000-0000-0000-0000-000000000001',
      p_merchant_group => '',
      p_category_id => '55000000-0000-0000-0000-000000000002',
      p_subcategory_id => '56000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'Merchant group is required.',
  'blank merchant groups are rejected'
);

select throws_ok(
  $$
    select *
    from public.apply_transaction_metadata_correction(
      p_household_id => '35000000-0000-0000-0000-000000000001',
      p_transaction_id => '75000000-0000-0000-0000-000000000001',
      p_merchant_group => 'Amazon Shopping',
      p_category_id => '55000000-0000-0000-0000-000000000004',
      p_subcategory_id => '56000000-0000-0000-0000-000000000004'
    )
  $$,
  'P0001',
  'Category does not belong to this household.',
  'categories from another household are rejected'
);

select throws_ok(
  $$
    select *
    from public.apply_transaction_metadata_correction(
      p_household_id => '35000000-0000-0000-0000-000000000001',
      p_transaction_id => '75000000-0000-0000-0000-000000000001',
      p_merchant_group => 'Amazon Shopping',
      p_category_id => '55000000-0000-0000-0000-000000000003',
      p_subcategory_id => '56000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'Subcategory does not belong to the selected category.',
  'subcategories from another category are rejected'
);

set local request.jwt.claim.sub = '15000000-0000-0000-0000-000000000002';

select throws_ok(
  $$
    select *
    from public.apply_transaction_metadata_correction(
      p_household_id => '35000000-0000-0000-0000-000000000001',
      p_transaction_id => '75000000-0000-0000-0000-000000000001',
      p_merchant_group => 'Viewer Blocked',
      p_category_id => '55000000-0000-0000-0000-000000000002',
      p_subcategory_id => '56000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'You do not have permission to edit transaction metadata for this household.',
  'viewers cannot edit transaction metadata'
);

set local request.jwt.claim.sub = '15000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.apply_transaction_metadata_correction(
      p_household_id => '35000000-0000-0000-0000-000000000001',
      p_transaction_id => '75000000-0000-0000-0000-000000000001',
      p_merchant_group => 'Outsider Blocked',
      p_category_id => '55000000-0000-0000-0000-000000000002',
      p_subcategory_id => '56000000-0000-0000-0000-000000000002'
    )
  $$,
  'P0001',
  'You do not have permission to edit transaction metadata for this household.',
  'non-members cannot edit transaction metadata'
);

select * from finish();

rollback;
