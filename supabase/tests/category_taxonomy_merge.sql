begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(23);

insert into auth.users (id)
values
  ('18000000-0000-0000-0000-000000000001'),
  ('18000000-0000-0000-0000-000000000002'),
  ('18000000-0000-0000-0000-000000000003'),
  ('18000000-0000-0000-0000-000000000004');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000001',
    'Merge Owner',
    'merge-owner@example.test'
  ),
  (
    '28000000-0000-0000-0000-000000000002',
    '18000000-0000-0000-0000-000000000002',
    'Merge Member',
    'merge-member@example.test'
  ),
  (
    '28000000-0000-0000-0000-000000000003',
    '18000000-0000-0000-0000-000000000003',
    'Merge Viewer',
    'merge-viewer@example.test'
  ),
  (
    '28000000-0000-0000-0000-000000000004',
    '18000000-0000-0000-0000-000000000004',
    'Merge Outsider',
    'merge-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '38000000-0000-0000-0000-000000000001',
    'Merge Household',
    '28000000-0000-0000-0000-000000000001'
  ),
  (
    '38000000-0000-0000-0000-000000000002',
    'Other Merge Household',
    '28000000-0000-0000-0000-000000000004'
  );

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '48000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '48000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000002',
    'member'
  ),
  (
    '48000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    '28000000-0000-0000-0000-000000000003',
    'viewer'
  ),
  (
    '48000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000004',
    'owner'
  );

