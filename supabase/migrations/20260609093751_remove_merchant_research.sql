drop function if exists public.check_ai_budget(uuid, text, numeric);
drop function if exists public.upsert_merchant_research_suggestion(
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
);

drop view if exists public.v_open_merchant_research_suggestions;
drop view if exists public.v_ai_budget_status;

drop table if exists public.merchant_research_suggestions;

alter table public.ai_feature_settings
  rename column merchant_research_enabled to transaction_metadata_suggestion_enabled;

alter table public.ai_feature_settings
  rename column merchant_research_web_search_enabled
  to transaction_metadata_suggestion_web_search_enabled;

alter table public.ai_feature_settings
  alter column transaction_metadata_suggestion_enabled set default true,
  alter column transaction_metadata_suggestion_web_search_enabled set default false;

alter table public.ai_jobs
  drop constraint ai_jobs_job_type_supported;

alter table public.ai_jobs
  add constraint ai_jobs_job_type_supported check (
    job_type in ('expense_qa', 'transaction_metadata_suggestion')
  ) not valid;

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
  coalesce(
    afs.transaction_metadata_suggestion_enabled,
    true
  ) as transaction_metadata_suggestion_enabled,
  coalesce(
    afs.transaction_metadata_suggestion_web_search_enabled,
    false
  ) as transaction_metadata_suggestion_web_search_enabled,
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
    transaction_metadata_suggestion_enabled,
    transaction_metadata_suggestion_web_search_enabled,
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

create function public.check_ai_budget(
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

  if p_feature not in (
    'expense_qa',
    'transaction_metadata_suggestion'
  ) then
    raise exception 'Unsupported AI feature.';
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

  if p_feature = 'transaction_metadata_suggestion'
    and not v_status.transaction_metadata_suggestion_enabled
  then
    raise exception 'Transaction metadata suggestions are disabled for this household.';
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
    v_status.transaction_metadata_suggestion_web_search_enabled;
end;
$$;

revoke all on public.v_ai_budget_status from public, anon, authenticated;
revoke execute on function public.ensure_ai_feature_settings(uuid)
  from public, anon, authenticated;
revoke execute on function public.check_ai_budget(uuid, text, numeric)
  from public, anon, authenticated;

grant select on public.v_ai_budget_status to authenticated;
grant execute on function public.ensure_ai_feature_settings(uuid)
  to authenticated, service_role;
grant execute on function public.check_ai_budget(uuid, text, numeric)
  to authenticated, service_role;

grant select on public.v_ai_budget_status to service_role;
