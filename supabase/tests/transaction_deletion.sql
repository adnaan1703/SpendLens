begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(43);

select ok(
  (
    select c.relrowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'deleted_transaction_sources'
  ),
  'deleted transaction source tombstones have RLS enabled'
);

insert into auth.users (id)
values
  ('17000000-0000-0000-0000-000000000001'),
  ('17000000-0000-0000-0000-000000000002'),
  ('17000000-0000-0000-0000-000000000003'),
  ('17000000-0000-0000-0000-000000000004'),
  ('17000000-0000-0000-0000-000000000005'),
  ('17000000-0000-0000-0000-000000000006');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  (
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'Delete Owner',
    'delete-owner@example.test'
  ),
  (
    '27000000-0000-0000-0000-000000000002',
    '17000000-0000-0000-0000-000000000002',
    'Delete Admin',
    'delete-admin@example.test'
  ),
  (
    '27000000-0000-0000-0000-000000000003',
    '17000000-0000-0000-0000-000000000003',
    'Delete Member',
    'delete-member@example.test'
  ),
  (
    '27000000-0000-0000-0000-000000000004',
    '17000000-0000-0000-0000-000000000004',
    'Delete Viewer',
    'delete-viewer@example.test'
  ),
  (
    '27000000-0000-0000-0000-000000000005',
    '17000000-0000-0000-0000-000000000005',
    'Delete Outsider',
    'delete-outsider@example.test'
  ),
  (
    '27000000-0000-0000-0000-000000000006',
    '17000000-0000-0000-0000-000000000006',
    'Other Household Owner',
    'delete-other-owner@example.test'
  );

insert into public.households (id, name, created_by)
values
  (
    '37000000-0000-0000-0000-000000000001',
    'Deletion Household',
    '27000000-0000-0000-0000-000000000001'
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    'Other Deletion Household',
    '27000000-0000-0000-0000-000000000006'
  );

insert into public.household_members (id, household_id, profile_id, role)
values
  (
    '47000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    'owner'
  ),
  (
    '47000000-0000-0000-0000-000000000002',
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000002',
    'admin'
  ),
  (
    '47000000-0000-0000-0000-000000000003',
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000003',
    'member'
  ),
  (
    '47000000-0000-0000-0000-000000000004',
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000004',
    'viewer'
  ),
  (
    '47000000-0000-0000-0000-000000000005',
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000006',
    'owner'
  ),
  (
    '47000000-0000-0000-0000-000000000006',
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000001',
    'owner'
  );

insert into public.categories (id, household_id, name, sort_order)
values
  (
    '57000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    'Dining',
    1
  ),
  (
    '57000000-0000-0000-0000-000000000002',
    '37000000-0000-0000-0000-000000000002',
    'Other Dining',
    1
  );

insert into public.merchants (id, household_id, display_name, category_id)
values (
  '67000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  'Delete Cafe',
  '57000000-0000-0000-0000-000000000001'
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
    '77000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    'gmail',
    '2026-06-05',
    'DELETE CAFE',
    'delete cafe',
    '67000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001',
    'debit_spend',
    100.00,
    100.00,
    0.00,
    100.00,
    'low',
    'delete-gmail-1'
  ),
  (
    '77000000-0000-0000-0000-000000000002',
    '37000000-0000-0000-0000-000000000001',
    'manual',
    '2026-06-06',
    'KEEP CAFE',
    'keep cafe',
    '67000000-0000-0000-0000-000000000001',
    '57000000-0000-0000-0000-000000000001',
    'debit_spend',
    25.00,
    25.00,
    0.00,
    25.00,
    'high',
    'keep-manual-1'
  ),
  (
    '77000000-0000-0000-0000-000000000003',
    '37000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-07-02',
    'DIRECT DELETE ROW',
    'direct delete row',
    null,
    '57000000-0000-0000-0000-000000000001',
    'debit_spend',
    40.00,
    40.00,
    0.00,
    40.00,
    'medium',
    'direct-workbook-1'
  ),
  (
    '77000000-0000-0000-0000-000000000004',
    '37000000-0000-0000-0000-000000000002',
    'manual',
    '2026-06-07',
    'OTHER HOUSEHOLD ROW',
    'other household row',
    null,
    '57000000-0000-0000-0000-000000000002',
    'debit_spend',
    200.00,
    200.00,
    0.00,
    200.00,
    'medium',
    'other-household-txn'
  ),
  (
    '77000000-0000-0000-0000-000000000005',
    '37000000-0000-0000-0000-000000000001',
    'manual',
    '2026-07-03',
    'ADMIN BLOCKED ROW',
    'admin blocked row',
    null,
    '57000000-0000-0000-0000-000000000001',
    'debit_spend',
    55.00,
    55.00,
    0.00,
    55.00,
    'medium',
    'admin-blocked-delete'
  );

