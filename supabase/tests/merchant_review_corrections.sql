begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(13);

insert into auth.users (id)
values ('12000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values ('22000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000001', 'Review User', 'review@example.test');

insert into public.households (id, name, created_by)
values ('32000000-0000-0000-0000-000000000001', 'Review Household', '22000000-0000-0000-0000-000000000001');

insert into public.household_members (id, household_id, profile_id, role)
values ('42000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', '22000000-0000-0000-0000-000000000001', 'owner');

insert into public.categories (id, household_id, name, sort_order)
values
  ('52000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 'Unclear', 1),
  ('52000000-0000-0000-0000-000000000002', '32000000-0000-0000-0000-000000000001', 'Shopping', 2);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('53000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'Needs Review', 1),
  ('53000000-0000-0000-0000-000000000002', '32000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000002', 'Marketplace', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values ('62000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', 'Unknown Amazon', '52000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001', 'low');

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
  (
    '72000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-02-01',
    'AMZN MKTP IN',
    'amzn mktp in',
    '62000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'debit_spend',
    100.00,
    100.00,
    0.00,
    100.00,
    'low',
    'review-amzn-1'
  ),
  (
    '72000000-0000-0000-0000-000000000002',
    '32000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-02-02',
    'AMZN MKTP IN',
    'amzn mktp in',
    '62000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'debit_spend',
    125.00,
    125.00,
    0.00,
    125.00,
    'medium',
    'review-amzn-2'
  ),
  (
    '72000000-0000-0000-0000-000000000003',
    '32000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-02-03',
    'AMAZON PRIME',
    'amazon prime',
    '62000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'debit_spend',
    999.00,
    999.00,
    0.00,
    999.00,
    'low',
    'review-prime-1'
  );

insert into public.review_items (id, household_id, transaction_id, reason, status)
values
  ('92000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', 'Unknown marketplace merchant', 'open'),
  ('92000000-0000-0000-0000-000000000002', '32000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000002', 'Related low-confidence merchant', 'open'),
  ('92000000-0000-0000-0000-000000000003', '32000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000003', 'Different Amazon merchant', 'open');

set local role authenticated;
set local request.jwt.claim.sub = '12000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is((select count(*)::integer from public.v_review_queue), 3, 'review queue starts with three open items');

create temporary table correction_result as
select *
from public.apply_merchant_review_correction(
  '32000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000001',
  'Amazon Shopping',
  '52000000-0000-0000-0000-000000000002',
  '53000000-0000-0000-0000-000000000002',
  'Prefer marketplace category'
);

select is((select updated_transaction_count from correction_result), 2, 'one correction updates matching past transactions');
select is((select resolved_review_item_count from correction_result), 2, 'one correction resolves related review items');

select is(
  (
    select count(*)::integer
    from public.merchant_mapping_rules
    where household_id = '32000000-0000-0000-0000-000000000001'
      and pattern = 'amzn mktp in'
      and match_type = 'exact'
      and confidence = 'manual'
      and apply_to_future
      and category_id = '52000000-0000-0000-0000-000000000002'
      and subcategory_id = '53000000-0000-0000-0000-000000000002'
      and created_by = '22000000-0000-0000-0000-000000000001'
      and notes = 'Prefer marketplace category'
  ),
  1,
  'correction creates a durable manual mapping rule'
);

select is(
  (
    select count(*)::integer
    from public.transactions t
    join public.merchants m on m.id = t.merchant_id and m.household_id = t.household_id
    where t.normalized_statement_merchant = 'amzn mktp in'
      and m.display_name = 'Amazon Shopping'
      and t.category_id = '52000000-0000-0000-0000-000000000002'
      and t.subcategory_id = '53000000-0000-0000-0000-000000000002'
      and t.confidence = 'manual'
  ),
  2,
  'matching historical transactions update consistently'
);

select is(
  (
    select count(*)::integer
    from public.transactions
    where normalized_statement_merchant = 'amzn mktp in'
      and classification_rule_id = (select rule_id from correction_result)
      and classification_review_item_id = '92000000-0000-0000-0000-000000000001'
      and classification_updated_by = '22000000-0000-0000-0000-000000000001'
      and classification_updated_at is not null
      and classification_note = 'Prefer marketplace category'
  ),
  2,
  'changed transaction rows keep correction audit metadata'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where id in (
      '92000000-0000-0000-0000-000000000001',
      '92000000-0000-0000-0000-000000000002'
    )
      and status = 'resolved'
      and resolved_by = '22000000-0000-0000-0000-000000000001'
      and resolved_at is not null
  ),
  2,
  'related review items are marked resolved'
);

select is((select count(*)::integer from public.v_review_queue), 1, 'review queue count decreases after resolution');

select is(
  (
    select count(*)::integer
    from public.transactions
    where normalized_statement_merchant = 'amazon prime'
      and merchant_id = '62000000-0000-0000-0000-000000000001'
      and category_id = '52000000-0000-0000-0000-000000000001'
      and subcategory_id = '53000000-0000-0000-0000-000000000001'
      and confidence = 'low'
      and classification_rule_id is null
  ),
  1,
  'non-matching merchants remain unchanged'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where id = '92000000-0000-0000-0000-000000000003'
      and status = 'open'
  ),
  1,
  'non-matching review item remains open'
);

select is(
  (
    select category_id::text
    from public.match_merchant_mapping_rule(
      '32000000-0000-0000-0000-000000000001',
      'AMZN MKTP IN'
    )
  ),
  '52000000-0000-0000-0000-000000000002',
  'future imports can apply the new manual rule'
);

select is(
  (
    select count(*)::integer
    from public.match_merchant_mapping_rule(
      '32000000-0000-0000-0000-000000000001',
      'AMAZON PRIME'
    )
  ),
  0,
  'future rule matching ignores non-matching merchants'
);

select is(
  (
    select count(*)::integer
    from public.merchant_aliases
    where household_id = '32000000-0000-0000-0000-000000000001'
      and normalized_name = 'amzn mktp in'
      and merchant_id = (select merchant_id from correction_result)
      and source_type = 'manual'
  ),
  1,
  'correction updates the exact alias for parser-first matching'
);

select * from finish();

rollback;
