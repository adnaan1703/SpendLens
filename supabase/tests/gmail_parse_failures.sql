begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(21);

select has_function(
  'public',
  'list_gmail_parse_failures',
  array['uuid', 'integer'],
  'Gmail parse-failure listing RPC exists'
);

select has_function(
  'public',
  'ignore_gmail_parse_failure',
  array['uuid'],
  'Gmail parse-failure ignore RPC exists'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.list_gmail_parse_failures(uuid, integer)',
    'execute'
  ),
  true,
  'authenticated users can execute Gmail parse-failure listing RPC'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.ignore_gmail_parse_failure(uuid)',
    'execute'
  ),
  true,
  'authenticated users can execute Gmail parse-failure ignore RPC'
);

select is(
  has_function_privilege(
    'anon',
    'public.list_gmail_parse_failures(uuid, integer)',
    'execute'
  ),
  false,
  'anonymous users cannot execute Gmail parse-failure listing RPC'
);

select is(
  has_function_privilege(
    'anon',
    'public.ignore_gmail_parse_failure(uuid)',
    'execute'
  ),
  false,
  'anonymous users cannot execute Gmail parse-failure ignore RPC'
);

select is(
  has_table_privilege('authenticated', 'public.gmail_parse_attempts', 'select'),
  false,
  'authenticated users cannot directly read Gmail parse attempts'
);

select is(
  has_table_privilege('authenticated', 'public.gmail_parse_attempts', 'update'),
  false,
  'authenticated users cannot directly update Gmail parse attempts'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.v_gmail_parse_attempt_health',
    'select'
  ),
  false,
  'authenticated users cannot directly read Gmail parse health'
);

select is(
  has_table_privilege('service_role', 'public.gmail_parse_attempts', 'select'),
  true,
  'service role can still read Gmail parse attempts'
);

select is(
  has_table_privilege(
    'service_role',
    'public.v_gmail_parse_attempt_health',
    'select'
  ),
  true,
  'service role can still read Gmail parse health'
);

insert into auth.users (id)
values
  ('13000000-0000-0000-0000-000000000001'),
  ('13000000-0000-0000-0000-000000000002'),
  ('13000000-0000-0000-0000-000000000003');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  ('23000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000001', 'Parse User A', 'parse-a@example.test'),
  ('23000000-0000-0000-0000-000000000002', '13000000-0000-0000-0000-000000000002', 'Parse User B', 'parse-b@example.test'),
  ('23000000-0000-0000-0000-000000000003', '13000000-0000-0000-0000-000000000003', 'Inactive Parse User', 'parse-inactive@example.test');

insert into public.households (id, name, created_by)
values
  ('33000000-0000-0000-0000-000000000001', 'Parse Household A', '23000000-0000-0000-0000-000000000001'),
  ('33000000-0000-0000-0000-000000000002', 'Parse Household B', '23000000-0000-0000-0000-000000000002');

insert into public.household_members (
  id,
  household_id,
  profile_id,
  role,
  is_active
)
values
  ('43000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000001', 'owner', true),
  ('43000000-0000-0000-0000-000000000002', '33000000-0000-0000-0000-000000000002', '23000000-0000-0000-0000-000000000002', 'owner', true),
  ('43000000-0000-0000-0000-000000000003', '33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000003', 'viewer', false);

insert into public.linked_mailboxes (
  id,
  household_id,
  profile_id,
  email,
  provider,
  is_active
)
values
  ('53000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000001', 'parse-a@example.test', 'gmail', true),
  ('53000000-0000-0000-0000-000000000002', '33000000-0000-0000-0000-000000000002', '23000000-0000-0000-0000-000000000002', 'parse-b@example.test', 'gmail', true),
  ('53000000-0000-0000-0000-000000000003', '33000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000001', 'inactive-parse-a@example.test', 'gmail', false);