insert into public.transaction_sources (
  id,
  household_id,
  transaction_id,
  source_type,
  source_message_id,
  source_reference,
  source_received_at,
  parser_name,
  parser_version,
  parse_status
)
values
  (
    '78000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    '77000000-0000-0000-0000-000000000001',
    'gmail',
    'gmail-message-1',
    'gmail://message/1',
    '2026-06-05 10:00:00+00',
    'gmail_parser',
    '1.0.0',
    'parsed'
  ),
  (
    '78000000-0000-0000-0000-000000000003',
    '37000000-0000-0000-0000-000000000001',
    '77000000-0000-0000-0000-000000000003',
    'workbook',
    null,
    'Workbook row 17',
    '2026-07-02 10:00:00+00',
    'workbook_importer',
    '1.0.0',
    'parsed'
  );

insert into public.labels (id, household_id, name, created_by)
values (
  '87000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  'Reimbursable',
  '27000000-0000-0000-0000-000000000001'
);

insert into public.transaction_labels (
  household_id,
  transaction_id,
  label_id,
  created_by
)
values (
  '37000000-0000-0000-0000-000000000001',
  '77000000-0000-0000-0000-000000000001',
  '87000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001'
);

insert into public.review_items (
  id,
  household_id,
  transaction_id,
  reason
)
values (
  '88000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  '77000000-0000-0000-0000-000000000001',
  'Low confidence transaction.'
);

insert into public.piggy_banks (id, household_id, name, created_by)
values (
  '89000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  'Trip Fund',
  '27000000-0000-0000-0000-000000000001'
);

insert into public.piggy_bank_entries (
  id,
  household_id,
  piggy_bank_id,
  entry_type,
  amount,
  entry_date,
  linked_transaction_id,
  created_by
)
values (
  '90000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  '89000000-0000-0000-0000-000000000001',
  'deposit',
  10.00,
  '2026-06-05',
  '77000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001'
);

insert into public.linked_mailboxes (
  id,
  household_id,
  profile_id,
  email,
  provider,
  is_active
)
values (
  '91000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  'owner-gmail@example.test',
  'gmail',
  true
);

insert into public.gmail_parse_attempts (
  id,
  household_id,
  linked_mailbox_id,
  transaction_id,
  candidate_type,
  source_message_id,
  source_thread_id,
  source_received_at,
  sender_email,
  subject,
  parser_name,
  parser_version,
  parse_status,
  transaction_date,
  source_reference
)
values (
  '92000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001',
  '77000000-0000-0000-0000-000000000001',
  'credit_card',
  'gmail-message-1',
  'gmail-thread-1',
  '2026-06-05 10:00:00+00',
  'alerts@example.test',
  'Card transaction alert',
  'gmail_parser',
  '1.0.0',
  'parsed',
  '2026-06-05',
  'gmail://message/1'
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
  '93000000-0000-0000-0000-000000000001',
  '37000000-0000-0000-0000-000000000001',
  'Dining cap',
  '2026-06-01',
  150.00,
  '27000000-0000-0000-0000-000000000001'
);

insert into public.monthly_cap_categories (
  household_id,
  monthly_cap_id,
  category_id
)
values (
  '37000000-0000-0000-0000-000000000001',
  '93000000-0000-0000-0000-000000000001',
  '57000000-0000-0000-0000-000000000001'
);

set local role authenticated;
set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select net_spend
    from public.v_monthly_spend
    where household_id = '37000000-0000-0000-0000-000000000001'
      and period_month = '2026-06-01'
  ),
  125.00::numeric(14,2),
  'monthly spend includes target and remaining transactions before deletion'
);

select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = '93000000-0000-0000-0000-000000000001'
  ),
  125.00::numeric(14,2),
  'monthly cap progress includes target and remaining transactions before deletion'
);

