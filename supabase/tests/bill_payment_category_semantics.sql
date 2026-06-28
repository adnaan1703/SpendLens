begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(10);

insert into auth.users (id)
values ('18000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values (
  '28000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000001',
  'Bill Payment Owner',
  'bill-payment@example.test'
);

insert into public.households (id, name, created_by)
values
  (
    '38000000-0000-0000-0000-000000000001',
    'Bill Payment Household',
    '28000000-0000-0000-0000-000000000001'
  ),
  (
    '38000000-0000-0000-0000-000000000002',
    'Bill Payment Rename Household',
    '28000000-0000-0000-0000-000000000001'
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
    '38000000-0000-0000-0000-000000000002',
    '28000000-0000-0000-0000-000000000001',
    'owner'
  );

delete from public.subcategories
where household_id in (
  '38000000-0000-0000-0000-000000000001',
  '38000000-0000-0000-0000-000000000002'
);

delete from public.categories
where household_id in (
  '38000000-0000-0000-0000-000000000001',
  '38000000-0000-0000-0000-000000000002'
);

insert into public.categories (id, household_id, name, sort_order)
values
  (
    '58000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'Payments/Credits (not expense)',
    1
  ),
  (
    '58000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    'Dining',
    2
  ),
  (
    '58000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    'Travel',
    3
  ),
  (
    '58000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000002',
    'Card Settlements',
    1
  );

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  (
    '68000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000001',
    'Statement credits',
    1
  ),
  (
    '68000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000002',
    'Restaurants',
    1
  ),
  (
    '68000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000003',
    'Flights',
    1
  ),
  (
    '68000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000004',
    'Statement credits',
    1
  );

insert into public.transactions (
  id,
  household_id,
  source_type,
  transaction_date,
  statement_merchant,
  normalized_statement_merchant,
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
    '78000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-05',
    'CARD PAYMENT',
    'card payment',
    '58000000-0000-0000-0000-000000000001',
    '68000000-0000-0000-0000-000000000001',
    'debit_spend',
    -132790.49,
    132790.49,
    0.00,
    132790.49,
    'high',
    'bill-payment-card-payment'
  ),
  (
    '78000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-08',
    'CAFE',
    'cafe',
    '58000000-0000-0000-0000-000000000002',
    '68000000-0000-0000-0000-000000000002',
    'debit_spend',
    300.00,
    300.00,
    0.00,
    300.00,
    'high',
    'bill-payment-cafe'
  ),
  (
    '78000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-04-12',
    'ZERO CARD PAYMENT',
    'zero card payment',
    '58000000-0000-0000-0000-000000000001',
    '68000000-0000-0000-0000-000000000001',
    'debit_spend',
    0.00,
    1.00,
    0.00,
    1.00,
    'high',
    'bill-payment-zero'
  ),
  (
    '78000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000002',
    'workbook',
    '2026-04-15',
    'LEGACY CARD PAYMENT',
    'legacy card payment',
    '58000000-0000-0000-0000-000000000004',
    '68000000-0000-0000-0000-000000000004',
    'debit_spend',
    -790.49,
    790.49,
    0.00,
    790.49,
    'high',
    'bill-payment-legacy'
  );

insert into public.review_items (id, household_id, transaction_id, reason, status)
values
  (
    '98000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '78000000-0000-0000-0000-000000000001',
    'Keep review independent',
    'open'
  ),
  (
    '98000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000002',
    '78000000-0000-0000-0000-000000000004',
    'Keep rename review independent',
    'open'
  );

set local role authenticated;
set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

create temporary table statement_credits_cap as
select *
from public.upsert_monthly_cap(
  p_household_id => '38000000-0000-0000-0000-000000000001',
  p_name => 'Statement credits cap',
  p_period_month => '2026-04-01',
  p_cap_amount => 500.00,
  p_category_ids => array['58000000-0000-0000-0000-000000000001'::uuid],
  p_carry_forward_enabled => true
);

select is(
  (
    select row(
      transaction_type,
      amount,
      gross_spend,
      refund_amount,
      net_expense
    )::text
    from public.transactions
    where id = '78000000-0000-0000-0000-000000000001'
  ),
  row(
    'bill_payment_credit'::public.transaction_type,
    -132790.49::numeric(14,2),
    0.00::numeric(14,2),
    0.00::numeric(14,2),
    0.00::numeric(14,2)
  )::text,
  'insert into exact Payments/Credits category forces bill-payment money shape and preserves amount'
);