insert into public.categories (id, household_id, name, sort_order)
values
  ('58000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', 'Food', 1),
  ('58000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', 'Dining', 2),
  ('58000000-0000-0000-0000-000000000003', '38000000-0000-0000-0000-000000000001', 'Shopping', 3),
  ('58000000-0000-0000-0000-000000000004', '38000000-0000-0000-0000-000000000001', 'Blocked', 4),
  ('58000000-0000-0000-0000-000000000005', '38000000-0000-0000-0000-000000000002', 'Other Household Category', 1);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('59000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', 'Groceries', 1),
  ('59000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'Delivery', 1),
  ('59000000-0000-0000-0000-000000000003', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000003', 'Marketplace', 1),
  ('59000000-0000-0000-0000-000000000004', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000003', 'Subscriptions', 2),
  ('59000000-0000-0000-0000-000000000005', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000004', 'Blocked child', 1),
  ('59000000-0000-0000-0000-000000000006', '38000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000005', 'Other', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values
  (
    '68000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'Swiggy Instamart',
    '58000000-0000-0000-0000-000000000002',
    '59000000-0000-0000-0000-000000000002',
    'high'
  ),
  (
    '68000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    'Amazon Shopping',
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000003',
    'manual'
  );

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
  created_by,
  notes
)
values
  (
    '78000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'swiggy instamart',
    'exact',
    '68000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000002',
    '59000000-0000-0000-0000-000000000002',
    10,
    'manual',
    true,
    '28000000-0000-0000-0000-000000000001',
    null
  ),
  (
    '78000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    'amazon pay',
    'exact',
    '68000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000003',
    10,
    'manual',
    true,
    '28000000-0000-0000-0000-000000000001',
    'Confirmed marketplace'
  );

insert into public.monthly_caps (
  id,
  household_id,
  name,
  period_month,
  cap_amount,
  created_by
)
values
  ('88000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', 'Destination cap', '2026-03-01', 10000.00, '28000000-0000-0000-0000-000000000001'),
  ('88000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', 'Source grocery', '2026-03-01', 5000.00, '28000000-0000-0000-0000-000000000001'),
  ('88000000-0000-0000-0000-000000000003', '38000000-0000-0000-0000-000000000001', 'Source marketplace', '2026-03-01', 2000.00, '28000000-0000-0000-0000-000000000001'),
  ('88000000-0000-0000-0000-000000000004', '38000000-0000-0000-0000-000000000001', 'Source marketplace', '2026-04-01', 3000.00, '28000000-0000-0000-0000-000000000001');

insert into public.monthly_cap_categories (
  household_id,
  monthly_cap_id,
  category_id
)
values
  ('38000000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001'),
  ('38000000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-000000000002', '58000000-0000-0000-0000-000000000002'),
  ('38000000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-000000000003', '58000000-0000-0000-0000-000000000003'),
  ('38000000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-000000000004', '58000000-0000-0000-0000-000000000003');

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
  classification_rule_id,
  source_fingerprint
)
values
  (
    '98000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-12',
    'SWIGGY INSTAMART BANGALORE',
    'swiggy instamart',
    '68000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000002',
    '59000000-0000-0000-0000-000000000002',
    'debit_spend',
    1200.00,
    1200.00,
    0.00,
    1200.00,
    'high',
    '78000000-0000-0000-0000-000000000001',
    'taxonomy-merge-dining-1'
  ),
  (
    '98000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-08',
    'Amazon Pay',
    'amazon pay',
    '68000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000003',
    'debit_spend',
    2400.00,
    2400.00,
    0.00,
    2400.00,
    'manual',
    '78000000-0000-0000-0000-000000000002',
    'taxonomy-merge-shopping-1'
  ),
  (
    '98000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-08',
    'Spotify',
    'spotify',
    null,
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000004',
    'debit_spend',
    499.00,
    499.00,
    0.00,
    499.00,
    'manual',
    null,
    'taxonomy-merge-shopping-2'
  ),
  (
    '98000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-09',
    'Misc Store',
    'misc store',
    null,
    '58000000-0000-0000-0000-000000000003',
    null,
    'debit_spend',
    99.00,
    99.00,
    0.00,
    99.00,
    'medium',
    null,
    'taxonomy-merge-shopping-3'
  );

insert into public.review_items (
  id,
  household_id,
  transaction_id,
  reason,
  suggested_merchant_id,
  suggested_category_id,
  suggested_subcategory_id
)
values
  (
    '99000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '98000000-0000-0000-0000-000000000002',
    'Existing shopping suggestion',
    '68000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000003'
  ),
  (
    '99000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    '98000000-0000-0000-0000-000000000003',
    'Existing subscription suggestion',
    null,
    '58000000-0000-0000-0000-000000000003',
    '59000000-0000-0000-0000-000000000004'
  );

set local role authenticated;
set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000002';
set local request.jwt.claim.role = 'authenticated';

select throws_ok(
  $$
    select *
    from public.merge_household_categories(
      '38000000-0000-0000-0000-000000000001',
      '58000000-0000-0000-0000-000000000001',
      'Household Food',
      array[
        '58000000-0000-0000-0000-000000000002',
        '58000000-0000-0000-0000-000000000003'
      ]::uuid[],
      jsonb_build_array(
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000002',
          'destination_subcategory_id',
          '59000000-0000-0000-0000-000000000001'
        )
      )
    )
  $$,
  'P0001',
  'Every source subcategory must be mapped.',
  'merge rejects missing source subcategory mappings'
);

select throws_ok(
  $$
    select *
    from public.merge_household_categories(
      '38000000-0000-0000-0000-000000000001',
      '58000000-0000-0000-0000-000000000001',
      'Household Food',
      array[
        '58000000-0000-0000-0000-000000000002',
        '58000000-0000-0000-0000-000000000003'
      ]::uuid[],
      jsonb_build_array(
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000002',
          'destination_subcategory_id',
          '59000000-0000-0000-0000-000000000001'
        ),
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000003',
          'destination_subcategory_name',
          'Merged'
        ),
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000004',
          'destination_subcategory_name',
          'merged'
        )
      )
    )
  $$,
  'P0001',
  'Duplicate destination subcategory names are not allowed.',
  'merge rejects duplicate new destination subcategory names case-insensitively'
);

