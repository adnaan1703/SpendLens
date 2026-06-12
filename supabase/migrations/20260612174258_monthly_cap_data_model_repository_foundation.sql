create table public.monthly_caps (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  period_month date not null,
  cap_amount numeric(14,2) not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint monthly_caps_name_trimmed_nonempty check (
    btrim(name) <> ''
    and name = btrim(name)
  ),
  constraint monthly_caps_period_month_first_day check (
    period_month = date_trunc('month', period_month)::date
  ),
  constraint monthly_caps_cap_amount_nonnegative check (cap_amount >= 0)
);

create table public.monthly_cap_categories (
  household_id uuid not null references public.households (id) on delete cascade,
  monthly_cap_id uuid not null,
  category_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (monthly_cap_id, category_id),
  constraint monthly_cap_categories_cap_household_fk
    foreign key (monthly_cap_id, household_id)
    references public.monthly_caps (id, household_id) on delete cascade,
  constraint monthly_cap_categories_category_household_fk
    foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete cascade
);

create table public.monthly_cap_labels (
  household_id uuid not null references public.households (id) on delete cascade,
  monthly_cap_id uuid not null,
  label_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (monthly_cap_id, label_id),
  constraint monthly_cap_labels_cap_household_fk
    foreign key (monthly_cap_id, household_id)
    references public.monthly_caps (id, household_id) on delete cascade,
  constraint monthly_cap_labels_label_household_fk
    foreign key (label_id, household_id)
    references public.labels (id, household_id) on delete cascade
);

create unique index monthly_caps_household_month_lower_name_key
  on public.monthly_caps (household_id, period_month, lower(name));
create index monthly_caps_household_month_idx
  on public.monthly_caps (household_id, period_month);
create index monthly_cap_categories_household_category_idx
  on public.monthly_cap_categories (household_id, category_id);
create index monthly_cap_labels_household_label_idx
  on public.monthly_cap_labels (household_id, label_id);

create trigger set_monthly_caps_updated_at
  before update on public.monthly_caps
  for each row execute function app_private.set_updated_at();

alter table public.monthly_caps enable row level security;
alter table public.monthly_cap_categories enable row level security;
alter table public.monthly_cap_labels enable row level security;

create policy "monthly_caps_select_members"
  on public.monthly_caps
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_caps_insert_writers"
  on public.monthly_caps
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "monthly_caps_update_writers"
  on public.monthly_caps
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_caps_delete_writers"
  on public.monthly_caps
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "monthly_cap_categories_select_members"
  on public.monthly_cap_categories
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_categories_insert_writers"
  on public.monthly_cap_categories
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_categories_update_writers"
  on public.monthly_cap_categories
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_categories_delete_writers"
  on public.monthly_cap_categories
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "monthly_cap_labels_select_members"
  on public.monthly_cap_labels
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_labels_insert_writers"
  on public.monthly_cap_labels
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_labels_update_writers"
  on public.monthly_cap_labels
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_labels_delete_writers"
  on public.monthly_cap_labels
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

do $$
begin
  if exists (
    select 1
    from public.category_caps cc
    join public.categories c
      on c.id = cc.category_id
      and c.household_id = cc.household_id
    group by cc.household_id, cc.period_month, lower(btrim(c.name))
    having count(*) > 1
  ) then
    raise exception 'Cannot backfill monthly caps because duplicate category cap names exist for the same household and month.';
  end if;
end;
$$;

insert into public.monthly_caps (
  id,
  household_id,
  name,
  period_month,
  cap_amount,
  created_by,
  created_at,
  updated_at
)
select
  cc.id,
  cc.household_id,
  btrim(c.name),
  cc.period_month,
  cc.cap_amount,
  cc.created_by,
  cc.created_at,
  cc.updated_at
from public.category_caps cc
join public.categories c
  on c.id = cc.category_id
  and c.household_id = cc.household_id;

insert into public.monthly_cap_categories (
  household_id,
  monthly_cap_id,
  category_id,
  created_at
)
select
  cc.household_id,
  cc.id,
  cc.category_id,
  cc.created_at
from public.category_caps cc;

