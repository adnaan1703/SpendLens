create table public.ai_feature_settings (
  household_id uuid primary key references public.households (id) on delete cascade,
  provider text not null default 'gemini',
  model text not null default 'gemini-3.5-flash',
  monthly_spend_cap_usd numeric(12,6) not null default 0,
  expense_qa_enabled boolean not null default true,
  merchant_research_enabled boolean not null default true,
  merchant_research_web_search_enabled boolean not null default false,
  free_tier_only boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ai_feature_settings_provider_supported check (provider in ('gemini')),
  constraint ai_feature_settings_model_nonempty check (btrim(model) <> ''),
  constraint ai_feature_settings_monthly_cap_nonnegative check (monthly_spend_cap_usd >= 0)
);

create table public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete set null,
  feature text not null,
  provider text not null,
  model text not null,
  input_tokens integer,
  output_tokens integer,
  estimated_cost_usd numeric(12,6) not null default 0,
  status text not null,
  request_metadata jsonb not null default '{}'::jsonb,
  response_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint ai_usage_events_feature_nonempty check (btrim(feature) <> ''),
  constraint ai_usage_events_provider_supported check (provider in ('gemini')),
  constraint ai_usage_events_model_nonempty check (btrim(model) <> ''),
  constraint ai_usage_events_tokens_nonnegative check (
    (input_tokens is null or input_tokens >= 0)
    and (output_tokens is null or output_tokens >= 0)
  ),
  constraint ai_usage_events_cost_nonnegative check (estimated_cost_usd >= 0),
  constraint ai_usage_events_status_supported check (
    status in ('queued', 'completed', 'failed', 'blocked', 'cached')
  )
);

create table public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete set null,
  job_type text not null,
  status public.job_status not null default 'queued',
  input jsonb not null,
  output jsonb,
  provider text not null default 'gemini',
  model text not null default 'gemini-3.5-flash',
  usage_event_id uuid references public.ai_usage_events (id) on delete set null,
  error_message text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  constraint ai_jobs_job_type_supported check (
    job_type in ('expense_qa', 'merchant_research')
  ),
  constraint ai_jobs_provider_supported check (provider in ('gemini')),
  constraint ai_jobs_model_nonempty check (btrim(model) <> ''),
  constraint ai_jobs_completed_after_started check (
    completed_at is null
    or started_at is null
    or completed_at >= started_at
  )
);

create table public.merchant_research_suggestions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  review_item_id uuid,
  normalized_merchant_name text not null,
  statement_merchant text,
  suggested_display_name text,
  suggested_category_id uuid,
  suggested_subcategory_id uuid,
  evidence jsonb not null default '{}'::jsonb,
  confidence public.confidence,
  status public.review_status not null default 'open',
  ai_job_id uuid references public.ai_jobs (id) on delete set null,
  usage_event_id uuid references public.ai_usage_events (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint merchant_research_suggestions_review_household_fk
    foreign key (review_item_id, household_id)
    references public.review_items (id, household_id) on delete set null (review_item_id),
  constraint merchant_research_suggestions_category_household_fk
    foreign key (suggested_category_id, household_id)
    references public.categories (id, household_id) on delete set null (suggested_category_id),
  constraint merchant_research_suggestions_subcategory_category_household_fk
    foreign key (suggested_subcategory_id, suggested_category_id, household_id)
    references public.subcategories (id, category_id, household_id) on delete set null (suggested_subcategory_id),
  constraint merchant_research_suggestions_normalized_name_nonempty check (
    btrim(normalized_merchant_name) <> ''
  ),
  constraint merchant_research_suggestions_subcategory_requires_category check (
    suggested_subcategory_id is null or suggested_category_id is not null
  )
);

create unique index merchant_research_suggestions_household_normalized_key
  on public.merchant_research_suggestions (household_id, normalized_merchant_name);

create index ai_usage_events_household_month_idx
  on public.ai_usage_events (household_id, created_at);
create index ai_usage_events_feature_idx
  on public.ai_usage_events (feature, status);
create index ai_jobs_household_status_idx
  on public.ai_jobs (household_id, status, created_at);