create temporary table merged_category as
select *
from public.merge_household_categories(
  '38000000-0000-0000-0000-000000000001',
  '58000000-0000-0000-0000-000000000001',
  'Household Food',
  array[
    '58000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000003'
  ]::uuid[],
  jsonb_build_array(
    jsonb_build_object(
      'source_subcategory_id',
      '59000000-0000-0000-0000-000000000002',
      'destination_subcategory_id',
      '59000000-0000-0000-0000-000000000001'
    ),
    jsonb_build_object(
      'source_subcategory_id',
      '59000000-0000-0000-0000-000000000003',
      'destination_subcategory_name',
      'Online Shopping'
    ),
    jsonb_build_object(
      'source_subcategory_id',
      '59000000-0000-0000-0000-000000000004',
      'destination_subcategory_name',
      'Recurring'
    )
  )
);

select is((select changed_transaction_count from merged_category), 4, 'merge reports changed transactions');
select is((select changed_merchant_count from merged_category), 2, 'merge reports changed merchants');
select is((select changed_mapping_rule_count from merged_category), 2, 'merge reports repointed mapping rules');
select is((select changed_review_suggestion_count from merged_category), 2, 'merge reports repointed review suggestions');
select is((select merged_cap_count from merged_category), 3, 'merge reports source caps');
select is((select created_subcategory_count from merged_category), 2, 'merge reports created destination subcategories');
select is((select deleted_category_count from merged_category), 2, 'merge reports deleted source categories');
select is((select deleted_subcategory_count from merged_category), 3, 'merge reports deleted source subcategories');

select is(
  (
    select count(*)::integer
    from public.categories
    where household_id = '38000000-0000-0000-0000-000000000001'
      and (
        (id = '58000000-0000-0000-0000-000000000001' and name = 'Household Food')
        or id in (
          '58000000-0000-0000-0000-000000000002',
          '58000000-0000-0000-0000-000000000003'
        )
      )
  ),
  1,
  'destination category survives renamed and source categories are deleted'
);

select is(
  (
    select count(*)::integer
    from public.subcategories
    where category_id = '58000000-0000-0000-0000-000000000001'
      and name in ('Groceries', 'Online Shopping', 'Recurring')
  ),
  3,
  'existing and newly created destination subcategories exist after merge'
);

select is(
  (
    select count(*)::integer
    from public.transactions t
    left join public.subcategories sc
      on sc.id = t.subcategory_id
      and sc.household_id = t.household_id
    where t.id in (
        '98000000-0000-0000-0000-000000000001',
        '98000000-0000-0000-0000-000000000002',
        '98000000-0000-0000-0000-000000000003',
        '98000000-0000-0000-0000-000000000004'
      )
      and t.category_id = '58000000-0000-0000-0000-000000000001'
      and (
        (t.id = '98000000-0000-0000-0000-000000000001' and sc.name = 'Groceries')
        or (t.id = '98000000-0000-0000-0000-000000000002' and sc.name = 'Online Shopping')
        or (t.id = '98000000-0000-0000-0000-000000000003' and sc.name = 'Recurring')
        or (t.id = '98000000-0000-0000-0000-000000000004' and t.subcategory_id is null)
      )
  ),
  4,
  'transactions point to surviving taxonomy after merge'
);

select is(
  (
    select count(*)::integer
    from public.transactions
    where household_id = '38000000-0000-0000-0000-000000000001'
      and classification_updated_by = '28000000-0000-0000-0000-000000000002'
      and classification_updated_at is not null
      and classification_note = 'Taxonomy merged into category: Household Food.'
  ),
  4,
  'merged transactions record acting profile and merge audit note'
);

