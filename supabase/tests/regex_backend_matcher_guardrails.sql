begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(13);

insert into auth.users (id)
values ('18000000-0000-0000-0000-000000000001');

insert into public.profiles (id, auth_user_id, display_name, email)
values (
  '28000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000001',
  'Regex Owner',
  'regex-owner@example.test'
);

insert into public.households (id, name, created_by)
values (
  '38000000-0000-0000-0000-000000000001',
  'Regex Household',
  '28000000-0000-0000-0000-000000000001'
);

insert into public.household_members (id, household_id, profile_id, role)
values (
  '48000000-0000-0000-0000-000000000001',
  '38000000-0000-0000-0000-000000000001',
  '28000000-0000-0000-0000-000000000001',
  'owner'
);

insert into public.categories (id, household_id, name, sort_order)
values
  ('58000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', 'Dining', 1),
  ('58000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', 'Shopping', 2);

insert into public.subcategories (id, household_id, category_id, name, sort_order)
values
  ('59000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000001', 'Cafe', 1),
  ('59000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', '58000000-0000-0000-0000-000000000002', 'Marketplace', 1);

insert into public.merchants (id, household_id, display_name, category_id, subcategory_id, confidence)
values
  ('68000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000001', 'Tea Stand', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'medium'),
  ('68000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000001', 'Big Bazaar', '58000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000002', 'high'),
  ('68000000-0000-0000-0000-000000000003', '38000000-0000-0000-0000-000000000001', 'Amazon Exact', '58000000-0000-0000-0000-000000000002', '59000000-0000-0000-0000-000000000002', 'manual'),
  ('68000000-0000-0000-0000-000000000004', '38000000-0000-0000-0000-000000000001', 'Amazon Regex', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'high'),
  ('68000000-0000-0000-0000-000000000005', '38000000-0000-0000-0000-000000000001', 'Coffee Low Priority', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'medium'),
  ('68000000-0000-0000-0000-000000000006', '38000000-0000-0000-0000-000000000001', 'Coffee High Priority', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'high'),
  ('68000000-0000-0000-0000-000000000007', '38000000-0000-0000-0000-000000000001', 'Tea Old Tie', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'medium'),
  ('68000000-0000-0000-0000-000000000008', '38000000-0000-0000-0000-000000000001', 'Tea New Tie', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'medium'),
  ('68000000-0000-0000-0000-000000000009', '38000000-0000-0000-0000-000000000001', 'Broken Regex', '58000000-0000-0000-0000-000000000001', '59000000-0000-0000-0000-000000000001', 'high');

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
  created_at,
  notes
)
values
  (
    '78000000-0000-0000-0000-000000000001',
    '38000000-0000-0000-0000-000000000001',
    '[',
    'regex',
    '68000000-0000-0000-0000-000000000009',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    0,
    'high',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Broken regex'
  ),
  (
    '78000000-0000-0000-0000-000000000002',
    '38000000-0000-0000-0000-000000000001',
    '^upi[[:space:]]+[0-9]+[[:space:]]+chai$',
    'regex',
    '68000000-0000-0000-0000-000000000001',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    20,
    'medium',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Regex tea match'
  ),
  (
    '78000000-0000-0000-0000-000000000003',
    '38000000-0000-0000-0000-000000000001',
    'Big   Bazaar',
    'contains',
    '68000000-0000-0000-0000-000000000002',
    '58000000-0000-0000-0000-000000000002',
    '59000000-0000-0000-0000-000000000002',
    10,
    'high',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Normalized contains match'
  ),
  (
    '78000000-0000-0000-0000-000000000004',
    '38000000-0000-0000-0000-000000000001',
    'amazon prime',
    'exact',
    '68000000-0000-0000-0000-000000000003',
    '58000000-0000-0000-0000-000000000002',
    '59000000-0000-0000-0000-000000000002',
    99,
    'manual',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Exact Amazon match'
  ),
  (
    '78000000-0000-0000-0000-000000000005',
    '38000000-0000-0000-0000-000000000001',
    '^amazon.*',
    'regex',
    '68000000-0000-0000-0000-000000000004',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    1,
    'high',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Regex Amazon match'
  ),
  (
    '78000000-0000-0000-0000-000000000006',
    '38000000-0000-0000-0000-000000000001',
    'coffee',
    'contains',
    '68000000-0000-0000-0000-000000000005',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    50,
    'medium',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Lower priority coffee match'
  ),
  (
    '78000000-0000-0000-0000-000000000007',
    '38000000-0000-0000-0000-000000000001',
    'coffee',
    'contains',
    '68000000-0000-0000-0000-000000000006',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    5,
    'high',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-02 00:00:00+00',
    'Higher priority coffee match'
  ),
  (
    '78000000-0000-0000-0000-000000000008',
    '38000000-0000-0000-0000-000000000001',
    'tea',
    'suffix',
    '68000000-0000-0000-0000-000000000007',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    30,
    'medium',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-01 00:00:00+00',
    'Older suffix tie'
  ),
  (
    '78000000-0000-0000-0000-000000000009',
    '38000000-0000-0000-0000-000000000001',
    'tea',
    'suffix',
    '68000000-0000-0000-0000-000000000008',
    '58000000-0000-0000-0000-000000000001',
    '59000000-0000-0000-0000-000000000001',
    30,
    'medium',
    true,
    '28000000-0000-0000-0000-000000000001',
    '2026-06-02 00:00:00+00',
    'Newer suffix tie'
  );

