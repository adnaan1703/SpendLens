begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

insert into auth.users (id)
values ('11000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'Summary User', 'summary@example.test');

insert into public.households (id, name, created_by)
values ('31000000-0000-0000-0000-000000000001', 'Summary Household', '21000000-0000-0000-0000-000000000001');

insert into public.household_members (id, household_id, profile_id, role)
values ('41000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'owner');

delete from public.subcategories
where household_id = '31000000-0000-0000-0000-000000000001';

delete from public.categories
where household_id = '31000000-0000-0000-0000-000000000001';

insert into public.categories (id, household_id, name, sort_order)
values
  ('51000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Food & Dining', 1),
  ('51000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'Travel & Visa', 2);

insert into public.merchants (id, household_id, display_name, category_id, confidence)
values
  ('61000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Swiggy/Zomato/Food delivery', '51000000-0000-0000-0000-000000000001', 'high'),
  ('61000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'HDFC SmartBuy - Flights', '51000000-0000-0000-0000-000000000002', 'high');

insert into public.transactions (
  id,
  household_id,
  source_type,
  transaction_date,
  statement_merchant,
  normalized_statement_merchant,
  merchant_id,
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
    '71000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-01-05',
    'SWIGGY BANGALORE',
    'swiggy bangalore',
    '61000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    'debit_spend',
    1000.00,
    1000.00,
    0.00,
    1000.00,
    'summary-food-1'
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    '31000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-01-12',
    'ZOMATO GURGAON',
    'zomato gurgaon',
    '61000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    'debit_spend',
    250.00,
    250.00,
    0.00,
    250.00,
    'summary-food-2'
  ),
  (
    '71000000-0000-0000-0000-000000000003',
    '31000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-01-14',
    'ZOMATO REFUND',
    'zomato refund',
    '61000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000001',
    'refund_reversal',
    -100.00,
    0.00,
    100.00,
    -100.00,
    'summary-food-refund'
  ),
  (
    '71000000-0000-0000-0000-000000000004',
    '31000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-01-20',
    'HDFC SMARTBUY FLIGHT',
    'hdfc smartbuy flight',
    '61000000-0000-0000-0000-000000000002',
    '51000000-0000-0000-0000-000000000002',
    'debit_spend',
    300.00,
    300.00,
    0.00,
    300.00,
    'summary-travel-1'
  ),
  (
    '71000000-0000-0000-0000-000000000005',
    '31000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-01-25',
    'TELE TRANSFER CREDIT',
    'tele transfer credit',
    null,
    null,
    'bill_payment_credit',
    -5000.00,
    0.00,
    0.00,
    0.00,
    'summary-bill-payment'
  );

insert into public.category_caps (id, household_id, category_id, period_month, cap_amount, created_by)
values
  ('81000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', '2026-01-01', 1000.00, '21000000-0000-0000-0000-000000000001'),
  ('81000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000002', '2026-01-01', 200.00, '21000000-0000-0000-0000-000000000001');

insert into public.review_items (id, household_id, transaction_id, reason, status)
values
  ('91000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003', 'Low confidence refund mapping', 'open'),
  ('91000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000004', 'Already handled', 'dismissed');

insert into public.piggy_banks (id, household_id, name, target_amount, created_by)
values ('a1000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Vacation', 1000.00, '21000000-0000-0000-0000-000000000001');

insert into public.piggy_bank_entries (id, household_id, piggy_bank_id, entry_type, amount, entry_date, note, created_by)
values
  ('a2000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'deposit', 500.00, '2026-01-02', 'Initial deposit', '21000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'withdrawal', 125.00, '2026-01-10', 'Partial use', '21000000-0000-0000-0000-000000000001'),
  ('a2000000-0000-0000-0000-000000000003', '31000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'adjustment', -25.00, '2026-01-15', 'Correction', '21000000-0000-0000-0000-000000000001');

set local role authenticated;
set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is((select transaction_count from public.v_monthly_spend where period_month = '2026-01-01'), 5, 'monthly spend counts all transaction rows');
select is((select gross_spend from public.v_monthly_spend where period_month = '2026-01-01'), 1550.00::numeric(14,2), 'monthly spend sums gross spend');
select is((select refund_amount from public.v_monthly_spend where period_month = '2026-01-01'), 100.00::numeric(14,2), 'monthly spend sums refunds');
select is((select net_spend from public.v_monthly_spend where period_month = '2026-01-01'), 1450.00::numeric(14,2), 'monthly spend nets refunds against gross spend');
select is((select bill_payments from public.v_monthly_spend where period_month = '2026-01-01'), 5000.00::numeric(14,2), 'monthly spend tracks bill payments separately');

select is(
  (
    select net_spend
    from public.v_category_monthly_spend
    where period_month = '2026-01-01'
      and category_name = 'Food & Dining'
  ),
  1150.00::numeric(14,2),
  'category monthly spend nets food refunds'
);

select is((select spent_amount from public.v_budget_progress where category_name = 'Food & Dining'), 1150.00::numeric(14,2), 'budget progress uses category net spend');
select is((select remaining_amount from public.v_budget_progress where category_name = 'Food & Dining'), -150.00::numeric(14,2), 'budget progress shows negative remaining amount when over cap');
select is((select percent_used from public.v_budget_progress where category_name = 'Food & Dining'), 1.1500::numeric, 'budget progress calculates percent used');
select ok((select is_over_budget from public.v_budget_progress where category_name = 'Food & Dining'), 'budget progress flags over-budget category');

select is((select net_spend from public.v_merchant_summary where merchant_name = 'Swiggy/Zomato/Food delivery'), 1150.00::numeric(14,2), 'merchant summary nets refunds');
select is((select count(*)::integer from public.v_review_queue), 1, 'review queue includes only open items');
select is((select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'), 350.00::numeric(14,2), 'piggy-bank balance is ledger-derived');
select is((select target_progress from public.v_piggy_bank_balances where name = 'Vacation'), 0.3500::numeric, 'piggy-bank progress uses derived balance over target');

select * from finish();

rollback;