select is(
  (
    select row(gross_spend, net_spend, bill_payments)::text
    from public.v_monthly_spend
    where household_id = '38000000-0000-0000-0000-000000000001'
      and period_month = '2026-04-01'
  ),
  row(
    300.00::numeric(14,2),
    300.00::numeric(14,2),
    132790.49::numeric(14,2)
  )::text,
  'monthly spend moves Payments/Credits rows out of gross/net and into bills paid'
);

select is(
  (
    select spent_amount
    from public.get_monthly_cap_progress(
      '38000000-0000-0000-0000-000000000001',
      '2026-04-01'
    )
    where monthly_cap_id = (select monthly_cap_id from statement_credits_cap)
  ),
  0.00::numeric(14,2),
  'monthly cap progress excludes bill-payment rows through zero net expense'
);

update public.transactions
set
  category_id = '58000000-0000-0000-0000-000000000001',
  subcategory_id = '68000000-0000-0000-0000-000000000001'
where id = '78000000-0000-0000-0000-000000000002';

select is(
  (
    select row(transaction_type, gross_spend, refund_amount, net_expense)::text
    from public.transactions
    where id = '78000000-0000-0000-0000-000000000002'
  ),
  row(
    'bill_payment_credit'::public.transaction_type,
    0.00::numeric(14,2),
    0.00::numeric(14,2),
    0.00::numeric(14,2)
  )::text,
  'update into exact Payments/Credits category forces bill-payment shape'
);

update public.transactions
set
  category_id = '58000000-0000-0000-0000-000000000003',
  subcategory_id = '68000000-0000-0000-0000-000000000003'
where id = '78000000-0000-0000-0000-000000000002';

select is(
  (
    select row(transaction_type, gross_spend, refund_amount, net_expense)::text
    from public.transactions
    where id = '78000000-0000-0000-0000-000000000002'
  ),
  row(
    'debit_spend'::public.transaction_type,
    300.00::numeric(14,2),
    0.00::numeric(14,2),
    300.00::numeric(14,2)
  )::text,
  'moving a transaction away from Payments/Credits converts it to debit spend shape'
);

select throws_ok(
  $$
    update public.transactions
    set
      category_id = '58000000-0000-0000-0000-000000000003',
      subcategory_id = '68000000-0000-0000-0000-000000000003'
    where id = '78000000-0000-0000-0000-000000000003'
  $$,
  'P0001',
  'Cannot move a zero-amount Payments/Credits transaction out of the bill-payment category.',
  'moving a zero-amount bill-payment transaction away fails clearly'
);

create temporary table renamed_to_bill_payment as
select *
from public.update_household_category_taxonomy(
  '38000000-0000-0000-0000-000000000002',
  '58000000-0000-0000-0000-000000000004',
  'Payments/Credits (not expense)',
  '[{"id":"68000000-0000-0000-0000-000000000004","name":"Statement credits"}]'::jsonb
);

select is(
  (
    select row(transaction_type, gross_spend, refund_amount, net_expense)::text
    from public.transactions
    where id = '78000000-0000-0000-0000-000000000004'
  ),
  row(
    'bill_payment_credit'::public.transaction_type,
    0.00::numeric(14,2),
    0.00::numeric(14,2),
    0.00::numeric(14,2)
  )::text,
  'renaming a category to exact Payments/Credits reshapes existing transactions'
);

create temporary table renamed_from_bill_payment as
select *
from public.update_household_category_taxonomy(
  '38000000-0000-0000-0000-000000000002',
  '58000000-0000-0000-0000-000000000004',
  'Card Settlements',
  '[{"id":"68000000-0000-0000-0000-000000000004","name":"Statement credits"}]'::jsonb
);

select is(
  (
    select row(transaction_type, gross_spend, refund_amount, net_expense)::text
    from public.transactions
    where id = '78000000-0000-0000-0000-000000000004'
  ),
  row(
    'debit_spend'::public.transaction_type,
    790.49::numeric(14,2),
    0.00::numeric(14,2),
    790.49::numeric(14,2)
  )::text,
  'renaming exact Payments/Credits away reshapes existing transactions to debit spend'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where id in (
      '98000000-0000-0000-0000-000000000001',
      '98000000-0000-0000-0000-000000000002'
    )
      and status = 'open'
  ),
  2,
  'bill-payment normalization leaves open Review rows unchanged'
);

select is(
  (
    select row(gross_spend, net_spend, bill_payments)::text
    from public.v_monthly_spend
    where household_id = '38000000-0000-0000-0000-000000000002'
      and period_month = '2026-04-01'
  ),
  row(
    790.49::numeric(14,2),
    790.49::numeric(14,2),
    0.00::numeric(14,2)
  )::text,
  'summary views reflect category rename away from exact Payments/Credits'
);

select * from finish();

rollback;