insert into public.gmail_parse_attempts (
  id,
  household_id,
  linked_mailbox_id,
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
    '93000000-0000-0000-0000-000000000001',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'credit_card',
    'gmail-failure-message-1',
    'gmail-failure-thread-1',
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
    '93000000-0000-0000-0000-000000000006',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'netbanking_imps',
    'gmail-imps-failure-message-1',
    'gmail-imps-failure-thread-1',
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
    '93000000-0000-0000-0000-000000000007',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'other',
    'gmail-unsupported-failure-message-1',
    'gmail-unsupported-failure-thread-1',
    '2026-06-08 10:30:00+05:30',
    'alerts@hdfcbank.bank.in',
    'Watched label unsupported template',
    'unsupported_labeled_gmail_message',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"no_supported_body_template_matched"}'::jsonb
  ),
  (
    '93000000-0000-0000-0000-000000000002',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'upi',
    'gmail-parsed-message-1',
    'gmail-parsed-thread-1',
    '2026-06-08 11:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'You have done a UPI txn. Check details!',
    'hdfc_upi_debit',
    '1.0.0',
    'parsed',
    '2026-06-08',
    '652216925085',
    '{"template":"hdfc_upi_debit_v1"}'::jsonb
  ),
  (
    '93000000-0000-0000-0000-000000000003',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000001',
    'credit_card',
    'gmail-outside-message-1',
    'gmail-outside-thread-1',
    '2026-05-01 10:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'A payment was made using your Credit Card',
    'hdfc_credit_card_debit',
    '1.0.0',
    'outside_date_range',
    null,
    null,
    '{"reason":"outside_date_range"}'::jsonb
  ),
  (
    '93000000-0000-0000-0000-000000000004',
    '33000000-0000-0000-0000-000000000002',
    '53000000-0000-0000-0000-000000000002',
    'credit_card',
    'gmail-other-household-failure',
    'gmail-other-household-thread',
    '2026-06-08 12:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'A payment was made using your Credit Card',
    'hdfc_credit_card_debit',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"other_household_failure"}'::jsonb
  ),
  (
    '93000000-0000-0000-0000-000000000005',
    '33000000-0000-0000-0000-000000000001',
    '53000000-0000-0000-0000-000000000003',
    'credit_card',
    'gmail-inactive-mailbox-failure',
    'gmail-inactive-mailbox-thread',
    '2026-06-08 13:00:00+05:30',
    'alerts@hdfcbank.bank.in',
    'A payment was made using your Credit Card',
    'hdfc_credit_card_debit',
    '1.0.0',
    'parse_failed',
    null,
    null,
    '{"reason":"inactive_mailbox_failure"}'::jsonb
  );

set local role authenticated;
set local request.jwt.claim.sub = '13000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select count(*)::integer
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
  ),
  3,
  'active household member can read only active-mailbox parse failures'
);

select results_eq(
  $$
    select
      failure_id,
      candidate_type::text,
      reason_code,
      source_message_id,
      source_thread_id
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
  $$,
  $$
    values (
      '93000000-0000-0000-0000-000000000007'::uuid,
      'other',
      'no_supported_body_template_matched',
      'gmail-unsupported-failure-message-1',
      'gmail-unsupported-failure-thread-1'
    ),
    (
      '93000000-0000-0000-0000-000000000006'::uuid,
      'netbanking_imps',
      'hdfc_imps_debit_pattern_not_matched',
      'gmail-imps-failure-message-1',
      'gmail-imps-failure-thread-1'
    ),
    (
      '93000000-0000-0000-0000-000000000001'::uuid,
      'credit_card',
      'hdfc_debit_pattern_not_matched',
      'gmail-failure-message-1',
      'gmail-failure-thread-1'
    )
  $$,
  'parse-failure RPC returns sanitized diagnostic fields'
);

select results_eq(
  $$
    select
      candidate_type::text,
      reason_code
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
    order by candidate_type::text
  $$,
  $$
    values (
      'credit_card',
      'hdfc_debit_pattern_not_matched'
    ),
    (
      'netbanking_imps',
      'hdfc_imps_debit_pattern_not_matched'
    ),
    (
      'other',
      'no_supported_body_template_matched'
    )
  $$,
  'parse-failure RPC supports IMPS and unsupported watched-label candidates'
);

select lives_ok(
  $$
    select public.ignore_gmail_parse_failure(
      '93000000-0000-0000-0000-000000000007'::uuid
    )
  $$,
  'active household member can ignore one visible parse failure'
);

select is(
  (
    select count(*)::integer
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
  ),
  2,
  'ignored parse failures are hidden from the visible Review list'
);

reset role;

select is(
  (
    select ignored_by
    from public.gmail_parse_attempts
    where id = '93000000-0000-0000-0000-000000000007'
      and ignored_at is not null
  ),
  '23000000-0000-0000-0000-000000000001'::uuid,
  'ignore RPC records the household member profile while keeping diagnostics'
);

set local role authenticated;
set local request.jwt.claim.sub = '13000000-0000-0000-0000-000000000002';
set local request.jwt.claim.role = 'authenticated';

select is(
  (
    select count(*)::integer
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
  ),
  0,
  'another household cannot read parse failures'
);

select throws_ok(
  $$
    select public.ignore_gmail_parse_failure(
      '93000000-0000-0000-0000-000000000001'::uuid
    )
  $$,
  'P0001',
  'Visible Gmail parse failure not found.',
  'another household cannot ignore a parse failure'
);

set local request.jwt.claim.sub = '13000000-0000-0000-0000-000000000003';

select is(
  (
    select count(*)::integer
    from public.list_gmail_parse_failures(
      '33000000-0000-0000-0000-000000000001'
    )
  ),
  0,
  'inactive household member cannot read parse failures'
);

select throws_ok(
  $$
    select public.ignore_gmail_parse_failure(
      '93000000-0000-0000-0000-000000000001'::uuid
    )
  $$,
  'P0001',
  'Visible Gmail parse failure not found.',
  'inactive household member cannot ignore a parse failure'
);

select * from finish();

rollback;
