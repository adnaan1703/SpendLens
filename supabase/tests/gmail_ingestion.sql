begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(23);

select isnt(
  (select installed_version from pg_available_extensions where name = 'supabase_vault'),
  null,
  'Supabase Vault is available for Gmail refresh tokens'
);

select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'v_linked_mailbox_status'
      and column_name = 'oauth_secret_ref'
  ),
  0,
  'mailbox status view does not expose the OAuth secret reference'
);

select is(
  has_table_privilege('authenticated', 'public.gmail_oauth_states', 'select'),
  false,
  'authenticated users cannot read OAuth state rows'
);

select is(
  has_table_privilege('authenticated', 'public.ingestion_jobs', 'select'),
  true,
  'authenticated users can read RLS-scoped ingestion job metadata'
);

insert into auth.users (id)
values
  ('11000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000002');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'Gmail User A', 'gmail-a@example.test'),
  ('21000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000002', 'Gmail User B', 'gmail-b@example.test');

insert into public.households (id, name, created_by)
values
  ('31000000-0000-0000-0000-000000000001', 'Gmail Household A', '21000000-0000-0000-0000-000000000001'),
  ('31000000-0000-0000-0000-000000000002', 'Gmail Household B', '21000000-0000-0000-0000-000000000002');

insert into public.household_members (id, household_id, profile_id, role)
values
  ('41000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', '21000000-0000-0000-0000-000000000001', 'owner'),
  ('41000000-0000-0000-0000-000000000002', '31000000-0000-0000-0000-000000000002', '21000000-0000-0000-0000-000000000002', 'owner');

insert into public.categories (id, household_id, name)
values ('51000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'Rent');

insert into public.merchants (
  id,
  household_id,
  display_name,
  category_id,
  confidence
)
values (
  '61000000-0000-0000-0000-000000000001',
  '31000000-0000-0000-0000-000000000001',
  'NoBroker',
  '51000000-0000-0000-0000-000000000001',
  'high'
);

insert into public.merchant_mapping_rules (
  id,
  household_id,
  pattern,
  match_type,
  merchant_id,
  category_id,
  priority,
  confidence,
  apply_to_future
)
values (
  '71000000-0000-0000-0000-000000000001',
  '31000000-0000-0000-0000-000000000001',
  public.normalize_merchant_name('NOBROKER'),
  'exact',
  '61000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  10,
  'high',
  true
);

set local role service_role;

create temporary table test_mailbox as
select *
from public.upsert_gmail_mailbox(
  '31000000-0000-0000-0000-000000000001',
  '21000000-0000-0000-0000-000000000001',
  'SpendLens.HDFC@example.test',
  'refresh-token-test',
  'gmail-profile-1',
  'https://www.googleapis.com/auth/gmail.readonly',
  '9001',
  '2026-06-14 00:00:00+00',
  '2026-06-07 14:00:00+00'
);

reset role;

select is(
  (select count(*)::integer from public.linked_mailboxes where provider = 'gmail' and is_active),
  1,
  'Gmail mailbox is stored as active after OAuth callback handling'
);

select is(
  (
    select decrypted_secret
    from vault.decrypted_secrets
    where id = (
      select oauth_secret_ref::uuid
      from public.linked_mailboxes
      where provider = 'gmail'
    )
  ),
  'refresh-token-test',
  'Gmail refresh token is stored in Vault'
);

select is(
  (select count(*)::integer from public.ingestion_jobs where job_type = 'gmail_backfill'),
  1,
  'initial connector setup queues a bounded Gmail backfill'
);

set local role authenticated;
set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*)::integer from public.v_linked_mailbox_status),
  1,
  'mailbox status view shows the connected mailbox to the owning household'
);

set local request.jwt.claim.sub = '11000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::integer from public.v_linked_mailbox_status),
  0,
  'mailbox status view is scoped by household RLS'
);

reset role;
set local role service_role;

select public.enqueue_gmail_sync_from_notification(
  'spendlens.hdfc@example.test',
  '9002',
  'pubsub-message-1',
  'projects/spendlens-498416/subscriptions/gmail-notifications-push'
);

select public.enqueue_gmail_sync_from_notification(
  'spendlens.hdfc@example.test',
  '9002',
  'pubsub-message-1',
  'projects/spendlens-498416/subscriptions/gmail-notifications-push'
);

reset role;

select is(
  (select count(*)::integer from public.ingestion_jobs where job_type = 'gmail_sync'),
  1,
  'duplicate Pub/Sub delivery does not create duplicate Gmail sync jobs'
);

set local role service_role;

select public.mark_gmail_mailbox_error(
  (select id from test_mailbox),
  'invalid_grant: token revoked',
  'failed'
);

reset role;

select is(
  (
    select last_error
    from public.linked_mailboxes
    where id = (select id from test_mailbox)
  ),
  'invalid_grant: token revoked',
  'revoked token handling stores connector failure for the mailbox'
);

set local role service_role;

