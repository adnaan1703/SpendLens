begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(20);

select has_view(
  'public',
  'v_ingestion_operational_health',
  'ingestion operational health view exists'
);

select has_view(
  'public',
  'v_parser_operational_health',
  'parser operational health view exists'
);

select has_table(
  'public',
  'gmail_parse_attempts',
  'Gmail parse attempts table exists'
);

select has_view(
  'public',
  'v_gmail_parse_attempt_health',
  'Gmail parse attempt health view exists'
);

select ok(
  coalesce(
    (
      select c.reloptions @> array['security_invoker=true']
      from pg_class c
      join pg_namespace n
        on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'v_ingestion_operational_health'
    ),
    false
  ),
  'ingestion operational health view uses security_invoker'
);

select ok(
  coalesce(
    (
      select c.reloptions @> array['security_invoker=true']
      from pg_class c
      join pg_namespace n
        on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'v_parser_operational_health'
    ),
    false
  ),
  'parser operational health view uses security_invoker'
);

select ok(
  coalesce(
    (
      select c.reloptions @> array['security_invoker=true']
      from pg_class c
      join pg_namespace n
        on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'v_gmail_parse_attempt_health'
    ),
    false
  ),
  'Gmail parse attempt health view uses security_invoker'
);

select is(
  has_table_privilege('authenticated', 'public.v_ingestion_operational_health', 'select'),
  false,
  'authenticated users cannot read ingestion operational health'
);

select is(
  has_table_privilege('authenticated', 'public.v_parser_operational_health', 'select'),
  false,
  'authenticated users cannot read parser operational health'
);

select is(
  has_table_privilege('authenticated', 'public.gmail_parse_attempts', 'select'),
  false,
  'authenticated users cannot read Gmail parse attempts'
);

select is(
  has_table_privilege('authenticated', 'public.v_gmail_parse_attempt_health', 'select'),
  false,
  'authenticated users cannot read Gmail parse attempt health'
);

select is(
  has_table_privilege('service_role', 'public.v_ingestion_operational_health', 'select'),
  true,
  'service role can read ingestion operational health'
);

select is(
  has_table_privilege('service_role', 'public.v_parser_operational_health', 'select'),
  true,
  'service role can read parser operational health'
);

select is(
  has_table_privilege('service_role', 'public.gmail_parse_attempts', 'select'),
  true,
  'service role can read Gmail parse attempts'
);

select is(
  has_table_privilege('service_role', 'public.v_gmail_parse_attempt_health', 'select'),
  true,
  'service role can read Gmail parse attempt health'
);

insert into auth.users (id)
values ('12000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values (
  '22000000-0000-0000-0000-000000000001',
  '12000000-0000-0000-0000-000000000001',
  'Production User',
  'production@example.test'
);

insert into public.households (id, name, created_by)
values (
  '32000000-0000-0000-0000-000000000001',
  'Production Household',
  '22000000-0000-0000-0000-000000000001'
);

insert into public.household_members (id, household_id, profile_id, role)
values (
  '42000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  'owner'
);

set local role service_role;

insert into public.linked_mailboxes (
  id,
  household_id,
  profile_id,
  email,
  provider,
  oauth_secret_ref,
  gmail_history_id,
  watch_expires_at,
  last_sync_at,
  last_error,
  is_active,
  connected_at,
  last_watch_renewed_at,
  last_sync_status,
  has_oauth_secret
)
values (
  '52000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001',
  '22000000-0000-0000-0000-000000000001',
  'production-gmail@example.test',
  'gmail',
  null,
  '9001',
  now() + interval '12 hours',
  now() - interval '2 days',
  'invalid_grant: token revoked',
  true,
  now() - interval '3 days',
  now() - interval '6 days',
  'failed',
  false
);

insert into public.ingestion_jobs (
  id,
  household_id,
  linked_mailbox_id,
  job_type,
  status,
  idempotency_key,
  attempts,
  max_attempts,
  run_after,
  updated_at,
  error_message
)
values
  (
    '62000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    'gmail_sync',
    'queued',
    'retry:9002',
    2,
    5,
    now() - interval '30 minutes',
    now() - interval '5 minutes',
    'rate limit, will retry'
  ),
  (
    '62000000-0000-0000-0000-000000000002',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    'gmail_backfill',
    'failed',
    'backfill:2026-06-07',
    5,
    5,
    now() - interval '1 hour',
    now(),
    'permanent parser failure'
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
  confidence,
  source_fingerprint
)
values (
  '72000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001',
  'gmail',
  '2026-06-07',
  'CRED Club',
  public.normalize_merchant_name('CRED Club'),
  'debit_spend',
  100.00,
  100.00,
  0.00,
  100.00,
  'low',
  'production-readiness-parser-health'
);

