create or replace view public.v_monthly_cap_progress
with (security_invoker = true)
as
with recursive recurring_bounds as (
  select
    mcs.id as monthly_cap_id,
    mcs.household_id,
    min(mcv.effective_month) as first_month,
    max(mcv.effective_month) as last_month
  from public.monthly_cap_series mcs
  join public.monthly_cap_versions mcv
    on mcv.household_id = mcs.household_id
    and mcv.monthly_cap_series_id = mcs.id
  where mcs.stopped_from_month is null
    or mcv.effective_month < mcs.stopped_from_month
  group by mcs.id, mcs.household_id
),
recurring_months as (
  select
    rb.monthly_cap_id,
    rb.household_id,
    rb.first_month as period_month,
    rb.last_month
  from recurring_bounds rb
  where rb.first_month <= rb.last_month

  union all

  select
    rm.monthly_cap_id,
    rm.household_id,
    (rm.period_month + interval '1 month')::date,
    rm.last_month
  from recurring_months rm
  where rm.period_month < rm.last_month
),
active_versions as (
  select
    rm.monthly_cap_id,
    mcv.id as monthly_cap_version_id,
    rm.household_id,
    mcv.name,
    rm.period_month,
    mcv.base_amount,
    mcv.carry_forward_enabled
  from recurring_months rm
  join lateral (
    select version_rows.*
    from public.monthly_cap_versions version_rows
    where version_rows.household_id = rm.household_id
      and version_rows.monthly_cap_series_id = rm.monthly_cap_id
      and version_rows.effective_month <= rm.period_month
    order by version_rows.effective_month desc, version_rows.created_at desc
    limit 1
  ) mcv on true
),
active_version_ids as (
  select distinct
    av.household_id,
    av.monthly_cap_version_id
  from active_versions av
),
category_targets as (
  select
    mvc.household_id,
    mvc.monthly_cap_version_id,
    array_agg(c.id order by lower(c.name), c.name, c.id)
      as category_target_ids,
    array_agg(c.name order by lower(c.name), c.name, c.id)
      as category_target_names
  from public.monthly_cap_version_categories mvc
  join active_version_ids avi
    on avi.household_id = mvc.household_id
    and avi.monthly_cap_version_id = mvc.monthly_cap_version_id
  join public.categories c
    on c.id = mvc.category_id
    and c.household_id = mvc.household_id
  group by mvc.household_id, mvc.monthly_cap_version_id
),
label_targets as (
  select
    mvl.household_id,
    mvl.monthly_cap_version_id,
    array_agg(l.id order by lower(l.name), l.name, l.id)
      as label_target_ids,
    array_agg(l.name order by lower(l.name), l.name, l.id)
      as label_target_names
  from public.monthly_cap_version_labels mvl
  join active_version_ids avi
    on avi.household_id = mvl.household_id
    and avi.monthly_cap_version_id = mvl.monthly_cap_version_id
  join public.labels l
    on l.id = mvl.label_id
    and l.household_id = mvl.household_id
  group by mvl.household_id, mvl.monthly_cap_version_id
),
matched_transactions as (
  select
    av.monthly_cap_id,
    av.monthly_cap_version_id,
    av.period_month,
    t.id as transaction_id,
    t.net_expense
  from active_versions av
  join public.transactions t
    on t.household_id = av.household_id
    and t.transaction_date >= av.period_month
    and t.transaction_date < (av.period_month + interval '1 month')::date
    and (
      exists (
        select 1
        from public.monthly_cap_version_categories mvc
        where mvc.household_id = av.household_id
          and mvc.monthly_cap_version_id = av.monthly_cap_version_id
          and mvc.category_id = t.category_id
      )
      or exists (
        select 1
        from public.monthly_cap_version_labels mvl
        join public.transaction_labels tl
          on tl.household_id = mvl.household_id
          and tl.label_id = mvl.label_id
          and tl.transaction_id = t.id
        where mvl.household_id = av.household_id
          and mvl.monthly_cap_version_id = av.monthly_cap_version_id
      )
    )
),
progress as (
  select
    mt.monthly_cap_id,
    mt.monthly_cap_version_id,
    mt.period_month,
    count(distinct mt.transaction_id)::integer as matched_transaction_count,
    coalesce(sum(mt.net_expense), 0)::numeric(14,2) as spent_amount
  from matched_transactions mt
  group by mt.monthly_cap_id, mt.monthly_cap_version_id, mt.period_month
),
carry_chain as (
  select
    av.monthly_cap_id,
    av.monthly_cap_version_id,
    av.household_id,
    av.name,
    av.period_month,
    av.base_amount,
    av.carry_forward_enabled,
    0::numeric(14,2) as carry_forward_amount,
    av.base_amount::numeric(14,2) as effective_cap_amount,
    coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
    coalesce(progress.matched_transaction_count, 0)::integer
      as matched_transaction_count
  from active_versions av
  left join progress
    on progress.monthly_cap_id = av.monthly_cap_id
    and progress.monthly_cap_version_id = av.monthly_cap_version_id
    and progress.period_month = av.period_month
  where not exists (
    select 1
    from active_versions prior_versions
    where prior_versions.monthly_cap_id = av.monthly_cap_id
      and prior_versions.period_month < av.period_month
  )

  union all

  select
    av.monthly_cap_id,
    av.monthly_cap_version_id,
    av.household_id,
    av.name,
    av.period_month,
    av.base_amount,
    av.carry_forward_enabled,
    case
      when av.carry_forward_enabled and cc.carry_forward_enabled then
        (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2)
      else 0::numeric(14,2)
    end as carry_forward_amount,
    (
      av.base_amount +
      case
        when av.carry_forward_enabled and cc.carry_forward_enabled then
          (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2)
        else 0::numeric(14,2)
      end
    )::numeric(14,2) as effective_cap_amount,
    coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
    coalesce(progress.matched_transaction_count, 0)::integer
      as matched_transaction_count
  from carry_chain cc
  join active_versions av
    on av.monthly_cap_id = cc.monthly_cap_id
    and av.period_month = (cc.period_month + interval '1 month')::date
  left join progress
    on progress.monthly_cap_id = av.monthly_cap_id
    and progress.monthly_cap_version_id = av.monthly_cap_version_id
    and progress.period_month = av.period_month
),
recurring_progress as (
  select
    cc.monthly_cap_id,
    cc.monthly_cap_version_id,
    cc.household_id,
    cc.name,
    cc.period_month,
    cc.base_amount as cap_amount,
    cc.base_amount as base_cap_amount,
    cc.carry_forward_enabled,
    cc.carry_forward_amount,
    cc.effective_cap_amount,
    cc.spent_amount,
    (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2)
      as remaining_amount,
    case
      when cc.effective_cap_amount > 0 then
        round(cc.spent_amount / cc.effective_cap_amount, 4)
      else null::numeric
    end as percent_used,
    (cc.effective_cap_amount - cc.spent_amount) < 0 as is_over_budget,
    cc.matched_transaction_count,
    coalesce(category_targets.category_target_ids, '{}'::uuid[])
      as category_target_ids,
    coalesce(category_targets.category_target_names, '{}'::text[])
      as category_target_names,
    coalesce(label_targets.label_target_ids, '{}'::uuid[])
      as label_target_ids,
    coalesce(label_targets.label_target_names, '{}'::text[])
      as label_target_names
  from carry_chain cc
  left join category_targets
    on category_targets.household_id = cc.household_id
    and category_targets.monthly_cap_version_id = cc.monthly_cap_version_id
  left join label_targets
    on label_targets.household_id = cc.household_id
    and label_targets.monthly_cap_version_id = cc.monthly_cap_version_id
  where exists (
    select 1
    from public.monthly_cap_versions version_months
    where version_months.id = cc.monthly_cap_version_id
      and version_months.household_id = cc.household_id
      and version_months.effective_month = cc.period_month
  )
),
legacy_caps as (
  select
    mc.id as monthly_cap_id,
    null::uuid as monthly_cap_version_id,
    mc.household_id,
    mc.name,
    mc.period_month,
    mc.cap_amount as base_amount,
    false as carry_forward_enabled
  from public.monthly_caps mc
  where not exists (
    select 1
    from public.monthly_cap_series mcs
    where mcs.id = mc.id
      and mcs.household_id = mc.household_id
  )
),
legacy_category_targets as (
  select
    mcc.household_id,
    mcc.monthly_cap_id,
    array_agg(c.id order by lower(c.name), c.name, c.id)
      as category_target_ids,
    array_agg(c.name order by lower(c.name), c.name, c.id)
      as category_target_names
  from public.monthly_cap_categories mcc
  join public.categories c
    on c.id = mcc.category_id
    and c.household_id = mcc.household_id
  group by mcc.household_id, mcc.monthly_cap_id
),
legacy_label_targets as (
  select
    mcl.household_id,
    mcl.monthly_cap_id,
    array_agg(l.id order by lower(l.name), l.name, l.id) as label_target_ids,
    array_agg(l.name order by lower(l.name), l.name, l.id)
      as label_target_names
  from public.monthly_cap_labels mcl
  join public.labels l
    on l.id = mcl.label_id
    and l.household_id = mcl.household_id
  group by mcl.household_id, mcl.monthly_cap_id
),
legacy_matched_transactions as (
  select
    lc.monthly_cap_id,
    lc.monthly_cap_version_id,
    t.id as transaction_id,
    t.net_expense
  from legacy_caps lc
  join public.transactions t
    on t.household_id = lc.household_id
    and t.transaction_date >= lc.period_month
    and t.transaction_date < (lc.period_month + interval '1 month')::date
    and (
      exists (
        select 1
        from public.monthly_cap_categories mcc
        where mcc.household_id = lc.household_id
          and mcc.monthly_cap_id = lc.monthly_cap_id
          and mcc.category_id = t.category_id
      )
      or exists (
        select 1
        from public.monthly_cap_labels mcl
        join public.transaction_labels tl
          on tl.household_id = mcl.household_id
          and tl.label_id = mcl.label_id
          and tl.transaction_id = t.id
        where mcl.household_id = lc.household_id
          and mcl.monthly_cap_id = lc.monthly_cap_id
      )
    )
),
legacy_progress_aggregate as (
  select
    lmt.monthly_cap_id,
    count(distinct lmt.transaction_id)::integer as matched_transaction_count,
    coalesce(sum(lmt.net_expense), 0)::numeric(14,2) as spent_amount
  from legacy_matched_transactions lmt
  group by lmt.monthly_cap_id
),
legacy_progress as (
  select
    lc.monthly_cap_id,
    lc.monthly_cap_version_id,
    lc.household_id,
    lc.name,
    lc.period_month,
    lc.base_amount as cap_amount,
    lc.base_amount as base_cap_amount,
    lc.carry_forward_enabled,
    0::numeric(14,2) as carry_forward_amount,
    lc.base_amount as effective_cap_amount,
    coalesce(legacy_progress_aggregate.spent_amount, 0)::numeric(14,2)
      as spent_amount,
    (
      lc.base_amount - coalesce(legacy_progress_aggregate.spent_amount, 0)
    )::numeric(14,2) as remaining_amount,
    case
      when lc.base_amount > 0 then
        round(coalesce(legacy_progress_aggregate.spent_amount, 0) / lc.base_amount, 4)
      else null::numeric
    end as percent_used,
    coalesce(legacy_progress_aggregate.spent_amount, 0) > lc.base_amount
      as is_over_budget,
    coalesce(legacy_progress_aggregate.matched_transaction_count, 0)::integer
      as matched_transaction_count,
    coalesce(legacy_category_targets.category_target_ids, '{}'::uuid[])
      as category_target_ids,
    coalesce(legacy_category_targets.category_target_names, '{}'::text[])
      as category_target_names,
    coalesce(legacy_label_targets.label_target_ids, '{}'::uuid[])
      as label_target_ids,
    coalesce(legacy_label_targets.label_target_names, '{}'::text[])
      as label_target_names
  from legacy_caps lc
  left join legacy_progress_aggregate
    on legacy_progress_aggregate.monthly_cap_id = lc.monthly_cap_id
  left join legacy_category_targets
    on legacy_category_targets.household_id = lc.household_id
    and legacy_category_targets.monthly_cap_id = lc.monthly_cap_id
  left join legacy_label_targets
    on legacy_label_targets.household_id = lc.household_id
    and legacy_label_targets.monthly_cap_id = lc.monthly_cap_id
)
select * from recurring_progress
union all
select * from legacy_progress;