create temporary table delete_result as
select *
from public.delete_transaction(
  '37000000-0000-0000-0000-000000000001',
  '77000000-0000-0000-0000-000000000001',
  '  Bad duplicate  '
);

select is(
  (select deleted_transaction_id from delete_result),
  '77000000-0000-0000-0000-000000000001'::uuid,
  'owner RPC returns the deleted transaction id'
);
select is((select source_type from delete_result), 'gmail'::public.source_type, 'owner RPC returns source type');
select is((select source_fingerprint from delete_result), 'delete-gmail-1', 'owner RPC returns source fingerprint');
select is((select deleted_label_count from delete_result), 1, 'owner RPC counts deleted labels');
select is((select deleted_source_row_count from delete_result), 1, 'owner RPC counts deleted transaction source rows');
select is((select deleted_review_item_count from delete_result), 1, 'owner RPC counts deleted review rows');
select is((select unlinked_piggy_bank_entry_count from delete_result), 1, 'owner RPC counts unlinked piggy-bank entries');
select is((select unlinked_gmail_parse_attempt_count from delete_result), 1, 'owner RPC counts unlinked Gmail parse attempts');

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '77000000-0000-0000-0000-000000000001'
  ),
  0,
  'deleted transaction row is gone'
);

select is(
  (
    select count(*)::integer
    from public.transaction_labels
    where transaction_id = '77000000-0000-0000-0000-000000000001'
  ),
  0,
  'transaction labels cascade when the transaction is deleted'
);

select is(
  (
    select count(*)::integer
    from public.transaction_sources
    where transaction_id = '77000000-0000-0000-0000-000000000001'
  ),
  0,
  'transaction source rows cascade when the transaction is deleted'
);

select is(
  (
    select count(*)::integer
    from public.review_items
    where transaction_id = '77000000-0000-0000-0000-000000000001'
  ),
  0,
  'transaction review rows cascade when the transaction is deleted'
);

select is(
  (
    select count(*)::integer
    from public.piggy_bank_entries
    where id = '90000000-0000-0000-0000-000000000001'
      and linked_transaction_id is null
  ),
  1,
  'piggy-bank entries are preserved and unlinked'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.gmail_parse_attempts
    where id = '92000000-0000-0000-0000-000000000001'
      and transaction_id is null
  ),
  1,
  'Gmail parse attempts are preserved and unlinked'
);

set local role authenticated;
set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select net_spend
    from public.v_monthly_spend
    where household_id = '37000000-0000-0000-0000-000000000001'
      and period_month = '2026-06-01'
  ),
  25.00::numeric(14,2),
  'monthly spend no longer counts the deleted transaction'
);

select is(
  (
    select net_spend
    from public.v_category_monthly_spend
    where household_id = '37000000-0000-0000-0000-000000000001'
      and category_id = '57000000-0000-0000-0000-000000000001'
      and period_month = '2026-06-01'
  ),
  25.00::numeric(14,2),
  'category monthly spend no longer counts the deleted transaction'
);

select is(
  (
    select net_spend
    from public.v_merchant_summary
    where household_id = '37000000-0000-0000-0000-000000000001'
      and merchant_id = '67000000-0000-0000-0000-000000000001'
  ),
  25.00::numeric(14,2),
  'merchant summary no longer counts the deleted transaction'
);

select is(
  (
    select spent_amount
    from public.v_monthly_cap_progress
    where monthly_cap_id = '93000000-0000-0000-0000-000000000001'
  ),
  25.00::numeric(14,2),
  'monthly cap progress no longer counts the deleted transaction'
);

select is(
  (
    select matched_transaction_count
    from public.v_monthly_cap_progress
    where monthly_cap_id = '93000000-0000-0000-0000-000000000001'
  ),
  1,
  'monthly cap matched transaction count no longer counts the deleted transaction'
);

select is(
  (
    select count(*)::integer
    from public.deleted_transaction_sources
    where household_id = '37000000-0000-0000-0000-000000000001'
  ),
  1,
  'owner can select the recorded tombstone'
);

select is(
  (
    select source_type
    from public.deleted_transaction_sources
    where source_fingerprint = 'delete-gmail-1'
  ),
  'gmail'::public.source_type,
  'tombstone records minimal source type'
);