select is(
  (
    select count(*)::integer
    from public.merchants m
    join public.subcategories sc
      on sc.id = m.subcategory_id
      and sc.household_id = m.household_id
    where m.category_id = '58000000-0000-0000-0000-000000000001'
      and (
        (m.id = '68000000-0000-0000-0000-000000000001' and sc.name = 'Groceries')
        or (m.id = '68000000-0000-0000-0000-000000000002' and sc.name = 'Online Shopping')
      )
  ),
  2,
  'merchants point to surviving taxonomy after merge'
);

select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules mmr
    join public.subcategories sc
      on sc.id = mmr.subcategory_id
      and sc.household_id = mmr.household_id
    where mmr.category_id = '58000000-0000-0000-0000-000000000001'
      and mmr.apply_to_future
      and (
        (mmr.id = '78000000-0000-0000-0000-000000000001' and sc.name = 'Groceries')
        or (mmr.id = '78000000-0000-0000-0000-000000000002' and sc.name = 'Online Shopping')
      )
  ),
  2,
  'future mapping rules are repointed and remain active'
);

select is(
  (
    select count(*)::integer
    from public.review_items ri
    join public.subcategories sc
      on sc.id = ri.suggested_subcategory_id
      and sc.household_id = ri.household_id
    where ri.suggested_category_id = '58000000-0000-0000-0000-000000000001'
      and (
        (ri.id = '99000000-0000-0000-0000-000000000001' and sc.name = 'Online Shopping')
        or (ri.id = '99000000-0000-0000-0000-000000000002' and sc.name = 'Recurring')
      )
  ),
  2,
  'review suggestions point to surviving taxonomy after merge'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_categories
    where household_id = '38000000-0000-0000-0000-000000000001'
      and monthly_cap_id in (
        '88000000-0000-0000-0000-000000000002',
        '88000000-0000-0000-0000-000000000003',
        '88000000-0000-0000-0000-000000000004'
      )
      and category_id = '58000000-0000-0000-0000-000000000001'
  ),
  3,
  'source cap targets are repointed to the destination category'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_categories
    where household_id = '38000000-0000-0000-0000-000000000001'
      and category_id in (
        '58000000-0000-0000-0000-000000000002',
        '58000000-0000-0000-0000-000000000003'
      )
  ),
  0,
  'source category cap targets are removed after merge'
);

select is(
  (
    select count(*)::integer
    from public.monthly_caps mc
    join public.monthly_cap_categories mcc
      on mcc.monthly_cap_id = mc.id
      and mcc.household_id = mc.household_id
    where mc.household_id = '38000000-0000-0000-0000-000000000001'
      and mcc.category_id = '58000000-0000-0000-0000-000000000001'
      and mc.period_month = '2026-03-01'
  ),
  3,
  'same-month named caps stay independent after merge'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where household_id = '38000000-0000-0000-0000-000000000001'
  ),
  2,
  'successful category merge does not create review items'
);

set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.merge_household_categories(
      '38000000-0000-0000-0000-000000000001',
      '58000000-0000-0000-0000-000000000001',
      'Viewer Food',
      array['58000000-0000-0000-0000-000000000004']::uuid[],
      jsonb_build_array(
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000005',
          'destination_subcategory_id',
          '59000000-0000-0000-0000-000000000001'
        )
      )
    )
  $$,
  'P0001',
  'You do not have permission to merge taxonomy for this household.',
  'viewers cannot merge category taxonomy'
);

set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000004';

select throws_ok(
  $$
    select *
    from public.merge_household_categories(
      '38000000-0000-0000-0000-000000000001',
      '58000000-0000-0000-0000-000000000001',
      'Outsider Food',
      array['58000000-0000-0000-0000-000000000004']::uuid[],
      jsonb_build_array(
        jsonb_build_object(
          'source_subcategory_id',
          '59000000-0000-0000-0000-000000000005',
          'destination_subcategory_id',
          '59000000-0000-0000-0000-000000000001'
        )
      )
    )
  $$,
  'P0001',
  'You do not have permission to merge taxonomy for this household.',
  'non-members cannot merge category taxonomy'
);

select * from finish();

rollback;