select *
from public.ingest_gmail_transaction(
  (select id from test_mailbox),
  jsonb_build_object(
    'id', 'gmail-message-1',
    'threadId', 'gmail-thread-1',
    'receivedAt', '2026-06-05 13:12:30+05:30'
  ),
  jsonb_build_object(
    'parser_name', 'hdfc_credit_card_debit',
    'parser_version', '1.0.0',
    'transaction_date', '2026-06-05',
    'transaction_time', '13:12:29',
    'amount', 55063.06,
    'currency_code', 'INR',
    'statement_merchant', 'NOBROKER',
    'transaction_type', 'debit_spend',
    'source_reference', 'gmail-message-1',
    'confidence', 'high',
    'source_account_hint', jsonb_build_object(
      'type', 'credit_card',
      'display_name', 'HDFC Credit Card ending 3604',
      'institution_name', 'HDFC Bank',
      'masked_identifier', '3604'
    ),
    'diagnostics', '{}'::jsonb
  ),
  'gmail-fingerprint-1'
);

select *
from public.ingest_gmail_transaction(
  (select id from test_mailbox),
  jsonb_build_object(
    'id', 'gmail-message-1',
    'threadId', 'gmail-thread-1',
    'receivedAt', '2026-06-05 13:12:30+05:30'
  ),
  jsonb_build_object(
    'parser_name', 'hdfc_credit_card_debit',
    'parser_version', '1.0.0',
    'transaction_date', '2026-06-05',
    'transaction_time', '13:12:29',
    'amount', 55063.06,
    'currency_code', 'INR',
    'statement_merchant', 'NOBROKER',
    'transaction_type', 'debit_spend',
    'source_reference', 'gmail-message-1',
    'confidence', 'high',
    'source_account_hint', jsonb_build_object(
      'type', 'credit_card',
      'display_name', 'HDFC Credit Card ending 3604',
      'institution_name', 'HDFC Bank',
      'masked_identifier', '3604'
    ),
    'diagnostics', '{}'::jsonb
  ),
  'gmail-fingerprint-1'
);

reset role;

select is(
  (select count(*)::integer from public.transactions where source_type = 'gmail'),
  1,
  'Gmail transaction import is idempotent by source fingerprint'
);

select is(
  (select count(*)::integer from public.transaction_sources where source_type = 'gmail'),
  1,
  'Gmail transaction source metadata is idempotent by message and parser'
);

select is(
  (select count(*)::integer from public.review_items where status = 'open'),
  0,
  'known high-confidence merchant mapping avoids review item creation'
);

set local role service_role;

select *
from public.ingest_gmail_transaction(
  (select id from test_mailbox),
  jsonb_build_object(
    'id', 'gmail-message-2',
    'threadId', 'gmail-thread-2',
    'receivedAt', '2026-06-06 21:42:12+05:30'
  ),
  jsonb_build_object(
    'parser_name', 'hdfc_credit_card_debit',
    'parser_version', '1.0.0',
    'transaction_date', '2026-06-06',
    'transaction_time', '21:42:11',
    'amount', 966.99,
    'currency_code', 'INR',
    'statement_merchant', 'RAZ*Plazza',
    'transaction_type', 'debit_spend',
    'source_reference', 'gmail-message-2',
    'confidence', 'high',
    'source_account_hint', jsonb_build_object(
      'type', 'credit_card',
      'display_name', 'HDFC Credit Card ending 3604',
      'institution_name', 'HDFC Bank',
      'masked_identifier', '3604'
    ),
    'diagnostics', '{}'::jsonb
  ),
  'gmail-fingerprint-2'
);

reset role;

select is(
  (select count(*)::integer from public.review_items where status = 'open'),
  1,
  'unknown Gmail merchant creates an open review item'
);

set local role service_role;

select *
from public.ingest_gmail_transaction(
  (select id from test_mailbox),
  jsonb_build_object(
    'id', 'gmail-upi-message-1',
    'threadId', 'gmail-upi-thread-1',
    'receivedAt', '2026-06-05 13:14:00+05:30'
  ),
  jsonb_build_object(
    'parser_name', 'hdfc_upi_debit',
    'parser_version', '1.0.0',
    'transaction_date', '2026-06-05',
    'transaction_time', null,
    'amount', 112937.00,
    'currency_code', 'INR',
    'statement_merchant', 'CRED Club',
    'transaction_type', 'debit_spend',
    'source_reference', '652216925085',
    'confidence', 'high',
    'source_account_hint', jsonb_build_object(
      'type', 'upi',
      'display_name', 'HDFC Bank UPI account ending 0932',
      'institution_name', 'HDFC Bank',
      'masked_identifier', '0932'
    ),
    'diagnostics', jsonb_build_object(
      'template', 'hdfc_upi_debit_v1',
      'has_payee_label', true
    )
  ),
  'gmail-upi-fingerprint-1'
);

