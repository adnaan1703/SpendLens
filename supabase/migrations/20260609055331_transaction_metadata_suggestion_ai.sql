alter table public.ai_jobs
  drop constraint ai_jobs_job_type_supported;

alter table public.ai_jobs
  add constraint ai_jobs_job_type_supported check (
    job_type in (
      'expense_qa',
      'merchant_research',
      'transaction_metadata_suggestion'
    )
  );

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

  if p_feature not in (
    'expense_qa',
    'merchant_research',
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

  if p_feature in (
    'merchant_research',
    'transaction_metadata_suggestion'
  ) and not v_status.merchant_research_enabled then
    raise exception 'Merchant metadata AI is disabled for this household.';
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