create index merchant_research_suggestions_household_status_idx
  on public.merchant_research_suggestions (household_id, status, created_at);

create trigger ai_feature_settings_set_updated_at
  before update on public.ai_feature_settings
  for each row execute function app_private.set_updated_at();

create trigger merchant_research_suggestions_set_updated_at
  before update on public.merchant_research_suggestions
  for each row execute function app_private.set_updated_at();

alter table public.ai_feature_settings enable row level security;
alter table public.ai_usage_events enable row level security;
alter table public.ai_jobs enable row level security;
alter table public.merchant_research_suggestions enable row level security;

create policy "ai_feature_settings_select_members"
  on public.ai_feature_settings
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));

create policy "ai_feature_settings_insert_admins"
  on public.ai_feature_settings
  for insert
  to authenticated
  with check (
    household_id in (select app_private.admin_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );

create policy "ai_feature_settings_update_admins"
  on public.ai_feature_settings
  for update
  to authenticated
  using (household_id in (select app_private.admin_household_ids()))
  with check (household_id in (select app_private.admin_household_ids()));

create policy "ai_usage_events_select_members"
  on public.ai_usage_events
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));

create policy "ai_jobs_select_members"
  on public.ai_jobs
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));

create policy "merchant_research_suggestions_select_members"
  on public.merchant_research_suggestions
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));

create policy "merchant_research_suggestions_update_writers"
  on public.merchant_research_suggestions
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));

create view public.v_ai_budget_status
with (security_invoker = true)
as
with usage_totals as (
  select
    aue.household_id,
    coalesce(
      sum(aue.estimated_cost_usd) filter (
        where aue.created_at >= date_trunc('month', now())
          and aue.created_at < date_trunc('month', now()) + interval '1 month'
          and aue.status in ('completed', 'cached')
      ),
      0
    )::numeric(12,6) as current_month_spend_usd,
    count(*) filter (
      where aue.created_at >= date_trunc('month', now())
        and aue.created_at < date_trunc('month', now()) + interval '1 month'
    )::integer as current_month_event_count
  from public.ai_usage_events aue
  group by aue.household_id
)
select
  h.id as household_id,
  coalesce(afs.provider, 'gemini') as provider,
  coalesce(afs.model, 'gemini-3.5-flash') as model,
  coalesce(afs.monthly_spend_cap_usd, 0)::numeric(12,6) as monthly_spend_cap_usd,
  coalesce(afs.expense_qa_enabled, true) as expense_qa_enabled,
  coalesce(afs.merchant_research_enabled, true) as merchant_research_enabled,
  coalesce(afs.merchant_research_web_search_enabled, false) as merchant_research_web_search_enabled,
  coalesce(afs.free_tier_only, true) as free_tier_only,
  date_trunc('month', now())::date as current_period_month,
  coalesce(ut.current_month_spend_usd, 0)::numeric(12,6) as current_month_spend_usd,
  coalesce(ut.current_month_event_count, 0)::integer as current_month_event_count,
  greatest(
    coalesce(afs.monthly_spend_cap_usd, 0) - coalesce(ut.current_month_spend_usd, 0),
    0
  )::numeric(12,6) as remaining_monthly_budget_usd
from public.households h
left join public.ai_feature_settings afs on afs.household_id = h.id
left join usage_totals ut on ut.household_id = h.id;

create view public.v_open_merchant_research_suggestions
with (security_invoker = true)
as
select
  mrs.id,
  mrs.household_id,
  mrs.review_item_id,
  mrs.normalized_merchant_name,
  mrs.statement_merchant,
  mrs.suggested_display_name,
  mrs.suggested_category_id,
  c.name as suggested_category_name,
  mrs.suggested_subcategory_id,
  sc.name as suggested_subcategory_name,
  mrs.evidence,
  mrs.confidence,
  mrs.status,
  mrs.created_at,
  mrs.updated_at
from public.merchant_research_suggestions mrs
left join public.categories c
  on c.id = mrs.suggested_category_id
  and c.household_id = mrs.household_id
