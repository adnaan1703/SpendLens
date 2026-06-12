begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(25);

insert into auth.users (id)
values
  ('16000000-0000-0000-0000-000000000001'),
  ('16000000-0000-0000-0000-000000000002'),
  ('16000000-0000-0000-0000-000000000003'),
  ('16000000-0000-0000-0000-000000000004');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '26000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000001',
    'Taxonomy Owner',
    'taxonomy-owner@example.test'
  ),
  (
    '26000000-0000-0000-0000-000000000002',
    '16000000-0000-0000-0000-000000000002',
    'Taxonomy Member',
    'taxonomy-member@example.test'
  ),
  (
    '26000000-0000-0000-0000-000000000003',
    '16000000-0000-0000-0000-000000000003',
    'Taxonomy Viewer',
    'taxonomy-viewer@example.test'
  ),
  (
    '26000000-0000-0000-0000-000000000004',
    '16000000-0000-0000-0000-000000000004',
    'Taxonomy Outsider',
    'taxonomy-outsider@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '36000000-0000-0000-0000-000000000001',
    'Taxonomy Household',
    '26000000-0000-0000-0000-000000000001'
  ),
  (
    '36000000-0000-0000-0000-000000000002',
    'Other Taxonomy Household',
    '26000000-0000-0000-0000-000000000004'
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
    'member'
  ),
  (
    '46000000-0000-0000-0000-000000000003',
    '36000000-0000-0000-0000-000000000001',
    '26000000-0000-0000-0000-000000000003',
    'viewer'
  ),
  (
    '46000000-0000-0000-0000-000000000004',
    '36000000-0000-0000-0000-000000000002',
    '26000000-0000-0000-0000-000000000004',
    'owner'
  );

