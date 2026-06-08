begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(17);

select is(
  has_table_privilege('authenticated', 'public.ai_usage_events', 'insert'),
  false,
  'authenticated users cannot insert AI usage events directly'
);

select is(
  has_table_privilege('authenticated', 'public.ai_jobs', 'insert'),
  false,
  'authenticated users cannot insert AI jobs directly'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.record_ai_usage_event(uuid, uuid, text, text, text, integer, integer, numeric, text, jsonb, jsonb)',
    'execute'
  ),
  false,
  'authenticated users cannot execute the AI usage logging RPC'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.upsert_merchant_research_suggestion(uuid, uuid, text, text, text, uuid, uuid, jsonb, public.confidence, uuid, uuid)',
    'execute'
  ),
  false,
  'authenticated users cannot execute the merchant research cache write RPC'
);

insert into auth.users (id)
values
  ('14000000-0000-0000-0000-000000000001'),
  ('14000000-0000-0000-0000-000000000002');

insert into public.profiles (id, auth_user_id, display_name, email)
values
  ('24000000-0000-0000-0000-000000000001', '14000000-0000-0000-0000-000000000001', 'AI User A', 'ai-a@example.test'),
  ('24000000-0000-0000-0000-000000000002', '14000000-0000-0000-0000-000000000002', 'AI User B', 'ai-b@example.test');

insert into public.households (id, name, created_by)
values
  ('34000000-0000-0000-0000-000000000001', 'AI Household A', '24000000-0000-0000-0000-000000000001'),
  ('34000000-0000-0000-0000-000000000002', 'AI Household B', '24000000-0000-0000-0000-000000000002');

insert into public.household_members (id, household_id, profile_id, role)
values
  ('44000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', '24000000-0000-0000-0000-000000000001', 'owner'),
  ('44000000-0000-0000-0000-000000000002', '34000000-0000-0000-0000-000000000002', '24000000-0000-0000-0000-000000000002', 'owner');

insert into public.categories (id, household_id, name, sort_order)
values
  ('54000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', 'Shopping', 1),
  ('54000000-0000-0000-0000-000000000002', '34000000-0000-0000-0000-000000000002', 'Shopping', 1);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('55000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', 'Marketplace', 1),
  ('55000000-0000-0000-0000-000000000002', '34000000-0000-0000-0000-000000000002', '54000000-0000-0000-0000-000000000002', 'Marketplace', 1);

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
    '64000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000001',
    'workbook',
    '2026-05-01',
    'AMZN MKTP IN',
    'amzn mktp in',
    '54000000-0000-0000-0000-000000000001',
    '55000000-0000-0000-0000-000000000001',
    'debit_spend',
    250.00,
    250.00,
    0.00,
    250.00,
    'low',
    'ai-a-transaction'
  ),
  (
    '64000000-0000-0000-0000-000000000002',
    '34000000-0000-0000-0000-000000000002',
    'workbook',
    '2026-05-01',
    'OTHER HOUSEHOLD SHOP',
    'other household shop',
    '54000000-0000-0000-0000-000000000002',
    '55000000-0000-0000-0000-000000000002',
    'debit_spend',
    500.00,
    500.00,
    0.00,
    500.00,
    'low',
    'ai-b-transaction'
  );

insert into public.review_items (id, household_id, transaction_id, reason, status)
values
  ('94000000-0000-0000-0000-000000000001', '34000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000001', 'Unknown merchant', 'open'),
  ('94000000-0000-0000-0000-000000000002', '34000000-0000-0000-0000-000000000002', '64000000-0000-0000-0000-000000000002', 'Unknown merchant', 'open');

set local role authenticated;
set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select provider from public.ensure_ai_feature_settings('34000000-0000-0000-0000-000000000001')),
  'gemini',
  'AI settings default to Gemini'
);

select is(
  (select model from public.v_ai_budget_status where household_id = '34000000-0000-0000-0000-000000000001'),
  'gemini-3.5-flash',
  'AI settings default to Gemini 3.5 Flash'
);