left join public.subcategories sc
  on sc.id = mrs.suggested_subcategory_id
  and sc.household_id = mrs.household_id
where mrs.status = 'open';

create or replace function public.ensure_ai_feature_settings(
  p_household_id uuid
)
returns setof public.ai_feature_settings
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid := app_private.current_profile_id();
begin
  if p_household_id not in (select app_private.active_household_ids()) then
    raise exception 'Household is not available to the current user.';
  end if;

  insert into public.ai_feature_settings (
    household_id,
    provider,
    model,
    monthly_spend_cap_usd,
    expense_qa_enabled,
    merchant_research_enabled,
    merchant_research_web_search_enabled,
    free_tier_only,
    created_by
  )
  values (
    p_household_id,
    'gemini',
    'gemini-3.5-flash',
    0,
    true,
    true,
    false,
    true,
    v_profile_id
  )
  on conflict (household_id) do nothing;

  return query
  select *
  from public.ai_feature_settings
  where household_id = p_household_id;
end;
$$;

create or replace function public.check_ai_budget(
  p_household_id uuid,
  p_feature text,
  p_estimated_cost_usd numeric default 0
)
returns table (
  household_id uuid,
  provider text,
  model text,
  monthly_spend_cap_usd numeric,
  current_month_spend_usd numeric,
  remaining_monthly_budget_usd numeric,
  free_tier_only boolean,
  web_search_enabled boolean
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status record;
begin
  if p_estimated_cost_usd is null or p_estimated_cost_usd < 0 then
    raise exception 'Estimated AI cost must be non-negative.';
  end if;

  if auth.uid() is not null
    and p_household_id not in (select app_private.active_household_ids())
  then
    raise exception 'Household is not available to the current user.';
  end if;

  select *
  into v_status
  from public.v_ai_budget_status vabs
  where vabs.household_id = p_household_id;

  if not found then
    raise exception 'AI budget status was not found for household.';
  end if;

  if p_feature = 'expense_qa' and not v_status.expense_qa_enabled then
    raise exception 'Expense Q&A is disabled for this household.';
  end if;

  if p_feature = 'merchant_research' and not v_status.merchant_research_enabled then
    raise exception 'Merchant research is disabled for this household.';
  end if;

  if p_estimated_cost_usd > v_status.remaining_monthly_budget_usd then
    raise exception 'Monthly AI budget cap reached.';
  end if;

  return query
  select
    v_status.household_id,
    v_status.provider,
    v_status.model,
    v_status.monthly_spend_cap_usd,
    v_status.current_month_spend_usd,
    v_status.remaining_monthly_budget_usd,
    v_status.free_tier_only,
    v_status.merchant_research_web_search_enabled;
end;
$$;

create or replace function public.record_ai_usage_event(
  p_household_id uuid,
  p_profile_id uuid,
  p_feature text,
  p_provider text,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_estimated_cost_usd numeric,
  p_status text,
  p_request_metadata jsonb default '{}'::jsonb,
  p_response_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_household_id is null then
    raise exception 'Household is required.';
  end if;

  insert into public.ai_usage_events (
    household_id,
    profile_id,
    feature,
    provider,
    model,
    input_tokens,
    output_tokens,
    estimated_cost_usd,
    status,
    request_metadata,
    response_metadata
  )
  values (
    p_household_id,
    p_profile_id,
    p_feature,
    p_provider,
    p_model,
    p_input_tokens,
    p_output_tokens,
    coalesce(p_estimated_cost_usd, 0),
    p_status,
    coalesce(p_request_metadata, '{}'::jsonb),
    coalesce(p_response_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.upsert_merchant_research_suggestion(
  p_household_id uuid,
  p_review_item_id uuid,
  p_normalized_merchant_name text,
  p_statement_merchant text,
  p_suggested_display_name text,
  p_suggested_category_id uuid,
  p_suggested_subcategory_id uuid,
  p_evidence jsonb,
  p_confidence public.confidence,
  p_ai_job_id uuid,
  p_usage_event_id uuid
)
returns setof public.merchant_research_suggestions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_normalized text := nullif(btrim(p_normalized_merchant_name), '');
begin
  if v_normalized is null then
    raise exception 'Normalized merchant name is required.';
  end if;

  insert into public.merchant_research_suggestions (
    household_id,
    review_item_id,
    normalized_merchant_name,
    statement_merchant,
    suggested_display_name,
    suggested_category_id,
    suggested_subcategory_id,
    evidence,
    confidence,
    ai_job_id,
    usage_event_id,
    status
  )
  values (
    p_household_id,
    p_review_item_id,
    v_normalized,
    nullif(btrim(p_statement_merchant), ''),
    nullif(btrim(p_suggested_display_name), ''),
    p_suggested_category_id,
    p_suggested_subcategory_id,
    coalesce(p_evidence, '{}'::jsonb),
    p_confidence,
    p_ai_job_id,
    p_usage_event_id,
    'open'
  )
  on conflict (household_id, normalized_merchant_name) do update set
    review_item_id = coalesce(excluded.review_item_id, public.merchant_research_suggestions.review_item_id),
    statement_merchant = coalesce(excluded.statement_merchant, public.merchant_research_suggestions.statement_merchant),
    suggested_display_name = coalesce(excluded.suggested_display_name, public.merchant_research_suggestions.suggested_display_name),
    suggested_category_id = excluded.suggested_category_id,
    suggested_subcategory_id = excluded.suggested_subcategory_id,
    evidence = excluded.evidence,
    confidence = excluded.confidence,
    ai_job_id = excluded.ai_job_id,
    usage_event_id = excluded.usage_event_id,
    status = 'open',
    updated_at = now();

  return query
  select *
  from public.merchant_research_suggestions
  where household_id = p_household_id
    and normalized_merchant_name = v_normalized;
end;
$$;

revoke all on public.ai_feature_settings from public, anon, authenticated;
revoke all on public.ai_usage_events from public, anon, authenticated;
revoke all on public.ai_jobs from public, anon, authenticated;
revoke all on public.merchant_research_suggestions from public, anon, authenticated;
revoke all on public.v_ai_budget_status from public, anon, authenticated;
revoke all on public.v_open_merchant_research_suggestions from public, anon, authenticated;
revoke execute on function public.ensure_ai_feature_settings(uuid) from public, anon, authenticated;
revoke execute on function public.check_ai_budget(uuid, text, numeric) from public, anon, authenticated;
revoke execute on function public.record_ai_usage_event(
  uuid,
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric,
  text,
  jsonb,
  jsonb
) from public, anon, authenticated;
revoke execute on function public.upsert_merchant_research_suggestion(
  uuid,
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  jsonb,
  public.confidence,
  uuid,
  uuid
) from public, anon, authenticated;

grant select, insert, update on public.ai_feature_settings to authenticated;
grant select on public.ai_usage_events to authenticated;
grant select on public.ai_jobs to authenticated;
grant select, update (status) on public.merchant_research_suggestions to authenticated;
grant select on public.v_ai_budget_status to authenticated;
grant select on public.v_open_merchant_research_suggestions to authenticated;
grant execute on function public.ensure_ai_feature_settings(uuid) to authenticated, service_role;
grant execute on function public.check_ai_budget(uuid, text, numeric) to authenticated, service_role;
grant execute on function public.record_ai_usage_event(
  uuid,
  uuid,
  text,
  text,
  text,
  integer,
  integer,
  numeric,
  text,
  jsonb,
  jsonb
) to service_role;
grant execute on function public.upsert_merchant_research_suggestion(
  uuid,
  uuid,
  text,
  text,
  text,
  uuid,
  uuid,
  jsonb,
  public.confidence,
  uuid,
  uuid
) to service_role;

grant select, insert, update, delete on public.ai_feature_settings to service_role;
grant select, insert, update, delete on public.ai_usage_events to service_role;
grant select, insert, update, delete on public.ai_jobs to service_role;
grant select, insert, update, delete on public.merchant_research_suggestions to service_role;
grant select on public.v_ai_budget_status to service_role;
grant select on public.v_open_merchant_research_suggestions to service_role;