create or replace function public.upsert_monthly_cap(
  p_household_id uuid,
  p_monthly_cap_id uuid default null,
  p_name text default null,
  p_period_month date default null,
  p_cap_amount numeric default null,
  p_category_ids uuid[] default '{}',
  p_label_ids uuid[] default '{}'
)
returns table (
  monthly_cap_id uuid,
  household_id uuid,
  name text,
  period_month date,
  cap_amount numeric(14,2),
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz,
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
  v_monthly_cap_id uuid;
  v_name text;
  v_period_month date;
  v_cap_amount numeric(14,2);
  v_category_ids uuid[];
  v_label_ids uuid[];
begin
  v_profile_id := app_private.current_profile_id();
  v_name := nullif(btrim(p_name), '');
  v_period_month := p_period_month;
  v_cap_amount := p_cap_amount;

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to save monthly caps.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to save monthly caps for this household.';
  end if;

  if v_name is null then
    raise exception 'Monthly cap name is required.';
  end if;

  if v_period_month is null
      or v_period_month <> date_trunc('month', v_period_month)::date then
    raise exception 'Monthly cap period must be the first day of the month.';
  end if;

  if v_cap_amount is null or v_cap_amount < 0 then
    raise exception 'Monthly cap amount cannot be negative.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_category_ids, '{}'::uuid[])) as provided(category_id)
    where provided.category_id is null
  ) then
    raise exception 'Category IDs cannot be blank.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_label_ids, '{}'::uuid[])) as provided(label_id)
    where provided.label_id is null
  ) then
    raise exception 'Label IDs cannot be blank.';
  end if;

  select coalesce(array_agg(category_id order by category_id), '{}'::uuid[])
  into v_category_ids
  from (
    select distinct provided.category_id
    from unnest(coalesce(p_category_ids, '{}'::uuid[])) as provided(category_id)
    where provided.category_id is not null
  ) distinct_categories;

  select coalesce(array_agg(label_id order by label_id), '{}'::uuid[])
  into v_label_ids
  from (
    select distinct provided.label_id
    from unnest(coalesce(p_label_ids, '{}'::uuid[])) as provided(label_id)
    where provided.label_id is not null
  ) distinct_labels;

  if cardinality(v_category_ids) = 0 and cardinality(v_label_ids) = 0 then
    raise exception 'At least one category or label target is required.';
  end if;

  if exists (
    select 1
    from unnest(v_category_ids) as provided(category_id)
    where not exists (
      select 1
      from public.categories c
      where c.id = provided.category_id
        and c.household_id = p_household_id
    )
  ) then
    raise exception 'Categories must belong to this household.';
  end if;

  if exists (
    select 1
    from unnest(v_label_ids) as provided(label_id)
    where not exists (
      select 1
      from public.labels l
      where l.id = provided.label_id
        and l.household_id = p_household_id
    )
  ) then
    raise exception 'Labels must belong to this household.';
  end if;

  if p_monthly_cap_id is null then
    insert into public.monthly_caps (
      household_id,
      name,
      period_month,
      cap_amount,
      created_by
    )
    values (
      p_household_id,
      v_name,
      v_period_month,
      v_cap_amount,
      v_profile_id
    )
    returning id into v_monthly_cap_id;
  else
    perform 1
    from public.monthly_caps mc
    where mc.id = p_monthly_cap_id
      and mc.household_id = p_household_id
    for update;

    if not found then
      raise exception 'Monthly cap not found for this household.';
    end if;

    update public.monthly_caps mc
    set name = v_name,
        period_month = v_period_month,
        cap_amount = v_cap_amount
    where mc.id = p_monthly_cap_id
      and mc.household_id = p_household_id
    returning mc.id into v_monthly_cap_id;
  end if;

  delete from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.monthly_cap_id = v_monthly_cap_id;

  delete from public.monthly_cap_labels mcl
  where mcl.household_id = p_household_id
    and mcl.monthly_cap_id = v_monthly_cap_id;

  insert into public.monthly_cap_categories (
    household_id,
    monthly_cap_id,
    category_id
  )
  select
    p_household_id,
    v_monthly_cap_id,
    category_targets.category_id
  from unnest(v_category_ids) as category_targets(category_id)
  on conflict on constraint monthly_cap_categories_pkey do nothing;

  insert into public.monthly_cap_labels (
    household_id,
    monthly_cap_id,
    label_id
  )
  select
    p_household_id,
    v_monthly_cap_id,
    label_targets.label_id
  from unnest(v_label_ids) as label_targets(label_id)
  on conflict on constraint monthly_cap_labels_pkey do nothing;

  return query
  select
    mc.id,
    mc.household_id,
    mc.name,
    mc.period_month,
    mc.cap_amount,
    mc.created_by,
    mc.created_at,
    mc.updated_at,
    coalesce(category_targets.category_target_ids, '{}'::uuid[]),
    coalesce(category_targets.category_target_names, '{}'::text[]),
    coalesce(label_targets.label_target_ids, '{}'::uuid[]),
    coalesce(label_targets.label_target_names, '{}'::text[])
  from public.monthly_caps mc
  left join lateral (
    select
      array_agg(c.id order by lower(c.name), c.name, c.id) as category_target_ids,
      array_agg(c.name order by lower(c.name), c.name, c.id) as category_target_names
    from public.monthly_cap_categories mcc
    join public.categories c
      on c.id = mcc.category_id
      and c.household_id = mcc.household_id
    where mcc.household_id = mc.household_id
      and mcc.monthly_cap_id = mc.id
  ) category_targets on true
  left join lateral (
    select
      array_agg(l.id order by lower(l.name), l.name, l.id) as label_target_ids,
      array_agg(l.name order by lower(l.name), l.name, l.id) as label_target_names
    from public.monthly_cap_labels mcl
    join public.labels l
      on l.id = mcl.label_id
      and l.household_id = mcl.household_id
    where mcl.household_id = mc.household_id
      and mcl.monthly_cap_id = mc.id
  ) label_targets on true
  where mc.id = v_monthly_cap_id
    and mc.household_id = p_household_id;