insert into public.transaction_sources (
  id,
  household_id,
  transaction_id,
  source_type,
  source_message_id,
  source_thread_id,
  source_reference,
  source_received_at,
  parser_name,
  parser_version,
  parse_status,
  diagnostics
)
values (
  '82000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000001',
  'gmail',
  'gmail-production-smoke',
  'gmail-production-smoke-thread',
  '652216925085',
  '2026-06-07 10:00:00+05:30',
  'hdfc_upi_debit',
  '1.0.0',
  'parsed',
  '{"template":"hdfc_upi_debit_v1"}'::jsonb
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
  source_reference,
  diagnostics
)
values
  (
    '92000000-0000-0000-0000-000000000001',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    '72000000-0000-0000-0000-000000000001',
    'upi',
    'gmail-production-smoke',
    'gmail-production-smoke-thread',
    '2026-06-07 10:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'You have done a UPI txn. Check details!',
    'hdfc_upi_debit',
    '1.0.0',
    'parsed',
    '2026-06-07',
    '652216925085',
    '{"template":"hdfc_upi_debit_v1"}'::jsonb
  ),
  (
    '92000000-0000-0000-0000-000000000002',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    null,
    'credit_card',
    'gmail-production-failed-smoke',
    'gmail-production-failed-thread',
    '2026-06-08 10:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'A payment was made using your Credit Card',
    'hdfc_credit_card_debit',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"hdfc_debit_pattern_not_matched"}'::jsonb
  ),
  (
    '92000000-0000-0000-0000-000000000003',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    null,
    'netbanking_imps',
    'gmail-production-imps-failed-smoke',
    'gmail-production-imps-failed-thread',
    '2026-06-08 10:15:00+05:30',
    'alerts@hdfcbank.bank.in',
    'Netbanking :: IMPS',
    'hdfc_netbanking_imps_debit',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"hdfc_imps_debit_pattern_not_matched"}'::jsonb
  ),
  (
    '92000000-0000-0000-0000-000000000004',
    '32000000-0000-0000-0000-000000000001',
    '52000000-0000-0000-0000-000000000001',
    null,
    'other',
    'gmail-production-unsupported-smoke',
    'gmail-production-unsupported-thread',
    '2026-06-08 10:30:00+05:30',
    'alerts@hdfcbank.bank.in',
    'Watched label unsupported template',
    'unsupported_labeled_gmail_message',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"no_supported_body_template_matched"}'::jsonb
  );

select results_eq(
  $$
    select
      active_mailbox_count,
      mailbox_error_count,
      oauth_missing_count,
      watch_expiring_48h_count,
      stale_sync_mailbox_count,
      queued_job_count,
      retrying_job_count,
      failed_job_count,
      permanently_failed_job_count
    from public.v_ingestion_operational_health
    where household_id = '32000000-0000-0000-0000-000000000001'
  $$,
  $$
    values (1, 1, 1, 1, 1, 1, 1, 1, 1)
  $$,
  'ingestion health view summarizes connector, retry, and failure state'
);

select is(
  (
    select latest_job_error
    from public.v_ingestion_operational_health
    where household_id = '32000000-0000-0000-0000-000000000001'
  ),
  'permanent parser failure',
  'ingestion health view exposes the latest non-secret job error'
);

select results_eq(
  $$
    select
      parser_name,
      parser_version,
      parse_status,
      transaction_source_count
    from public.v_parser_operational_health
    where household_id = '32000000-0000-0000-0000-000000000001'
  $$,
  $$
    values ('hdfc_upi_debit', '1.0.0', 'parsed', 1)
  $$,
  'parser health view summarizes Gmail parser status counts'
);

select results_eq(
  $$
    select
      candidate_type::text,
      parser_name,
      parse_status,
      parse_attempt_count
    from public.v_gmail_parse_attempt_health
    where household_id = '32000000-0000-0000-0000-000000000001'
    order by candidate_type::text, parse_status
  $$,
  $$
    values
      ('credit_card', 'hdfc_credit_card_debit', 'parse_failed', 1),
      ('netbanking_imps', 'hdfc_netbanking_imps_debit', 'parse_failed', 1),
      ('other', 'unsupported_labeled_gmail_message', 'parse_failed', 1),
      ('upi', 'hdfc_upi_debit', 'parsed', 1)
  $$,
  'Gmail parse attempt health view summarizes candidate parse statuses'
);

reset role;

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relrowsecurity
      and c.relname not like 'pg_%'
  ),
  0,
  'all public base tables have RLS enabled'
);

select * from finish();

rollback;