select is(
  (select monthly_spend_cap_usd from public.v_ai_budget_status where household_id = '34000000-0000-0000-0000-000000000001'),
  0.000000::numeric,
  'development AI cap defaults to zero paid spend'
);

select is(
  (select merchant_research_web_search_enabled from public.v_ai_budget_status where household_id = '34000000-0000-0000-0000-000000000001'),
  false,
  'merchant research web search is disabled by default'
);

select is(
  (select count(*)::integer from public.v_ai_budget_status),
  1,
  'AI budget status is scoped to the signed-in household'
);

select throws_ok(
  $$
    select *
    from public.check_ai_budget(
      '34000000-0000-0000-0000-000000000002',
      'expense_qa',
      0
    )
  $$,
  'P0001',
  'Household is not available to the current user.',
  'AI budget checks reject cross-household access'
);

select lives_ok(
  $$
    select *
    from public.check_ai_budget(
      '34000000-0000-0000-0000-000000000001',
      'expense_qa',
      0
    )
  $$,
  'zero-cost free-tier AI call is allowed with the development cap'
);

select throws_ok(
  $$
    select *
    from public.check_ai_budget(
      '34000000-0000-0000-0000-000000000001',
      'expense_qa',
      0.000001
    )
  $$,
  'P0001',
  'Monthly AI budget cap reached.',
  'paid AI cost is blocked by the zero-dollar development cap'
);

reset role;
set local role service_role;

insert into public.ai_jobs (
  id,
  household_id,
  profile_id,
  job_type,
  status,
  input,
  output,
  provider,
  model,
  started_at,
  completed_at
)
values (
  'a4000000-0000-0000-0000-000000000001',
  '34000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000001',
  'expense_qa',
  'completed',
  jsonb_build_object('question', 'What did I spend on shopping?'),
  jsonb_build_object('answer', 'You spent INR 250 on shopping.'),
  'gemini',
  'gemini-3.5-flash',
  now(),
  now()
);

select public.record_ai_usage_event(
  '34000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000001',
  'expense_qa',
  'gemini',
  'gemini-3.5-flash',
  120,
  30,
  0,
  'completed',
  jsonb_build_object('job_id', 'a4000000-0000-0000-0000-000000000001'),
  jsonb_build_object('finish_reason', 'STOP')
);

select *
from public.upsert_merchant_research_suggestion(
  '34000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001',
  'amzn mktp in',
  'AMZN MKTP IN',
  'Amazon Shopping',
  '54000000-0000-0000-0000-000000000001',
  '55000000-0000-0000-0000-000000000001',
  jsonb_build_object('source', 'gemini', 'web_search_enabled', false),
  'medium',
  null,
  null
);

select *
from public.upsert_merchant_research_suggestion(
  '34000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001',
  'amzn mktp in',
  'AMZN MKTP IN',
  'Amazon Shopping',
  '54000000-0000-0000-0000-000000000001',
  '55000000-0000-0000-0000-000000000001',
  jsonb_build_object('source', 'cache-refresh', 'web_search_enabled', false),
  'medium',
  null,
  null
);

reset role;
set local role authenticated;
set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  (select count(*)::integer from public.ai_usage_events),
  1,
  'authenticated users can read AI usage logged for their household'
);

select is(
  (select current_month_event_count from public.v_ai_budget_status where household_id = '34000000-0000-0000-0000-000000000001'),
  1,
  'AI budget status includes current-month usage count'
);

select is(
  (select count(*)::integer from public.v_open_merchant_research_suggestions),
  1,
  'merchant research suggestions are cached by normalized merchant name'
);

select is(
  (select suggested_display_name from public.v_open_merchant_research_suggestions),
  'Amazon Shopping',
  'merchant research suggestion is visible for approval'
);

set local request.jwt.claim.sub = '14000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::integer from public.v_open_merchant_research_suggestions),
  0,
  'merchant research suggestions are scoped by household RLS'
);

select * from finish();

rollback;