exception
  when unique_violation then
    raise exception 'A monthly cap with this name already exists for this month.';
end;
$$;

create or replace function public.delete_monthly_cap(
  p_household_id uuid,
  p_monthly_cap_id uuid
)
returns table (
  monthly_cap_id uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete monthly caps.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to delete monthly caps for this household.';
  end if;

  perform 1
  from public.monthly_caps mc
  where mc.id = p_monthly_cap_id
    and mc.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Monthly cap not found for this household.';
  end if;

  delete from public.monthly_caps mc
  where mc.id = p_monthly_cap_id
    and mc.household_id = p_household_id;

  monthly_cap_id := p_monthly_cap_id;
  return next;
end;
$$;

create view public.v_monthly_cap_progress
with (security_invoker = true)
as
with category_targets as (
  select
    mcc.household_id,
    mcc.monthly_cap_id,
    array_agg(c.id order by lower(c.name), c.name, c.id) as category_target_ids,
    array_agg(c.name order by lower(c.name), c.name, c.id) as category_target_names
  from public.monthly_cap_categories mcc
  join public.categories c
    on c.id = mcc.category_id
    and c.household_id = mcc.household_id
  group by mcc.household_id, mcc.monthly_cap_id
),
label_targets as (
  select
    mcl.household_id,
    mcl.monthly_cap_id,
    array_agg(l.id order by lower(l.name), l.name, l.id) as label_target_ids,
    array_agg(l.name order by lower(l.name), l.name, l.id) as label_target_names
  from public.monthly_cap_labels mcl
  join public.labels l
    on l.id = mcl.label_id
    and l.household_id = mcl.household_id
  group by mcl.household_id, mcl.monthly_cap_id
),
matched_transactions as (
  select
    mc.id as monthly_cap_id,
    t.id as transaction_id,
    t.net_expense
  from public.monthly_caps mc
  join public.transactions t
    on t.household_id = mc.household_id
    and t.transaction_date >= mc.period_month
    and t.transaction_date < (mc.period_month + interval '1 month')::date
    and (
      exists (
        select 1
        from public.monthly_cap_categories mcc
        where mcc.household_id = mc.household_id
          and mcc.monthly_cap_id = mc.id
          and mcc.category_id = t.category_id
      )
      or exists (
        select 1
        from public.monthly_cap_labels mcl
        join public.transaction_labels tl
          on tl.household_id = mcl.household_id
          and tl.label_id = mcl.label_id
          and tl.transaction_id = t.id
        where mcl.household_id = mc.household_id
          and mcl.monthly_cap_id = mc.id
      )
    )
),
progress as (
  select
    matched_transactions.monthly_cap_id,
    count(distinct matched_transactions.transaction_id)::integer
      as matched_transaction_count,
    coalesce(sum(matched_transactions.net_expense), 0)::numeric(14,2)
      as spent_amount
  from matched_transactions
  group by matched_transactions.monthly_cap_id
)
select
  mc.id as monthly_cap_id,
  mc.household_id,
  mc.name,
  mc.period_month,
  mc.cap_amount,
  coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
  (mc.cap_amount - coalesce(progress.spent_amount, 0))::numeric(14,2)
    as remaining_amount,
  case
    when mc.cap_amount > 0 then
      round(coalesce(progress.spent_amount, 0) / mc.cap_amount, 4)
    else null
  end as percent_used,
  coalesce(progress.spent_amount, 0) > mc.cap_amount as is_over_budget,
  coalesce(progress.matched_transaction_count, 0)::integer
    as matched_transaction_count,
  coalesce(category_targets.category_target_ids, '{}'::uuid[])
    as category_target_ids,
  coalesce(category_targets.category_target_names, '{}'::text[])
    as category_target_names,
  coalesce(label_targets.label_target_ids, '{}'::uuid[])
    as label_target_ids,
  coalesce(label_targets.label_target_names, '{}'::text[])
    as label_target_names
from public.monthly_caps mc
left join progress
  on progress.monthly_cap_id = mc.id
left join category_targets
  on category_targets.household_id = mc.household_id
  and category_targets.monthly_cap_id = mc.id
left join label_targets
  on label_targets.household_id = mc.household_id
  and label_targets.monthly_cap_id = mc.id;

create or replace view public.v_budget_progress
with (security_invoker = true)
as
select
  mcp.household_id,
  mcp.period_month,
  mcc.category_id,
  c.name as category_name,
  mcp.cap_amount,
  mcp.spent_amount,
  mcp.remaining_amount,
  mcp.percent_used,
  mcp.is_over_budget
from public.v_monthly_cap_progress mcp
join public.monthly_cap_categories mcc
  on mcc.monthly_cap_id = mcp.monthly_cap_id
  and mcc.household_id = mcp.household_id
join public.categories c
  on c.id = mcc.category_id
  and c.household_id = mcc.household_id
where cardinality(mcp.category_target_ids) = 1
  and cardinality(mcp.label_target_ids) = 0;

drop policy if exists "categories_delete_writers" on public.categories;
create policy "categories_delete_writers"
  on public.categories
  for delete
  to authenticated
  using (
    household_id in (select app_private.write_household_ids())
    and not exists (
      select 1
      from public.transactions t
      where t.household_id = categories.household_id
        and (
          t.category_id = categories.id
          or exists (
            select 1
            from public.subcategories sc
            where sc.id = t.subcategory_id
              and sc.household_id = t.household_id
              and sc.category_id = categories.id
          )
        )
    )
    and not exists (
      select 1
      from public.merchants m
      where m.household_id = categories.household_id
        and (
          m.category_id = categories.id
          or exists (
            select 1
            from public.subcategories sc
            where sc.id = m.subcategory_id
              and sc.household_id = m.household_id
              and sc.category_id = categories.id
          )
        )
    )
    and not exists (
      select 1
      from public.merchant_mapping_rules mmr
      where mmr.household_id = categories.household_id
        and (
          mmr.category_id = categories.id
          or exists (
            select 1
            from public.subcategories sc
            where sc.id = mmr.subcategory_id
              and sc.household_id = mmr.household_id
              and sc.category_id = categories.id
          )
        )
    )
    and not exists (
      select 1
      from public.review_items ri
      where ri.household_id = categories.household_id
        and (
          ri.suggested_category_id = categories.id
          or exists (
            select 1
            from public.subcategories sc
            where sc.id = ri.suggested_subcategory_id
              and sc.household_id = ri.household_id
              and sc.category_id = categories.id
          )
        )
    )
    and not exists (
      select 1
      from public.monthly_cap_categories mcc
      where mcc.household_id = categories.household_id
        and mcc.category_id = categories.id
    )
  );

drop policy if exists "labels_delete_writers" on public.labels;
create policy "labels_delete_writers"
  on public.labels
  for delete
  to authenticated
  using (
    household_id in (select app_private.write_household_ids())
    and not exists (
      select 1
      from public.monthly_cap_labels mcl
      where mcl.household_id = labels.household_id
        and mcl.label_id = labels.id
    )
  );

create or replace function public.delete_household_category(
  p_household_id uuid,
  p_category_id uuid
)
returns table (
  deleted_category_id uuid,
  affected_transaction_count integer,
  opened_review_item_count integer,
  deactivated_mapping_rule_count integer,
  cleared_merchant_count integer,
  cleared_review_suggestion_count integer,
  deleted_cap_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_note text := 'Taxonomy deleted: category removed.';
  v_now timestamptz := now();
  v_affected_count integer := 0;
  v_review_count integer := 0;
  v_mapping_rule_count integer := 0;
  v_merchant_count integer := 0;
  v_review_suggestion_count integer := 0;
  v_cap_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete categories.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to delete taxonomy for this household.';
  end if;

  perform 1
  from public.categories c
  where c.id = p_category_id
    and c.household_id = p_household_id;

  if not found then
    raise exception 'Category not found for this household.';
  end if;

  select count(*)::integer
  into v_affected_count
  from public.transactions t
  where t.household_id = p_household_id
    and (
      t.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = t.subcategory_id
          and sc.household_id = t.household_id
          and sc.category_id = p_category_id
      )
      or exists (
        select 1
        from public.merchant_mapping_rules mmr
        where mmr.id = t.classification_rule_id
          and mmr.household_id = t.household_id
          and (
            mmr.category_id = p_category_id
            or exists (
              select 1
              from public.subcategories sc
              where sc.id = mmr.subcategory_id
                and sc.household_id = mmr.household_id
                and sc.category_id = p_category_id
            )
          )
      )
    );

  insert into public.review_items (
    household_id,
    transaction_id,
    reason,
    suggested_merchant_id,
    suggested_category_id,
    suggested_subcategory_id
  )
  select
    p_household_id,
    t.id,
    v_note,
    t.merchant_id,
    null::uuid,
    null::uuid
  from public.transactions t
  where t.household_id = p_household_id
    and (
      t.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = t.subcategory_id
          and sc.household_id = t.household_id
          and sc.category_id = p_category_id
      )
      or exists (
        select 1
        from public.merchant_mapping_rules mmr
        where mmr.id = t.classification_rule_id
          and mmr.household_id = t.household_id
          and (
            mmr.category_id = p_category_id
            or exists (
              select 1
              from public.subcategories sc
              where sc.id = mmr.subcategory_id
                and sc.household_id = mmr.household_id
                and sc.category_id = p_category_id
            )
          )
      )
    )
  on conflict (household_id, transaction_id, reason)
  where status = 'open' and transaction_id is not null
  do update
    set suggested_merchant_id = excluded.suggested_merchant_id,
        suggested_category_id = null,
        suggested_subcategory_id = null;

  get diagnostics v_review_count = row_count;

  update public.transactions t
  set category_id = null,
      subcategory_id = null,
      classification_rule_id = null,
      classification_updated_by = v_profile_id,
      classification_updated_at = v_now,
      classification_note = v_note
  where t.household_id = p_household_id
    and (
      t.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = t.subcategory_id
          and sc.household_id = t.household_id
          and sc.category_id = p_category_id
      )
      or exists (
        select 1
        from public.merchant_mapping_rules mmr
        where mmr.id = t.classification_rule_id
          and mmr.household_id = t.household_id
          and (
            mmr.category_id = p_category_id
            or exists (
              select 1
              from public.subcategories sc
              where sc.id = mmr.subcategory_id
                and sc.household_id = mmr.household_id
                and sc.category_id = p_category_id
            )
          )
      )
    );

  update public.merchants m
  set category_id = null,
      subcategory_id = null
  where m.household_id = p_household_id
    and (
      m.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = m.subcategory_id
          and sc.household_id = m.household_id
          and sc.category_id = p_category_id
      )
    );

  get diagnostics v_merchant_count = row_count;

  select count(*)::integer
  into v_mapping_rule_count
  from public.merchant_mapping_rules mmr
  where mmr.household_id = p_household_id
    and mmr.apply_to_future
    and (
      mmr.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = mmr.subcategory_id
          and sc.household_id = mmr.household_id
          and sc.category_id = p_category_id
      )
    );

  update public.merchant_mapping_rules mmr
  set category_id = null,
      subcategory_id = null,
      apply_to_future = false,
      notes = case
        when nullif(btrim(mmr.notes), '') is null then v_note
        when position(v_note in mmr.notes) > 0 then mmr.notes
        else mmr.notes || E'\n' || v_note
      end
  where mmr.household_id = p_household_id
    and (
      mmr.category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = mmr.subcategory_id
          and sc.household_id = mmr.household_id
          and sc.category_id = p_category_id
      )
    );

  update public.review_items ri
  set suggested_category_id = null,
      suggested_subcategory_id = null
  where ri.household_id = p_household_id
    and (
      ri.suggested_category_id = p_category_id
      or exists (
        select 1
        from public.subcategories sc
        where sc.id = ri.suggested_subcategory_id
          and sc.household_id = ri.household_id
          and sc.category_id = p_category_id
      )
    );

  get diagnostics v_review_suggestion_count = row_count;

  delete from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.category_id = p_category_id;

  with orphan_caps as (
    select mc.id
    from public.monthly_caps mc
    where mc.household_id = p_household_id
      and not exists (
        select 1
        from public.monthly_cap_categories mcc
        where mcc.household_id = mc.household_id
          and mcc.monthly_cap_id = mc.id
      )
      and not exists (
        select 1
        from public.monthly_cap_labels mcl
        where mcl.household_id = mc.household_id
          and mcl.monthly_cap_id = mc.id
      )
  )
  delete from public.monthly_caps mc
  using orphan_caps
  where mc.id = orphan_caps.id
    and mc.household_id = p_household_id;

  get diagnostics v_cap_count = row_count;

  delete from public.categories c
  where c.id = p_category_id
    and c.household_id = p_household_id;

  deleted_category_id := p_category_id;
  affected_transaction_count := v_affected_count;
  opened_review_item_count := v_review_count;
  deactivated_mapping_rule_count := v_mapping_rule_count;
  cleared_merchant_count := v_merchant_count;
  cleared_review_suggestion_count := v_review_suggestion_count;
  deleted_cap_count := v_cap_count;
  return next;
