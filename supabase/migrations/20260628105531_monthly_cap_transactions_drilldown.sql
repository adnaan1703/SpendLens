create or replace function public.get_monthly_cap_transactions(
  p_household_id uuid,
  p_monthly_cap_id uuid,
  p_period_month date,
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  transaction_id uuid,
  transaction_date date,
  statement_merchant text,
  merchant_id uuid,
  merchant_name text,
  category_id uuid,
  category_name text,
  subcategory_id uuid,
  subcategory_name text,
  source_account_id uuid,
  transaction_type public.transaction_type,
  amount numeric(14,2),
  gross_spend numeric(14,2),
  refund_amount numeric(14,2),
  net_expense numeric(14,2),
  currency_code text,
  confidence public.confidence,
  cardholder_name text,
  notes text,
  label_ids uuid[],
  label_names text[],
  is_under_review boolean,
  review_item_id uuid
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_period_month date;
  v_limit integer;
  v_offset integer;
begin
  v_profile_id := app_private.current_profile_id();
  v_period_month := p_period_month;
  v_limit := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to read monthly cap transactions.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.active_household_ids()) then
    raise exception 'You do not have permission to read monthly cap transactions for this household.';
  end if;

  if p_monthly_cap_id is null then
    raise exception 'Monthly cap is required.';
  end if;

  if v_period_month is null
      or v_period_month <> date_trunc('month', v_period_month)::date then
    raise exception 'Monthly cap transaction period must be the first day of the month.';
  end if;

  return query
  with active_cap as (
    select
      mcs.id as monthly_cap_id,
      mcs.household_id
    from public.monthly_cap_series mcs
    where mcs.household_id = p_household_id
      and mcs.id = p_monthly_cap_id
      and (
        mcs.stopped_from_month is null
        or v_period_month < mcs.stopped_from_month
      )
  ),
  active_version as (
    select
      ac.monthly_cap_id,
      ac.household_id,
      mcv.id as monthly_cap_version_id
    from active_cap ac
    join lateral (
      select version_rows.*
      from public.monthly_cap_versions version_rows
      where version_rows.household_id = ac.household_id
        and version_rows.monthly_cap_series_id = ac.monthly_cap_id
        and version_rows.effective_month <= v_period_month
      order by
        version_rows.effective_month desc,
        version_rows.created_at desc,
        version_rows.id desc
      limit 1
    ) mcv on true
  ),
  matched_transactions as (
    select
      av.household_id,
      av.monthly_cap_version_id,
      t.id,
      t.transaction_date,
      t.statement_merchant,
      t.merchant_id,
      t.category_id,
      t.subcategory_id,
      t.source_account_id,
      t.transaction_type,
      t.amount,
      t.gross_spend,
      t.refund_amount,
      t.net_expense,
      t.currency_code,
      t.confidence,
      t.cardholder_name,
      t.notes,
      t.created_at
    from active_version av
    join public.transactions t
      on t.household_id = av.household_id
      and t.transaction_date >= v_period_month
      and t.transaction_date < (v_period_month + interval '1 month')::date
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
  )
  select
    mt.id as transaction_id,
    mt.transaction_date,
    mt.statement_merchant,
    mt.merchant_id,
    merchants.display_name as merchant_name,
    mt.category_id,
    categories.name as category_name,
    mt.subcategory_id,
    subcategories.name as subcategory_name,
    mt.source_account_id,
    mt.transaction_type,
    mt.amount,
    mt.gross_spend,
    mt.refund_amount,
    mt.net_expense,
    mt.currency_code,
    mt.confidence,
    mt.cardholder_name,
    mt.notes,
    coalesce(transaction_labels.label_ids, '{}'::uuid[]) as label_ids,
    coalesce(transaction_labels.label_names, '{}'::text[]) as label_names,
    open_review.review_item_id is not null as is_under_review,
    open_review.review_item_id
  from matched_transactions mt
  left join public.merchants
    on merchants.household_id = mt.household_id
    and merchants.id = mt.merchant_id
  left join public.categories
    on categories.household_id = mt.household_id
    and categories.id = mt.category_id
  left join public.subcategories
    on subcategories.household_id = mt.household_id
    and subcategories.id = mt.subcategory_id
    and subcategories.category_id = mt.category_id
  left join lateral (
    select
      array_agg(l.id order by lower(l.name), l.name, l.id) as label_ids,
      array_agg(l.name order by lower(l.name), l.name, l.id) as label_names
    from public.transaction_labels tl
    join public.labels l
      on l.household_id = tl.household_id
      and l.id = tl.label_id
    where tl.household_id = mt.household_id
      and tl.transaction_id = mt.id
  ) transaction_labels on true
  left join lateral (
    select ri.id as review_item_id
    from public.review_items ri
    where ri.household_id = mt.household_id
      and ri.transaction_id = mt.id
      and ri.status = 'open'
    order by ri.created_at desc, ri.id desc
    limit 1
  ) open_review on true
  order by
    mt.transaction_date desc,
    mt.created_at desc,
    mt.id desc
  limit v_limit
  offset v_offset;
end;
$$;

comment on function public.get_monthly_cap_transactions(
  uuid,
  uuid,
  date,
  integer,
  integer
) is
  'Returns a bounded deterministic page of transactions matching one active recurring monthly cap series for a reporting month.';

revoke execute on function public.get_monthly_cap_transactions(
  uuid,
  uuid,
  date,
  integer,
  integer
) from public, anon;

grant execute on function public.get_monthly_cap_transactions(
  uuid,
  uuid,
  date,
  integer,
  integer
) to authenticated;