insert into public.categories (id, household_id, name, sort_order)
values
  ('56000000-0000-0000-0000-000000000001', '36000000-0000-0000-0000-000000000001', 'Food', 1),
  ('56000000-0000-0000-0000-000000000002', '36000000-0000-0000-0000-000000000001', 'Shopping', 2),
  ('56000000-0000-0000-0000-000000000003', '36000000-0000-0000-0000-000000000001', 'Blocked', 3),
  ('56000000-0000-0000-0000-000000000004', '36000000-0000-0000-0000-000000000002', 'Other Household Category', 1);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('57000000-0000-0000-0000-000000000001', '36000000-0000-0000-0000-000000000001', '56000000-0000-0000-0000-000000000001', 'Delivery', 1),
  ('57000000-0000-0000-0000-000000000002', '36000000-0000-0000-0000-000000000001', '56000000-0000-0000-0000-000000000002', 'Marketplace', 1),
  ('57000000-0000-0000-0000-000000000003', '36000000-0000-0000-0000-000000000001', '56000000-0000-0000-0000-000000000003', 'Blocked child', 1),
  ('57000000-0000-0000-0000-000000000004', '36000000-0000-0000-0000-000000000002', '56000000-0000-0000-0000-000000000004', 'Other', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values
  (
    '66000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    'Swiggy Instamart',
    '56000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001',
    'high'
  ),
  (
    '66000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    'Amazon Shopping',
    '56000000-0000-0000-0000-000000000002',
    '57000000-0000-0000-0000-000000000002',
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
    '76000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    'swiggy instamart',
    'exact',
    '66000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001',
    10,
    'manual',
    true,
    '26000000-0000-0000-0000-000000000001',
    null
  ),
  (
    '76000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    'amazon pay',
    'exact',
    '66000000-0000-0000-0000-000000000002',
    '56000000-0000-0000-0000-000000000002',
    '57000000-0000-0000-0000-000000000002',
    10,
    'manual',
    true,
    '26000000-0000-0000-0000-000000000001',
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
values (
  '86000000-0000-0000-0000-000000000001',
  '36000000-0000-0000-0000-000000000001',
  'Shopping',
  '2026-03-01',
  50000.00,
  '26000000-0000-0000-0000-000000000001'
);

insert into public.monthly_cap_categories (
  household_id,
  monthly_cap_id,
  category_id
)
values (
  '36000000-0000-0000-0000-000000000001',
  '86000000-0000-0000-0000-000000000001',
  '56000000-0000-0000-0000-000000000002'
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
  classification_rule_id,
  source_fingerprint
)
values
  (
    '96000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-12',
    'SWIGGY INSTAMART BANGALORE',
    'swiggy instamart',
    '66000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001',
    'debit_spend',
    1200.00,
    1200.00,
    0.00,
    1200.00,
    'high',
    '76000000-0000-0000-0000-000000000001',
    'taxonomy-delete-food-1'
  ),
  (
    '96000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-03-08',
    'Amazon Pay',
    'amazon pay',
    '66000000-0000-0000-0000-000000000002',
    '56000000-0000-0000-0000-000000000002',
    '57000000-0000-0000-0000-000000000002',
    'debit_spend',
    2400.00,
    2400.00,
    0.00,
    2400.00,
    'manual',
    '76000000-0000-0000-0000-000000000002',
    'taxonomy-delete-shopping-1'
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
    '97000000-0000-0000-0000-000000000001',
    '36000000-0000-0000-0000-000000000001',
    '96000000-0000-0000-0000-000000000001',
    'Existing food suggestion',
    '66000000-0000-0000-0000-000000000001',
    '56000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001'
  ),
  (
    '97000000-0000-0000-0000-000000000002',
    '36000000-0000-0000-0000-000000000001',
    '96000000-0000-0000-0000-000000000002',
    'Existing shopping suggestion',
    '66000000-0000-0000-0000-000000000002',
    '56000000-0000-0000-0000-000000000002',
    '57000000-0000-0000-0000-000000000002'
  );

set local role authenticated;
set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000002';
set local request.jwt.claim.role = 'authenticated';

with deleted as (
  delete from public.subcategories
  where id = '57000000-0000-0000-0000-000000000001'
  returning 1
)
select is(
  (select count(*)::integer from deleted),
  0,
  'direct authenticated delete cannot remove a used subcategory before review requeue'
);

create temporary table deleted_subcategory as
select *
from public.delete_household_subcategory(
  '36000000-0000-0000-0000-000000000001',
  '56000000-0000-0000-0000-000000000001',
  '57000000-0000-0000-0000-000000000001'
);

select is((select affected_transaction_count from deleted_subcategory), 1, 'subcategory delete reports affected transactions');
select is((select opened_review_item_count from deleted_subcategory), 1, 'subcategory delete opens review items');
select is((select cleared_mapping_rule_count from deleted_subcategory), 1, 'subcategory delete clears mapping-rule subcategory references');

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '96000000-0000-0000-0000-000000000001'
      and category_id = '56000000-0000-0000-0000-000000000001'
      and subcategory_id is null
      and classification_rule_id = '76000000-0000-0000-0000-000000000001'
      and classification_updated_by = '26000000-0000-0000-0000-000000000002'
      and classification_updated_at is not null
      and classification_note = 'Taxonomy deleted: subcategory removed.'
  ),
  1,
  'subcategory delete preserves transaction category and marks audit metadata'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where transaction_id = '96000000-0000-0000-0000-000000000001'
      and reason = 'Taxonomy deleted: subcategory removed.'
      and status = 'open'
      and suggested_category_id = '56000000-0000-0000-0000-000000000001'
      and suggested_subcategory_id is null
  ),
  1,
  'subcategory delete requeues the transaction for subcategory reassignment'
);

select is(
  (
    select count(*)::integer
    from public.merchants
    where id = '66000000-0000-0000-0000-000000000001'
      and category_id = '56000000-0000-0000-0000-000000000001'
      and subcategory_id is null
  ),
  1,
  'subcategory delete clears merchant subcategory while preserving category'
);

select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where id = '76000000-0000-0000-0000-000000000001'
      and category_id = '56000000-0000-0000-0000-000000000001'
      and subcategory_id is null
      and apply_to_future
  ),
  1,
  'subcategory delete clears mapping-rule subcategory and keeps future category rule active'
);