end;
$$;

create or replace function public.merge_household_categories(
  p_household_id uuid,
  p_destination_category_id uuid,
  p_destination_category_name text,
  p_source_category_ids uuid[],
  p_subcategory_mappings jsonb
)
returns table (
  destination_category_id uuid,
  destination_category_name text,
  changed_transaction_count integer,
  changed_merchant_count integer,
  changed_mapping_rule_count integer,
  changed_review_suggestion_count integer,
  merged_cap_count integer,
  created_subcategory_count integer,
  deleted_category_count integer,
  deleted_subcategory_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_destination_name text;
  v_now timestamptz := now();
  v_note text;
  v_source_category_ids uuid[];
  v_subcategory_mappings jsonb := '[]'::jsonb;
  v_created_mappings jsonb := '[]'::jsonb;
  v_source_count integer := 0;
  v_source_subcategory_count integer := 0;
  v_mapping_count integer := 0;
  v_input_source_count integer := 0;
  v_distinct_source_count integer := 0;
  v_transaction_count integer := 0;
  v_merchant_count integer := 0;
  v_mapping_rule_count integer := 0;
  v_review_suggestion_count integer := 0;
  v_cap_count integer := 0;
  v_created_subcategory_count integer := 0;
  v_deleted_category_count integer := 0;
  v_deleted_subcategory_count integer := 0;
  v_next_sort_order integer := 0;
begin
  v_profile_id := app_private.current_profile_id();
  v_destination_name := nullif(btrim(p_destination_category_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to merge categories.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to merge taxonomy for this household.';
  end if;

  if v_destination_name is null then
    raise exception 'Destination category name is required.';
  end if;

  if p_source_category_ids is null or cardinality(p_source_category_ids) = 0 then
    raise exception 'At least one source category is required.';
  end if;

  if p_subcategory_mappings is null or jsonb_typeof(p_subcategory_mappings) <> 'array' then
    raise exception 'Subcategory mappings must be provided as an array.';
  end if;

  select
    count(*)::integer,
    count(distinct source_id)::integer
  into v_input_source_count, v_distinct_source_count
  from unnest(p_source_category_ids) as source_ids(source_id);

  if v_input_source_count <> v_distinct_source_count then
    raise exception 'A source category can only appear once.';
  end if;

  if exists (
    select 1
    from unnest(p_source_category_ids) as source_ids(source_id)
    where source_ids.source_id is null
  ) then
    raise exception 'Source category ids cannot be blank.';
  end if;

  select array_agg(source_ids.source_id order by source_ids.source_id)
  into v_source_category_ids
  from (
    select distinct source_id
    from unnest(p_source_category_ids) as source_ids(source_id)
  ) source_ids;

  perform 1
  from public.categories c
  where c.id = p_destination_category_id
    and c.household_id = p_household_id;

  if not found then
    raise exception 'Destination category not found for this household.';
  end if;

  if p_destination_category_id = any(v_source_category_ids) then
    raise exception 'Source categories cannot include the destination category.';
  end if;

  select count(*)::integer
  into v_source_count
  from public.categories c
  where c.household_id = p_household_id
    and c.id = any(v_source_category_ids);

  if v_source_count <> cardinality(v_source_category_ids) then
    raise exception 'Source categories must belong to the same household.';
  end if;

  if exists (
    select 1
    from public.categories c
    where c.household_id = p_household_id
      and c.id <> p_destination_category_id
      and c.id <> all(v_source_category_ids)
      and lower(c.name) = lower(v_destination_name)
  ) then
    raise exception 'A category with this name already exists.';
  end if;

  select count(*)::integer
  into v_source_subcategory_count
  from public.subcategories sc
  where sc.household_id = p_household_id
    and sc.category_id = any(v_source_category_ids);

  if exists (
    select 1
    from jsonb_array_elements(p_subcategory_mappings) as payload(element)
    where jsonb_typeof(payload.element) <> 'object'
  ) then
    raise exception 'Each subcategory mapping must be an object.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
          as source_subcategory_id,
        nullif(btrim(entry.element ->> 'destination_subcategory_id'), '')::uuid
          as destination_subcategory_id,
        nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
          as destination_subcategory_name
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    where raw_mappings.source_subcategory_id is null
  ) then
    raise exception 'Every subcategory mapping needs a source subcategory.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
          as source_subcategory_id,
        nullif(btrim(entry.element ->> 'destination_subcategory_id'), '')::uuid
          as destination_subcategory_id,
        nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
          as destination_subcategory_name
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    where (
      raw_mappings.destination_subcategory_id is null
      and raw_mappings.destination_subcategory_name is null
    )
    or (
      raw_mappings.destination_subcategory_id is not null
      and raw_mappings.destination_subcategory_name is not null
    )
  ) then
    raise exception 'Each source subcategory must map to exactly one destination.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
          as source_subcategory_id
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    group by raw_mappings.source_subcategory_id
    having count(*) > 1
  ) then
    raise exception 'Each source subcategory must be mapped exactly once.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
          as source_subcategory_id
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    where not exists (
      select 1
      from public.subcategories sc
      where sc.id = raw_mappings.source_subcategory_id
        and sc.household_id = p_household_id
        and sc.category_id = any(v_source_category_ids)
    )
  ) then
    raise exception 'Mappings can only reference source subcategories.';
  end if;

  if exists (
    select 1
    from public.subcategories sc
    where sc.household_id = p_household_id
      and sc.category_id = any(v_source_category_ids)
      and not exists (
        with raw_mappings as (
          select
            nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
              as source_subcategory_id
          from jsonb_array_elements(p_subcategory_mappings) as entry(element)
        )
        select 1
        from raw_mappings
        where raw_mappings.source_subcategory_id = sc.id
      )
  ) then
    raise exception 'Every source subcategory must be mapped.';
  end if;

  with raw_mappings as (
    select
      nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
        as source_subcategory_id
    from jsonb_array_elements(p_subcategory_mappings) as entry(element)
  )
  select count(*)::integer
  into v_mapping_count
  from raw_mappings;

  if v_mapping_count <> v_source_subcategory_count then
    raise exception 'Every source subcategory must be mapped.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'destination_subcategory_id'), '')::uuid
          as destination_subcategory_id
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    where raw_mappings.destination_subcategory_id is not null
      and not exists (
        select 1
        from public.subcategories sc
        where sc.id = raw_mappings.destination_subcategory_id
          and sc.category_id = p_destination_category_id
          and sc.household_id = p_household_id
      )
  ) then
    raise exception 'Destination subcategory not found for the surviving category.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
          as destination_subcategory_name
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    where raw_mappings.destination_subcategory_name is not null
    group by lower(raw_mappings.destination_subcategory_name)
    having count(*) > 1
  ) then
    raise exception 'Duplicate destination subcategory names are not allowed.';
  end if;

  if exists (
    with raw_mappings as (
      select
        nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
          as destination_subcategory_name
      from jsonb_array_elements(p_subcategory_mappings) as entry(element)
    )
    select 1
    from raw_mappings
    join public.subcategories sc
      on sc.category_id = p_destination_category_id
      and sc.household_id = p_household_id
      and lower(sc.name) = lower(raw_mappings.destination_subcategory_name)
    where raw_mappings.destination_subcategory_name is not null
  ) then
    raise exception 'Duplicate destination subcategory names are not allowed.';
  end if;

  select coalesce(max(sc.sort_order), 0)
  into v_next_sort_order
  from public.subcategories sc
  where sc.household_id = p_household_id
    and sc.category_id = p_destination_category_id;

  with raw_mappings as (
    select
      nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
        as source_subcategory_id,
      nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
        as destination_subcategory_name
    from jsonb_array_elements(p_subcategory_mappings) as entry(element)
  )
  select count(*)::integer
  into v_created_subcategory_count
  from raw_mappings
  where raw_mappings.destination_subcategory_name is not null;

  with raw_mappings as (
    select
      nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
        as source_subcategory_id,
      nullif(btrim(entry.element ->> 'destination_subcategory_name'), '')
        as destination_subcategory_name
    from jsonb_array_elements(p_subcategory_mappings) as entry(element)
  ),
  ordered_new as (
    select
      raw_mappings.source_subcategory_id,
      raw_mappings.destination_subcategory_name,
      row_number() over (
        order by lower(raw_mappings.destination_subcategory_name),
          raw_mappings.source_subcategory_id
      ) as new_sort_offset
    from raw_mappings
    where raw_mappings.destination_subcategory_name is not null
  ),
  inserted as (
    insert into public.subcategories (
      household_id,
      category_id,
      name,
      sort_order
    )
    select
      p_household_id,
      p_destination_category_id,
      ordered_new.destination_subcategory_name,
      v_next_sort_order + ordered_new.new_sort_offset
    from ordered_new
    returning id, name
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'source_subcategory_id', ordered_new.source_subcategory_id,
        'destination_subcategory_id', inserted.id
      )
    ),
    '[]'::jsonb
  )
  into v_created_mappings
  from ordered_new
  join inserted
    on lower(inserted.name) = lower(ordered_new.destination_subcategory_name);

  with raw_mappings as (
    select
      nullif(btrim(entry.element ->> 'source_subcategory_id'), '')::uuid
        as source_subcategory_id,
      nullif(btrim(entry.element ->> 'destination_subcategory_id'), '')::uuid
        as destination_subcategory_id
    from jsonb_array_elements(p_subcategory_mappings) as entry(element)
  ),
  created_mappings as (
    select
      (entry.element ->> 'source_subcategory_id')::uuid
        as source_subcategory_id,
      (entry.element ->> 'destination_subcategory_id')::uuid
        as destination_subcategory_id
    from jsonb_array_elements(v_created_mappings) as entry(element)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'source_subcategory_id', raw_mappings.source_subcategory_id,
        'destination_subcategory_id',
          coalesce(
            raw_mappings.destination_subcategory_id,
            created_mappings.destination_subcategory_id
          )
      )
    ),
    '[]'::jsonb
  )
  into v_subcategory_mappings
  from raw_mappings
  left join created_mappings
    on created_mappings.source_subcategory_id =
      raw_mappings.source_subcategory_id;

  if exists (
    select 1
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
    where mappings.element ->> 'destination_subcategory_id' is null
  ) then
    raise exception 'Every source subcategory must map to a destination subcategory.';
  end if;

  v_note := 'Taxonomy merged into category: ' || v_destination_name || '.';

  update public.transactions t
  set category_id = p_destination_category_id,
      subcategory_id = case
        when t.subcategory_id is null then null
        else (
          select (mappings.element ->> 'destination_subcategory_id')::uuid
          from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
          where (mappings.element ->> 'source_subcategory_id')::uuid =
            t.subcategory_id
        )
      end,
      classification_updated_by = v_profile_id,
      classification_updated_at = v_now,
      classification_note = v_note
  where t.household_id = p_household_id
    and t.category_id = any(v_source_category_ids);

  get diagnostics v_transaction_count = row_count;

  update public.merchants m
  set category_id = p_destination_category_id,
      subcategory_id = case
        when m.subcategory_id is null then null
        else (
          select (mappings.element ->> 'destination_subcategory_id')::uuid
          from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
          where (mappings.element ->> 'source_subcategory_id')::uuid =
            m.subcategory_id
        )
      end
  where m.household_id = p_household_id
    and m.category_id = any(v_source_category_ids);

  get diagnostics v_merchant_count = row_count;

  update public.merchant_mapping_rules mmr
  set category_id = p_destination_category_id,
      subcategory_id = case
        when mmr.subcategory_id is null then null
        else (
          select (mappings.element ->> 'destination_subcategory_id')::uuid
          from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
          where (mappings.element ->> 'source_subcategory_id')::uuid =
            mmr.subcategory_id
        )
      end
  where mmr.household_id = p_household_id
    and mmr.category_id = any(v_source_category_ids);

  get diagnostics v_mapping_rule_count = row_count;

  update public.review_items ri
  set suggested_category_id = p_destination_category_id,
      suggested_subcategory_id = case
        when ri.suggested_subcategory_id is null then null
        else (
          select (mappings.element ->> 'destination_subcategory_id')::uuid
          from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
          where (mappings.element ->> 'source_subcategory_id')::uuid =
            ri.suggested_subcategory_id
        )
      end
  where ri.household_id = p_household_id
    and ri.suggested_category_id = any(v_source_category_ids);

  get diagnostics v_review_suggestion_count = row_count;

  select count(*)::integer
  into v_cap_count
  from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.category_id = any(v_source_category_ids);

  insert into public.monthly_cap_categories (
    household_id,
    monthly_cap_id,
    category_id
  )
  select distinct
    mcc.household_id,
    mcc.monthly_cap_id,
    p_destination_category_id
  from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.category_id = any(v_source_category_ids)
  on conflict on constraint monthly_cap_categories_pkey do nothing;

  delete from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.category_id = any(v_source_category_ids);

  delete from public.subcategories sc
  where sc.household_id = p_household_id
    and sc.category_id = any(v_source_category_ids);

  get diagnostics v_deleted_subcategory_count = row_count;

  delete from public.categories c
  where c.household_id = p_household_id
    and c.id = any(v_source_category_ids);

  get diagnostics v_deleted_category_count = row_count;

  update public.categories c
  set name = v_destination_name
  where c.id = p_destination_category_id
    and c.household_id = p_household_id;

  destination_category_id := p_destination_category_id;
  destination_category_name := v_destination_name;
  changed_transaction_count := v_transaction_count;
  changed_merchant_count := v_merchant_count;
  changed_mapping_rule_count := v_mapping_rule_count;
  changed_review_suggestion_count := v_review_suggestion_count;
  merged_cap_count := v_cap_count;
  created_subcategory_count := v_created_subcategory_count;
  deleted_category_count := v_deleted_category_count;
  deleted_subcategory_count := v_deleted_subcategory_count;
  return next;