create or replace function public.get_monthly_cap_progress(
  p_household_id uuid,
  p_period_month date
)
returns table (
  monthly_cap_id uuid,
  monthly_cap_version_id uuid,
  household_id uuid,
  name text,
  period_month date,
  cap_amount numeric(14,2),
  base_cap_amount numeric(14,2),
  carry_forward_enabled boolean,
  carry_forward_amount numeric(14,2),
  effective_cap_amount numeric(14,2),
  spent_amount numeric(14,2),
  remaining_amount numeric(14,2),
  percent_used numeric,
  is_over_budget boolean,
  matched_transaction_count integer,
  category_target_ids uuid[],
  category_target_names text[],
  label_target_ids uuid[],
  label_target_names text[]
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_period_month date;
begin
  v_profile_id := app_private.current_profile_id();
  v_period_month := p_period_month;

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to read monthly caps.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.active_household_ids()) then
    raise exception 'You do not have permission to read monthly caps for this household.';
  end if;

  if v_period_month is null
      or v_period_month <> date_trunc('month', v_period_month)::date then
    raise exception 'Monthly cap period must be the first day of the month.';
  end if;

  return query
  with recursive series_bounds as (
    select
      mcs.id as monthly_cap_id,
      mcs.household_id,
      min(mcv.effective_month) as first_month
    from public.monthly_cap_series mcs
    join public.monthly_cap_versions mcv
      on mcv.household_id = mcs.household_id
      and mcv.monthly_cap_series_id = mcs.id
    where mcs.household_id = p_household_id
      and mcv.effective_month <= v_period_month
      and (
        mcs.stopped_from_month is null
        or v_period_month < mcs.stopped_from_month
      )
    group by mcs.id, mcs.household_id
  ),
  series_months as (
    select
      sb.monthly_cap_id,
      sb.household_id,
      sb.first_month as period_month
    from series_bounds sb

    union all

    select
      sm.monthly_cap_id,
      sm.household_id,
      (sm.period_month + interval '1 month')::date
    from series_months sm
    where sm.period_month < v_period_month
  ),
  active_versions as (
    select
      sm.monthly_cap_id,
      mcv.id as monthly_cap_version_id,
      sm.household_id,
      mcv.name,
      sm.period_month,
      mcv.base_amount,
      mcv.carry_forward_enabled
    from series_months sm
    join lateral (
      select version_rows.*
      from public.monthly_cap_versions version_rows
      where version_rows.household_id = sm.household_id
        and version_rows.monthly_cap_series_id = sm.monthly_cap_id
        and version_rows.effective_month <= sm.period_month
      order by version_rows.effective_month desc, version_rows.created_at desc
      limit 1
    ) mcv on true
  ),
  active_version_ids as (
    select distinct
      av.household_id,
      av.monthly_cap_version_id
    from active_versions av
  ),
  category_targets as (
    select
      mvc.household_id,
      mvc.monthly_cap_version_id,
      array_agg(c.id order by lower(c.name), c.name, c.id)
        as category_target_ids,
      array_agg(c.name order by lower(c.name), c.name, c.id)
        as category_target_names
    from public.monthly_cap_version_categories mvc
    join active_version_ids avi
      on avi.household_id = mvc.household_id
      and avi.monthly_cap_version_id = mvc.monthly_cap_version_id
    join public.categories c
      on c.id = mvc.category_id
      and c.household_id = mvc.household_id
    group by mvc.household_id, mvc.monthly_cap_version_id
  ),
  label_targets as (
    select
      mvl.household_id,
      mvl.monthly_cap_version_id,
      array_agg(l.id order by lower(l.name), l.name, l.id)
        as label_target_ids,
      array_agg(l.name order by lower(l.name), l.name, l.id)
        as label_target_names
    from public.monthly_cap_version_labels mvl
    join active_version_ids avi
      on avi.household_id = mvl.household_id
      and avi.monthly_cap_version_id = mvl.monthly_cap_version_id
    join public.labels l
      on l.id = mvl.label_id
      and l.household_id = mvl.household_id
    group by mvl.household_id, mvl.monthly_cap_version_id
  ),
  matched_transactions as (
    select
      av.monthly_cap_id,
      av.monthly_cap_version_id,
      av.period_month,
      t.id as transaction_id,
      t.net_expense
    from active_versions av
    join public.transactions t
      on t.household_id = av.household_id
      and t.transaction_date >= av.period_month
      and t.transaction_date < (av.period_month + interval '1 month')::date
      and (
        exists (
          select 1
          from public.monthly_cap_version_categories mvc
          where mvc.household_id = av.household_id
            and mvc.monthly_cap_version_id = av.monthly_cap_version_id
            and mvc.category_id = t.category_id
        )
        or exists (
          select 1
          from public.monthly_cap_version_labels mvl
          join public.transaction_labels tl
            on tl.household_id = mvl.household_id
            and tl.label_id = mvl.label_id
            and tl.transaction_id = t.id
          where mvl.household_id = av.household_id
            and mvl.monthly_cap_version_id = av.monthly_cap_version_id
        )
      )
  ),
  progress as (
    select
      mt.monthly_cap_id,
      mt.monthly_cap_version_id,
      mt.period_month,
      count(distinct mt.transaction_id)::integer as matched_transaction_count,
      coalesce(sum(mt.net_expense), 0)::numeric(14,2) as spent_amount
    from matched_transactions mt
    group by mt.monthly_cap_id, mt.monthly_cap_version_id, mt.period_month
  ),
  carry_chain as (
    select
      av.monthly_cap_id,
      av.monthly_cap_version_id,
      av.household_id,
      av.name,
      av.period_month,
      av.base_amount,
      av.carry_forward_enabled,
      0::numeric(14,2) as carry_forward_amount,
      av.base_amount::numeric(14,2) as effective_cap_amount,
      coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
      coalesce(progress.matched_transaction_count, 0)::integer
        as matched_transaction_count
    from active_versions av
    left join progress
      on progress.monthly_cap_id = av.monthly_cap_id
      and progress.monthly_cap_version_id = av.monthly_cap_version_id
      and progress.period_month = av.period_month
    where av.period_month = (
      select min(first_versions.period_month)
      from active_versions first_versions
      where first_versions.monthly_cap_id = av.monthly_cap_id
    )

    union all

    select
      av.monthly_cap_id,
      av.monthly_cap_version_id,
      av.household_id,
      av.name,
      av.period_month,
      av.base_amount,
      av.carry_forward_enabled,
      case
        when av.carry_forward_enabled and cc.carry_forward_enabled then
          (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2)
        else 0::numeric(14,2)
      end as carry_forward_amount,
      (
        av.base_amount +
        case
          when av.carry_forward_enabled and cc.carry_forward_enabled then
            (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2)
          else 0::numeric(14,2)
        end
      )::numeric(14,2) as effective_cap_amount,
      coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
      coalesce(progress.matched_transaction_count, 0)::integer
        as matched_transaction_count
    from carry_chain cc
    join active_versions av
      on av.monthly_cap_id = cc.monthly_cap_id
      and av.period_month = (cc.period_month + interval '1 month')::date
    left join progress
      on progress.monthly_cap_id = av.monthly_cap_id
      and progress.monthly_cap_version_id = av.monthly_cap_version_id
      and progress.period_month = av.period_month
  )
  select
    cc.monthly_cap_id,
    cc.monthly_cap_version_id,
    cc.household_id,
    cc.name,
    cc.period_month,
    cc.base_amount,
    cc.base_amount,
    cc.carry_forward_enabled,
    cc.carry_forward_amount,
    cc.effective_cap_amount,
    cc.spent_amount,
    (cc.effective_cap_amount - cc.spent_amount)::numeric(14,2),
    case
      when cc.effective_cap_amount > 0 then
        round(cc.spent_amount / cc.effective_cap_amount, 4)
      else null::numeric
    end,
    (cc.effective_cap_amount - cc.spent_amount) < 0,
    cc.matched_transaction_count,
    coalesce(category_targets.category_target_ids, '{}'::uuid[]),
    coalesce(category_targets.category_target_names, '{}'::text[]),
    coalesce(label_targets.label_target_ids, '{}'::uuid[]),
    coalesce(label_targets.label_target_names, '{}'::text[])
  from carry_chain cc
  left join category_targets
    on category_targets.household_id = cc.household_id
    and category_targets.monthly_cap_version_id = cc.monthly_cap_version_id
  left join label_targets
    on label_targets.household_id = cc.household_id
    and label_targets.monthly_cap_version_id = cc.monthly_cap_version_id
  where cc.period_month = v_period_month
  order by
    case
      when cc.effective_cap_amount > 0 then
        cc.spent_amount / cc.effective_cap_amount
      else null::numeric
    end desc nulls last,
    cc.name;
end;
$$;