select is(
  (
    select count(*)::integer
    from public.subcategories
    where id = '57000000-0000-0000-0000-000000000001'
  ),
  0,
  'subcategory row is deleted after references are cleared'
);

with deleted as (
  delete from public.categories
  where id = '56000000-0000-0000-0000-000000000002'
  returning 1
)
select is(
  (select count(*)::integer from deleted),
  0,
  'direct authenticated delete cannot remove a used category before review requeue'
);

create temporary table deleted_category as
select *
from public.delete_household_category(
  '36000000-0000-0000-0000-000000000001',
  '56000000-0000-0000-0000-000000000002'
);

select is((select affected_transaction_count from deleted_category), 1, 'category delete reports affected transactions');
select is((select opened_review_item_count from deleted_category), 1, 'category delete opens review items');
select is((select deactivated_mapping_rule_count from deleted_category), 1, 'category delete deactivates active mapping rules');
select is((select deleted_cap_count from deleted_category), 1, 'category delete removes caps left without targets');

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '96000000-0000-0000-0000-000000000002'
      and merchant_id = '66000000-0000-0000-0000-000000000002'
      and statement_merchant = 'Amazon Pay'
      and category_id is null
      and subcategory_id is null
      and classification_rule_id is null
      and classification_updated_by = '26000000-0000-0000-0000-000000000002'
      and classification_updated_at is not null
      and classification_note = 'Taxonomy deleted: category removed.'
  ),
  1,
  'category delete unclassifies transactions while preserving merchant and statement context'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where transaction_id = '96000000-0000-0000-0000-000000000002'
      and reason = 'Taxonomy deleted: category removed.'
      and status = 'open'
      and suggested_merchant_id = '66000000-0000-0000-0000-000000000002'
      and suggested_category_id is null
      and suggested_subcategory_id is null
  ),
  1,
  'category delete requeues the transaction for recategorization'
);

select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where id = '76000000-0000-0000-0000-000000000002'
      and category_id is null
      and subcategory_id is null
      and not apply_to_future
      and notes like '%Taxonomy deleted: category removed.%'
  ),
  1,
  'category delete deactivates and annotates future mapping rules'
);

select is(
  (
    select count(*)::integer
    from public.merchants
    where id = '66000000-0000-0000-0000-000000000002'
      and category_id is null
      and subcategory_id is null
  ),
  1,
  'category delete clears merchant taxonomy references'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where id = '97000000-0000-0000-0000-000000000002'
      and suggested_merchant_id = '66000000-0000-0000-0000-000000000002'
      and suggested_category_id is null
      and suggested_subcategory_id is null
  ),
  1,
  'category delete clears existing review suggestions that referenced deleted taxonomy'
);

select is(
  (
    select count(*)::integer
    from public.monthly_cap_categories
    where category_id = '56000000-0000-0000-0000-000000000002'
  ),
  0,
  'category delete removes monthly cap category targets'
);

select is(
  (
    select count(*)::integer
    from public.monthly_caps
    where id = '86000000-0000-0000-0000-000000000001'
  ),
  0,
  'category delete removes caps left with no targets'
);

select is(
  (
    select count(*)::integer
    from public.categories
    where id = '56000000-0000-0000-0000-000000000002'
  ),
  0,
  'category row is deleted after dependent references are handled'
);

select is(
  (
    select count(*)::integer
    from public.transactions
    where household_id = '36000000-0000-0000-0000-000000000001'
  ),
  2,
  'taxonomy deletes never delete transactions'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.delete_household_category(
      '36000000-0000-0000-0000-000000000001',
      '56000000-0000-0000-0000-000000000003'
    )
  $$,
  'P0001',
  'You do not have permission to delete taxonomy for this household.',
  'viewers cannot delete categories'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000004';

select throws_ok(
  $$
    select *
    from public.delete_household_subcategory(
      '36000000-0000-0000-0000-000000000001',
      '56000000-0000-0000-0000-000000000003',
      '57000000-0000-0000-0000-000000000003'
    )
  $$,
  'P0001',
  'You do not have permission to delete taxonomy for this household.',
  'non-members cannot delete subcategories'
);

select * from finish();

rollback;