exception
  when invalid_text_representation then
    raise exception 'Subcategory mappings contain invalid ids.';
  when unique_violation then
    raise exception 'Category or subcategory already exists.';
end;
$$;

create or replace function public.delete_household_label(
  p_household_id uuid,
  p_label_id uuid
)
returns table (
  label_id uuid,
  detached_transaction_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_detached_transaction_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete labels.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to delete labels for this household.';
  end if;

  perform 1
  from public.labels l
  where l.id = p_label_id
    and l.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Label not found for this household.';
  end if;

  select count(distinct tl.transaction_id)::integer
  into v_detached_transaction_count
  from public.transaction_labels tl
  where tl.household_id = p_household_id
    and tl.label_id = p_label_id;

  delete from public.monthly_cap_labels mcl
  where mcl.household_id = p_household_id
    and mcl.label_id = p_label_id;

  with orphan_caps as (
    select mc.id
    from public.monthly_caps mc
    where mc.household_id = p_household_id
      and not exists (
        select 1
        from public.monthly_cap_categories mcc
        where mcc.household_id = mc.household_id
          and mcc.monthly_cap_id = mc.id
      )
      and not exists (
        select 1
        from public.monthly_cap_labels mcl
        where mcl.household_id = mc.household_id
          and mcl.monthly_cap_id = mc.id
      )
  )
  delete from public.monthly_caps mc
  using orphan_caps
  where mc.id = orphan_caps.id
    and mc.household_id = p_household_id;

  delete from public.transaction_labels tl
  where tl.household_id = p_household_id
    and tl.label_id = p_label_id;

  delete from public.labels l
  where l.id = p_label_id
    and l.household_id = p_household_id;

  label_id := p_label_id;
  detached_transaction_count := v_detached_transaction_count;
  return next;
end;
$$;

revoke all privileges on public.monthly_caps
  from public, anon, authenticated, service_role;
revoke all privileges on public.monthly_cap_categories
  from public, anon, authenticated, service_role;
revoke all privileges on public.monthly_cap_labels
  from public, anon, authenticated, service_role;
revoke all privileges on public.v_monthly_cap_progress
  from public, anon, authenticated, service_role;
revoke execute on function public.upsert_monthly_cap(
  uuid,
  uuid,
  text,
  date,
  numeric,
  uuid[],
  uuid[]
) from public, anon, authenticated, service_role;
revoke execute on function public.delete_monthly_cap(uuid, uuid)
  from public, anon, authenticated, service_role;

grant select, insert, update, delete on public.monthly_caps to authenticated;
grant select, insert, update, delete on public.monthly_cap_categories
  to authenticated;
grant select, insert, update, delete on public.monthly_cap_labels
  to authenticated;
grant select on public.v_monthly_cap_progress to authenticated;
grant execute on function public.upsert_monthly_cap(
  uuid,
  uuid,
  text,
  date,
  numeric,
  uuid[],
  uuid[]
) to authenticated;
grant execute on function public.delete_monthly_cap(uuid, uuid)
  to authenticated;