select is(
  (
    select source_message_id
    from public.deleted_transaction_sources
    where source_fingerprint = 'delete-gmail-1'
  ),
  'gmail-message-1',
  'tombstone records minimal source message id'
);

select is(
  (
    select source_reference
    from public.deleted_transaction_sources
    where source_fingerprint = 'delete-gmail-1'
  ),
  'gmail://message/1',
  'tombstone records minimal source reference'
);

select is(
  (
    select deleted_by
    from public.deleted_transaction_sources
    where source_fingerprint = 'delete-gmail-1'
  ),
  '27000000-0000-0000-0000-000000000001'::uuid,
  'tombstone records the owner profile that deleted the transaction'
);

select is(
  (
    select reason
    from public.deleted_transaction_sources
    where source_fingerprint = 'delete-gmail-1'
  ),
  'Bad duplicate',
  'tombstone records the trimmed optional reason'
);

select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'deleted_transaction_sources'
      and column_name = any (array[
        'amount',
        'gross_spend',
        'refund_amount',
        'net_expense',
        'statement_merchant',
        'normalized_statement_merchant',
        'merchant_id',
        'category_id',
        'subcategory_id',
        'cardholder_name',
        'notes',
        'diagnostics'
      ])
  ),
  0,
  'tombstone table does not store transaction payload or diagnostics columns'
);

delete from public.transactions
where id = '77000000-0000-0000-0000-000000000003';

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '77000000-0000-0000-0000-000000000003'
  ),
  0,
  'direct owner delete removes the transaction row'
);

select is(
  (
    select source_reference
    from public.deleted_transaction_sources
    where source_fingerprint = 'direct-workbook-1'
  ),
  'Workbook row 17',
  'direct owner delete records a tombstone through the trigger'
);

select is(
  (
    select deleted_by
    from public.deleted_transaction_sources
    where source_fingerprint = 'direct-workbook-1'
  ),
  '27000000-0000-0000-0000-000000000001'::uuid,
  'direct owner delete records the deleting profile'
);

select is(
  (
    select reason
    from public.deleted_transaction_sources
    where source_fingerprint = 'direct-workbook-1'
  ),
  null,
  'direct owner delete stores no reason when no RPC reason was provided'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000002';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000005',
      null
    )
  $$,
  'P0001',
  'You do not have permission to delete transactions for this household.',
  'household admins cannot delete transactions through the RPC'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000003';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000005',
      null
    )
  $$,
  'P0001',
  'You do not have permission to delete transactions for this household.',
  'household members cannot delete transactions through the RPC'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000004';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000005',
      null
    )
  $$,
  'P0001',
  'You do not have permission to delete transactions for this household.',
  'household viewers cannot delete transactions through the RPC'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000005';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000005',
      null
    )
  $$,
  'P0001',
  'You do not have permission to delete transactions for this household.',
  'non-members cannot delete transactions through the RPC'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000006';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000005',
      null
    )
  $$,
  'P0001',
  'You do not have permission to delete transactions for this household.',
  'other-household owners cannot delete transactions through the RPC'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000001';

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000004',
      null
    )
  $$,
  'P0001',
  'Transaction does not belong to this household.',
  'cross-household transaction ids are rejected'
);

select throws_ok(
  $$
    select *
    from public.delete_transaction(
      '37000000-0000-0000-0000-000000000001',
      '77000000-0000-0000-0000-000000000099',
      null
    )
  $$,
  'P0001',
  'Transaction not found.',
  'missing transaction ids raise a clear error'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000002';

delete from public.transactions
where id = '77000000-0000-0000-0000-000000000005';

select is(
  (
    select count(*)::integer
    from public.transactions
    where id = '77000000-0000-0000-0000-000000000005'
  ),
  1,
  'direct non-owner delete is blocked by transaction RLS'
);

set local request.jwt.claim.sub = '17000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)::integer
    from public.deleted_transaction_sources
    where source_fingerprint = 'admin-blocked-delete'
  ),
  0,
  'blocked direct non-owner delete does not record a tombstone'
);

reset role;
set local role service_role;

select is(
  (
    select count(*)::integer
    from public.deleted_transaction_sources
    where household_id = '37000000-0000-0000-0000-000000000001'
  ),
  2,
  'service role can select tombstones for ingestion suppression'
);

select * from finish();

rollback;