select *
from public.ingest_gmail_transaction(
  (select id from test_mailbox),
  jsonb_build_object(
    'id', 'gmail-upi-message-duplicate',
    'threadId', 'gmail-upi-thread-duplicate',
    'receivedAt', '2026-06-05 13:15:00+05:30'
  ),
  jsonb_build_object(
    'parser_name', 'hdfc_upi_debit',
    'parser_version', '1.0.0',
    'transaction_date', '2026-06-05',
    'transaction_time', null,
    'amount', 112937.00,
    'currency_code', 'INR',
    'statement_merchant', 'CRED Club',
    'transaction_type', 'debit_spend',
    'source_reference', '652216925085',
    'confidence', 'high',
    'source_account_hint', jsonb_build_object(
      'type', 'upi',
      'display_name', 'HDFC Bank UPI account ending 0932',
      'institution_name', 'HDFC Bank',
      'masked_identifier', '0932'
    ),
    'diagnostics', jsonb_build_object(
      'template', 'hdfc_upi_debit_v1',
      'has_payee_label', true
    )
  ),
  'gmail-upi-fingerprint-1'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.source_accounts
    where household_id = '31000000-0000-0000-0000-000000000001'
      and type = 'upi'
      and institution_name = 'HDFC Bank'
      and masked_identifier = '0932'
  ),
  1,
  'UPI Gmail import creates one HDFC UPI source account'
);

select is(
  (
    select count(distinct t.id)::integer
    from public.transactions t
    join public.source_accounts sa
      on sa.id = t.source_account_id
    join public.transaction_sources ts
      on ts.transaction_id = t.id
     and ts.source_reference = '652216925085'
    where t.household_id = '31000000-0000-0000-0000-000000000001'
      and t.source_fingerprint = 'gmail-upi-fingerprint-1'
      and t.statement_merchant = 'CRED Club'
      and t.net_expense = 112937.00
      and sa.type = 'upi'
  ),
  1,
  'UPI duplicate import remains one transaction by source fingerprint'
);

select is(
  (select count(*)::integer from public.review_items where status = 'open'),
  2,
  'unknown UPI payee creates an open review item'
);

set local role service_role;

select public.record_gmail_parse_attempt(
  (select id from test_mailbox),
  (
    select id
    from public.transactions
    where source_fingerprint = 'gmail-upi-fingerprint-1'
  ),
  'gmail-upi-message-1',
  'gmail-upi-thread-1',
  '2026-05-31 23:00:00+05:30',
  'alerts@hdfcbank.bank.in',
  'You have done a UPI txn. Check details!',
  'upi',
  'hdfc_upi_debit',
  '1.0.0',
  'parsed',
  '2026-06-05',
  '652216925085',
  jsonb_build_object('template', 'hdfc_upi_debit_v1')
);

select public.record_gmail_parse_attempt(
  (select id from test_mailbox),
  (
    select id
    from public.transactions
    where source_fingerprint = 'gmail-upi-fingerprint-1'
  ),
  'gmail-upi-message-1',
  'gmail-upi-thread-1',
  '2026-05-31 23:00:00+05:30',
  'alerts@hdfcbank.bank.in',
  'You have done a UPI txn. Check details!',
  'upi',
  'hdfc_upi_debit',
  '1.0.0',
  'parsed',
  '2026-06-05',
  '652216925085',
  jsonb_build_object('template', 'hdfc_upi_debit_v1')
);

select public.record_gmail_parse_attempt(
  (select id from test_mailbox),
  null,
  'gmail-credit-card-failed-message-1',
  'gmail-credit-card-thread-1',
  '2026-05-10 18:20:00+05:30',
  'alerts@hdfcbank.bank.in',
  'A payment was made using your Credit Card',
  'credit_card',
  'hdfc_credit_card_debit',
  '1.0.0',
  'parse_failed',
  null,
  null,
  jsonb_build_object('reason', 'hdfc_debit_pattern_not_matched')
);

reset role;

select is(
  (select count(*)::integer from public.gmail_parse_attempts),
  2,
  'Gmail parse attempt recording is idempotent by message candidate and parser'
);

select results_eq(
  $$
    select candidate_type::text, parse_status, count(*)::integer
    from public.gmail_parse_attempts
    where source_received_at >= '2026-05-01'
      and source_received_at < '2026-06-01'
    group by candidate_type, parse_status
    order by candidate_type::text, parse_status
  $$,
  $$
    values
      ('credit_card', 'parse_failed', 1),
      ('upi', 'parsed', 1)
  $$,
  'Gmail parse attempts can be reconciled by received month and candidate type'
);

select is(
  (
    select transaction_id is not null
    from public.gmail_parse_attempts
    where candidate_type = 'upi'
      and parse_status = 'parsed'
  ),
  true,
  'parsed Gmail attempt links back to the imported transaction'
);

set local role service_role;

select *
from public.disconnect_gmail_mailbox((select id from test_mailbox));

reset role;

select is(
  (
    select count(*)::integer
    from public.linked_mailboxes
    where provider = 'gmail'
      and not is_active
      and oauth_secret_ref is null
  ),
  1,
  'disconnect deactivates mailbox and clears the stored Vault reference'
);

select is(
  (
    select count(*)::integer
    from public.ingestion_jobs
    where linked_mailbox_id = (select id from test_mailbox)
      and status in ('queued', 'processing')
  ),
  0,
  'disconnect cancels pending Gmail ingestion jobs'
);

select * from finish();

rollback;