set local role authenticated;
set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000001';
set local request.jwt.claim.role = 'authenticated';

select is(
  public.merchant_rule_matches('regex', '[', 'any merchant'),
  false,
  'invalid regex patterns return false'
);

select is(
  public.merchant_rule_matches('exact', '   ', 'any merchant'),
  false,
  'blank effective patterns return false'
);

select is(
  public.merchant_rule_matches('contains', 'merchant', '   '),
  false,
  'blank normalized inputs return false'
);

select is(
  public.merchant_rule_matches('unknown', 'merchant', 'any merchant'),
  false,
  'unknown match types return false'
);

select is(
  (
    select merchant_id::text
    from public.match_merchant_mapping_rule(
      '38000000-0000-0000-0000-000000000001',
      'UPI/123 Chai'
    )
  ),
  '68000000-0000-0000-0000-000000000001',
  'regex rules match normalized statement merchant text'
);

select is(
  (
    select merchant_id::text
    from public.match_merchant_mapping_rule(
      '38000000-0000-0000-0000-000000000001',
      'BIG-BAZAAR AIRPORT'
    )
  ),
  '68000000-0000-0000-0000-000000000002',
  'non-regex patterns are normalized before comparison'
);

select is(
  (
    select merchant_id::text
    from public.match_merchant_mapping_rule(
      '38000000-0000-0000-0000-000000000001',
      'AMAZON PRIME'
    )
  ),
  '68000000-0000-0000-0000-000000000003',
  'exact rules outrank broader regex rules'
);

select is(
  (
    select merchant_id::text
    from public.match_merchant_mapping_rule(
      '38000000-0000-0000-0000-000000000001',
      'Coffee Corner'
    )
  ),
  '68000000-0000-0000-0000-000000000006',
  'priority breaks ties inside the same match type'
);

select is(
  (
    select merchant_id::text
    from public.match_merchant_mapping_rule(
      '38000000-0000-0000-0000-000000000001',
      'Masala Tea'
    )
  ),
  '68000000-0000-0000-0000-000000000008',
  'newer rules win when match type and priority tie'
);

select results_eq(
  $$
    select
      rule_id::text,
      merchant_id::text,
      merchant_name,
      category_id::text,
      category_name,
      subcategory_id::text,
      subcategory_name,
      confidence::text,
      rule_notes,
      rule_created_by::text
    from public.classify_statement_merchant(
      '38000000-0000-0000-0000-000000000001',
      'UPI/123 Chai'
    )
  $$,
  $$
    values (
      '78000000-0000-0000-0000-000000000002',
      '68000000-0000-0000-0000-000000000001',
      'Tea Stand',
      '58000000-0000-0000-0000-000000000001',
      'Dining',
      '59000000-0000-0000-0000-000000000001',
      'Cafe',
      'medium',
      'Regex tea match',
      '28000000-0000-0000-0000-000000000001'
    )
  $$,
  'detail helper returns winning rule names, ids, confidence, notes, and creator'
);

select is(
  (
    select count(*)::integer
    from public.classify_statement_merchant(
      '38000000-0000-0000-0000-000000000001',
      'No Matching Merchant'
    )
  ),
  0,
  'detail helper returns no row when no rule matches'
);

select is(
  has_function_privilege('anon', 'public.classify_statement_merchant(uuid,text)', 'execute'),
  false,
  'detail helper is not executable by anon'
);

select is(
  has_function_privilege('authenticated', 'public.classify_statement_merchant(uuid,text)', 'execute'),
  true,
  'detail helper is executable by authenticated callers'
);

select * from finish();

rollback;
