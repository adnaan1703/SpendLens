begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

insert into auth.users (id)
values ('13000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values (
  '23000000-0000-0000-0000-000000000001',
  '13000000-0000-0000-0000-000000000001',
  'Piggy User',
  'piggy@example.test'
);

insert into public.households (id, name, created_by)
values (
  '33000000-0000-0000-0000-000000000001',
  'Piggy Household',
  '23000000-0000-0000-0000-000000000001'
);

insert into public.household_members (id, household_id, profile_id, role)
values (
  '43000000-0000-0000-0000-000000000001',
  '33000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000001',
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
  source_fingerprint
)
values (
  '73000000-0000-0000-0000-000000000001',
  '33000000-0000-0000-0000-000000000001',
  'manual',
  '2026-02-01',
  'Travel booking',
  'travel booking',
  'debit_spend',
  50.00,
  50.00,
  0.00,
  50.00,
  'piggy-linked-txn'
);

insert into public.piggy_banks (
  id,
  household_id,
  name,
  description,
  target_amount,
  target_date,
  created_by
)
values (
  'a3000000-0000-0000-0000-000000000001',
  '33000000-0000-0000-0000-000000000001',
  'Vacation',
  'Flights and stay',
  1000.00,
  '2026-12-31',
  '23000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub = '13000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'),
  0.00::numeric(14,2),
  'new piggy-bank balance starts at zero'
);

select is(
  (select target_progress from public.v_piggy_bank_balances where name = 'Vacation'),
  0.0000::numeric,
  'target progress starts at zero for positive targets'
);

select is(
  (
    select amount
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'deposit',
      500.00,
      '2026-02-02',
      'Initial deposit'
    )
  ),
  500.00::numeric(14,2),
  'deposit RPC creates a positive deposit'
);

select is(
  (select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'),
  500.00::numeric(14,2),
  'deposit increases ledger-derived balance'
);

select is(
  (select target_progress from public.v_piggy_bank_balances where name = 'Vacation'),
  0.5000::numeric,
  'deposit updates target progress'
);

select is(
  (
    select amount
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'withdrawal',
      125.00,
      '2026-02-05',
      'Partial use'
    )
  ),
  125.00::numeric(14,2),
  'withdrawal RPC creates a positive withdrawal'
);

select is(
  (select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'),
  375.00::numeric(14,2),
  'withdrawal decreases ledger-derived balance'
);

select is(
  (
    select amount
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'adjustment',
      -25.00,
      '2026-02-08',
      'Correction'
    )
  ),
  -25.00::numeric(14,2),
  'explicit adjustment can reduce the balance'
);

select is(
  (select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'),
  350.00::numeric(14,2),
  'adjustment contributes to ledger-derived balance'
);

select is(
  (
    select linked_transaction_id
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'deposit',
      50.00,
      '2026-02-10',
      'Linked spend reimbursement',
      '73000000-0000-0000-0000-000000000001'
    )
  ),
  '73000000-0000-0000-0000-000000000001'::uuid,
  'entry RPC can link to a household transaction'
);

select is(
  (select balance_amount from public.v_piggy_bank_balances where name = 'Vacation'),
  400.00::numeric(14,2),
  'linked deposit still updates balance'
);

select throws_ok(
  $$
    select *
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'withdrawal',
      401.00,
      '2026-02-11',
      'Overdraft attempt'
    )
  $$,
  'P0001',
  'Withdrawal cannot exceed current piggy-bank balance.',
  'withdrawal cannot exceed current balance'
);

select throws_ok(
  $$
    select *
    from public.create_piggy_bank_entry(
      '33000000-0000-0000-0000-000000000001',
      'a3000000-0000-0000-0000-000000000001',
      'deposit',
      0.00,
      '2026-02-12',
      'Invalid deposit'
    )
  $$,
  'P0001',
  'Deposits and withdrawals require a positive amount.',
  'deposit amount must be positive'
);

select is(
  (
    select count(*)::integer
    from public.piggy_bank_entries
    where piggy_bank_id = 'a3000000-0000-0000-0000-000000000001'
  ),
  4,
  'invalid entry attempts do not add ledger rows'
);

select * from finish();

rollback;
