create table public.monthly_cap_series (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null,
  stopped_from_month date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint monthly_cap_series_stopped_month_first_day check (
    stopped_from_month is null
    or stopped_from_month = date_trunc('month', stopped_from_month)::date
  )
);

create table public.monthly_cap_versions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  monthly_cap_series_id uuid not null,
  effective_month date not null,
  name text not null,
  base_amount numeric(14,2) not null,
  carry_forward_enabled boolean not null default false,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint monthly_cap_versions_series_household_fk
    foreign key (monthly_cap_series_id, household_id)
    references public.monthly_cap_series (id, household_id) on delete cascade,
  constraint monthly_cap_versions_series_month_key
    unique (monthly_cap_series_id, effective_month),
  constraint monthly_cap_versions_name_trimmed_nonempty check (
    btrim(name) <> ''
    and name = btrim(name)
  ),
  constraint monthly_cap_versions_effective_month_first_day check (
    effective_month = date_trunc('month', effective_month)::date
  ),
  constraint monthly_cap_versions_base_amount_nonnegative check (
    base_amount >= 0
  )
);

create table public.monthly_cap_version_categories (
  household_id uuid not null references public.households (id) on delete cascade,
  monthly_cap_version_id uuid not null,
  category_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (monthly_cap_version_id, category_id),
  constraint monthly_cap_version_categories_version_household_fk
    foreign key (monthly_cap_version_id, household_id)
    references public.monthly_cap_versions (id, household_id) on delete cascade,
  constraint monthly_cap_version_categories_category_household_fk
    foreign key (category_id, household_id)
    references public.categories (id, household_id) on delete cascade
);

create table public.monthly_cap_version_labels (
  household_id uuid not null references public.households (id) on delete cascade,
  monthly_cap_version_id uuid not null,
  label_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (monthly_cap_version_id, label_id),
  constraint monthly_cap_version_labels_version_household_fk
    foreign key (monthly_cap_version_id, household_id)
    references public.monthly_cap_versions (id, household_id) on delete cascade,
  constraint monthly_cap_version_labels_label_household_fk
    foreign key (label_id, household_id)
    references public.labels (id, household_id) on delete cascade
);

create index monthly_cap_series_household_idx
  on public.monthly_cap_series (household_id);
create index monthly_cap_series_household_stop_idx
  on public.monthly_cap_series (household_id, stopped_from_month);
create index monthly_cap_versions_series_effective_idx
  on public.monthly_cap_versions (
    household_id,
    monthly_cap_series_id,
    effective_month desc
  );
create index monthly_cap_versions_household_effective_idx
  on public.monthly_cap_versions (household_id, effective_month);
create index monthly_cap_version_categories_household_category_idx
  on public.monthly_cap_version_categories (household_id, category_id);
create index monthly_cap_version_labels_household_label_idx
  on public.monthly_cap_version_labels (household_id, label_id);

create trigger set_monthly_cap_series_updated_at
  before update on public.monthly_cap_series
  for each row execute function app_private.set_updated_at();

create trigger set_monthly_cap_versions_updated_at
  before update on public.monthly_cap_versions
  for each row execute function app_private.set_updated_at();

alter table public.monthly_cap_series enable row level security;
alter table public.monthly_cap_versions enable row level security;
alter table public.monthly_cap_version_categories enable row level security;
alter table public.monthly_cap_version_labels enable row level security;

create policy "monthly_cap_series_select_members"
  on public.monthly_cap_series
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_series_insert_writers"
  on public.monthly_cap_series
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "monthly_cap_series_update_writers"
  on public.monthly_cap_series
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_series_delete_writers"
  on public.monthly_cap_series
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "monthly_cap_versions_select_members"
  on public.monthly_cap_versions
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_versions_insert_writers"
  on public.monthly_cap_versions
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "monthly_cap_versions_update_writers"
  on public.monthly_cap_versions
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_versions_delete_writers"
  on public.monthly_cap_versions
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "monthly_cap_version_categories_select_members"
  on public.monthly_cap_version_categories
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_version_categories_insert_writers"
  on public.monthly_cap_version_categories
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_version_categories_update_writers"
  on public.monthly_cap_version_categories
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_version_categories_delete_writers"
  on public.monthly_cap_version_categories
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "monthly_cap_version_labels_select_members"
  on public.monthly_cap_version_labels
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "monthly_cap_version_labels_insert_writers"
  on public.monthly_cap_version_labels
  for insert
  to authenticated
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_version_labels_update_writers"
  on public.monthly_cap_version_labels
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "monthly_cap_version_labels_delete_writers"
  on public.monthly_cap_version_labels
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

insert into public.monthly_cap_series (
  id,
  household_id,
  created_by,
  created_at,
  updated_at
)
select
  mc.id,
  mc.household_id,
  mc.created_by,
  mc.created_at,
  mc.updated_at
from public.monthly_caps mc;

insert into public.monthly_cap_versions (
  household_id,
  monthly_cap_series_id,
  effective_month,
  name,
  base_amount,
  carry_forward_enabled,
  created_by,
  created_at,
  updated_at
)
select
  mc.household_id,
  mc.id,
  mc.period_month,
  mc.name,
  mc.cap_amount,
  false,
  mc.created_by,
  mc.created_at,
  mc.updated_at
from public.monthly_caps mc;

insert into public.monthly_cap_version_categories (
  household_id,
  monthly_cap_version_id,
  category_id,
  created_at
)
select
  mcc.household_id,
  mcv.id,
  mcc.category_id,
  mcc.created_at
from public.monthly_cap_categories mcc
join public.monthly_cap_versions mcv
  on mcv.household_id = mcc.household_id
  and mcv.monthly_cap_series_id = mcc.monthly_cap_id;

insert into public.monthly_cap_version_labels (
  household_id,
  monthly_cap_version_id,
  label_id,
  created_at
)
select
  mcl.household_id,
  mcv.id,
  mcl.label_id,
  mcl.created_at
from public.monthly_cap_labels mcl
join public.monthly_cap_versions mcv
  on mcv.household_id = mcl.household_id
  and mcv.monthly_cap_series_id = mcl.monthly_cap_id;

drop function public.upsert_monthly_cap(
  uuid,
  uuid,
  text,
  date,
  numeric,
  uuid[],
  uuid[]
);

create function public.upsert_monthly_cap(
  p_household_id uuid,
  p_monthly_cap_id uuid default null,
  p_name text default null,
  p_period_month date default null,
  p_cap_amount numeric default null,
  p_category_ids uuid[] default '{}',
  p_label_ids uuid[] default '{}',
  p_carry_forward_enabled boolean default false
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
  v_series_id uuid;
  v_version_id uuid;
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
    insert into public.monthly_cap_series (
      household_id,
      created_by
    )
    values (
      p_household_id,
      v_profile_id
    )
    returning id into v_series_id;
  else
    select mcs.id
    into v_series_id
    from public.monthly_cap_series mcs
    where mcs.id = p_monthly_cap_id
      and mcs.household_id = p_household_id
    for update;

    if not found then
      raise exception 'Monthly cap not found for this household.';
    end if;

    if exists (
      select 1
      from public.monthly_cap_series mcs
      where mcs.id = p_monthly_cap_id
        and mcs.household_id = p_household_id
        and mcs.stopped_from_month is not null
        and v_period_month >= mcs.stopped_from_month
    ) then
      raise exception 'Monthly cap is stopped for this month.';
    end if;
  end if;

  insert into public.monthly_cap_versions (
    household_id,
    monthly_cap_series_id,
    effective_month,
    name,
    base_amount,
    carry_forward_enabled,
    created_by
  )
  values (
    p_household_id,
    v_series_id,
    v_period_month,
    v_name,
    v_cap_amount,
    coalesce(p_carry_forward_enabled, false),
    v_profile_id
  )
  on conflict on constraint monthly_cap_versions_series_month_key
  do update
  set name = excluded.name,
      base_amount = excluded.base_amount,
      carry_forward_enabled = excluded.carry_forward_enabled,
      created_by = excluded.created_by
  returning id into v_version_id;

  delete from public.monthly_cap_version_categories mvc
  where mvc.household_id = p_household_id
    and mvc.monthly_cap_version_id = v_version_id;

  delete from public.monthly_cap_version_labels mvl
  where mvl.household_id = p_household_id
    and mvl.monthly_cap_version_id = v_version_id;

  insert into public.monthly_cap_version_categories (
    household_id,
    monthly_cap_version_id,
    category_id
  )
  select
    p_household_id,
    v_version_id,
    category_targets.category_id
  from unnest(v_category_ids) as category_targets(category_id)
  on conflict on constraint monthly_cap_version_categories_pkey do nothing;

  insert into public.monthly_cap_version_labels (
    household_id,
    monthly_cap_version_id,
    label_id
  )
  select
    p_household_id,
    v_version_id,
    label_targets.label_id
  from unnest(v_label_ids) as label_targets(label_id)
  on conflict on constraint monthly_cap_version_labels_pkey do nothing;

  perform set_config('app.skip_monthly_cap_legacy_target_sync', 'on', true);

  insert into public.monthly_caps (
    id,
    household_id,
    name,
    period_month,
    cap_amount,
    created_by
  )
  values (
    v_series_id,
    p_household_id,
    v_name,
    v_period_month,
    v_cap_amount,
    v_profile_id
  )
  on conflict (id) do update
  set name = excluded.name,
      period_month = excluded.period_month,
      cap_amount = excluded.cap_amount,
      created_by = excluded.created_by;

  delete from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.monthly_cap_id = v_series_id;

  delete from public.monthly_cap_labels mcl
  where mcl.household_id = p_household_id
    and mcl.monthly_cap_id = v_series_id;

  insert into public.monthly_cap_categories (
    household_id,
    monthly_cap_id,
    category_id
  )
  select
    p_household_id,
    v_series_id,
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
    v_series_id,
    label_targets.label_id
  from unnest(v_label_ids) as label_targets(label_id)
  on conflict on constraint monthly_cap_labels_pkey do nothing;

  perform set_config('app.skip_monthly_cap_legacy_target_sync', 'off', true);

  return query
  select
    mcs.id,
    mcv.id,
    mcs.household_id,
    mcv.name,
    mcv.effective_month,
    mcv.base_amount,
    mcv.base_amount,
    mcv.carry_forward_enabled,
    0::numeric(14,2),
    mcv.base_amount,
    mcv.created_by,
    mcv.created_at,
    mcv.updated_at,
    coalesce(category_targets.category_target_ids, '{}'::uuid[]),
    coalesce(category_targets.category_target_names, '{}'::text[]),
    coalesce(label_targets.label_target_ids, '{}'::uuid[]),
    coalesce(label_targets.label_target_names, '{}'::text[])
  from public.monthly_cap_series mcs
  join public.monthly_cap_versions mcv
    on mcv.monthly_cap_series_id = mcs.id
    and mcv.household_id = mcs.household_id
  left join lateral (
    select
      array_agg(c.id order by lower(c.name), c.name, c.id)
        as category_target_ids,
      array_agg(c.name order by lower(c.name), c.name, c.id)
        as category_target_names
    from public.monthly_cap_version_categories mvc
    join public.categories c
      on c.id = mvc.category_id
      and c.household_id = mvc.household_id
    where mvc.household_id = mcv.household_id
      and mvc.monthly_cap_version_id = mcv.id
  ) category_targets on true
  left join lateral (
    select
      array_agg(l.id order by lower(l.name), l.name, l.id)
        as label_target_ids,
      array_agg(l.name order by lower(l.name), l.name, l.id)
        as label_target_names
    from public.monthly_cap_version_labels mvl
    join public.labels l
      on l.id = mvl.label_id
      and l.household_id = mvl.household_id
    where mvl.household_id = mcv.household_id
      and mvl.monthly_cap_version_id = mcv.id
  ) label_targets on true
  where mcs.id = v_series_id
    and mcs.household_id = p_household_id
    and mcv.id = v_version_id;
exception
  when unique_violation then
    raise exception 'A monthly cap with this name already exists for this month.';
end;
$$;

drop function public.delete_monthly_cap(uuid, uuid);

create function public.delete_monthly_cap(
  p_household_id uuid,
  p_monthly_cap_id uuid,
  p_period_month date default null
)
returns table (
  monthly_cap_id uuid,
  stopped_from_month date
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

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete monthly caps.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to delete monthly caps for this household.';
  end if;

  select coalesce(
    p_period_month,
    (
      select mc.period_month
      from public.monthly_caps mc
      where mc.id = p_monthly_cap_id
        and mc.household_id = p_household_id
    ),
    (
      select max(mcv.effective_month)
      from public.monthly_cap_versions mcv
      where mcv.monthly_cap_series_id = p_monthly_cap_id
        and mcv.household_id = p_household_id
    )
  )
  into v_period_month;

  if v_period_month is null
      or v_period_month <> date_trunc('month', v_period_month)::date then
    raise exception 'Monthly cap period must be the first day of the month.';
  end if;

  perform 1
  from public.monthly_cap_series mcs
  where mcs.id = p_monthly_cap_id
    and mcs.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Monthly cap not found for this household.';
  end if;

  update public.monthly_cap_series mcs
  set stopped_from_month = v_period_month
  where mcs.id = p_monthly_cap_id
    and mcs.household_id = p_household_id;

  perform set_config('app.skip_monthly_cap_legacy_target_sync', 'on', true);

  delete from public.monthly_caps mc
  where mc.id = p_monthly_cap_id
    and mc.household_id = p_household_id;

  perform set_config('app.skip_monthly_cap_legacy_target_sync', 'off', true);

  monthly_cap_id := p_monthly_cap_id;
  stopped_from_month := v_period_month;
  return next;
end;
$$;

drop view public.v_budget_progress;
drop view public.v_monthly_cap_progress;

create view public.v_monthly_cap_progress
with (security_invoker = true)
as
with recurring_caps as (
  select
    mcs.id as monthly_cap_id,
    mcv.id as monthly_cap_version_id,
    mcs.household_id,
    mcv.name,
    mcv.effective_month as period_month,
    mcv.base_amount,
    mcv.carry_forward_enabled
  from public.monthly_cap_series mcs
  join public.monthly_cap_versions mcv
    on mcv.household_id = mcs.household_id
    and mcv.monthly_cap_series_id = mcs.id
  where mcs.stopped_from_month is null
    or mcv.effective_month < mcs.stopped_from_month
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
cap_versions as (
  select * from recurring_caps
  union all
  select * from legacy_caps
),
category_targets as (
  select
    target_rows.household_id,
    target_rows.monthly_cap_id,
    target_rows.monthly_cap_version_id,
    array_agg(c.id order by lower(c.name), c.name, c.id) as category_target_ids,
    array_agg(c.name order by lower(c.name), c.name, c.id)
      as category_target_names
  from (
    select
      mcv.household_id,
      mcv.monthly_cap_series_id as monthly_cap_id,
      mvc.monthly_cap_version_id,
      mvc.category_id
    from public.monthly_cap_version_categories mvc
    join public.monthly_cap_versions mcv
      on mcv.id = mvc.monthly_cap_version_id
      and mcv.household_id = mvc.household_id
    union all
    select
      mcc.household_id,
      mcc.monthly_cap_id,
      null::uuid,
      mcc.category_id
    from public.monthly_cap_categories mcc
    where not exists (
      select 1
      from public.monthly_cap_series mcs
      where mcs.id = mcc.monthly_cap_id
        and mcs.household_id = mcc.household_id
    )
  ) target_rows
  join public.categories c
    on c.id = target_rows.category_id
    and c.household_id = target_rows.household_id
  group by
    target_rows.household_id,
    target_rows.monthly_cap_id,
    target_rows.monthly_cap_version_id
),
label_targets as (
  select
    target_rows.household_id,
    target_rows.monthly_cap_id,
    target_rows.monthly_cap_version_id,
    array_agg(l.id order by lower(l.name), l.name, l.id) as label_target_ids,
    array_agg(l.name order by lower(l.name), l.name, l.id)
      as label_target_names
  from (
    select
      mcv.household_id,
      mcv.monthly_cap_series_id as monthly_cap_id,
      mvl.monthly_cap_version_id,
      mvl.label_id
    from public.monthly_cap_version_labels mvl
    join public.monthly_cap_versions mcv
      on mcv.id = mvl.monthly_cap_version_id
      and mcv.household_id = mvl.household_id
    union all
    select
      mcl.household_id,
      mcl.monthly_cap_id,
      null::uuid,
      mcl.label_id
    from public.monthly_cap_labels mcl
    where not exists (
      select 1
      from public.monthly_cap_series mcs
      where mcs.id = mcl.monthly_cap_id
        and mcs.household_id = mcl.household_id
    )
  ) target_rows
  join public.labels l
    on l.id = target_rows.label_id
    and l.household_id = target_rows.household_id
  group by
    target_rows.household_id,
    target_rows.monthly_cap_id,
    target_rows.monthly_cap_version_id
),
matched_transactions as (
  select
    cv.monthly_cap_id,
    cv.monthly_cap_version_id,
    t.id as transaction_id,
    t.net_expense
  from cap_versions cv
  join public.transactions t
    on t.household_id = cv.household_id
    and t.transaction_date >= cv.period_month
    and t.transaction_date < (cv.period_month + interval '1 month')::date
    and (
      exists (
        select 1
        from public.monthly_cap_version_categories mvc
        join public.monthly_cap_versions mcv
          on mcv.id = mvc.monthly_cap_version_id
          and mcv.household_id = mvc.household_id
        where mcv.monthly_cap_series_id = cv.monthly_cap_id
          and mvc.monthly_cap_version_id = cv.monthly_cap_version_id
          and mvc.category_id = t.category_id
      )
      or exists (
        select 1
        from public.monthly_cap_version_labels mvl
        join public.monthly_cap_versions mcv
          on mcv.id = mvl.monthly_cap_version_id
          and mcv.household_id = mvl.household_id
        join public.transaction_labels tl
          on tl.household_id = mvl.household_id
          and tl.label_id = mvl.label_id
          and tl.transaction_id = t.id
        where mcv.monthly_cap_series_id = cv.monthly_cap_id
          and mvl.monthly_cap_version_id = cv.monthly_cap_version_id
      )
      or (
        cv.monthly_cap_version_id is null
        and exists (
          select 1
          from public.monthly_cap_categories mcc
          where mcc.household_id = cv.household_id
            and mcc.monthly_cap_id = cv.monthly_cap_id
            and mcc.category_id = t.category_id
        )
      )
      or (
        cv.monthly_cap_version_id is null
        and exists (
          select 1
          from public.monthly_cap_labels mcl
          join public.transaction_labels tl
            on tl.household_id = mcl.household_id
            and tl.label_id = mcl.label_id
            and tl.transaction_id = t.id
          where mcl.household_id = cv.household_id
            and mcl.monthly_cap_id = cv.monthly_cap_id
        )
      )
    )
),
progress as (
  select
    matched_transactions.monthly_cap_id,
    matched_transactions.monthly_cap_version_id,
    count(distinct matched_transactions.transaction_id)::integer
      as matched_transaction_count,
    coalesce(sum(matched_transactions.net_expense), 0)::numeric(14,2)
      as spent_amount
  from matched_transactions
  group by
    matched_transactions.monthly_cap_id,
    matched_transactions.monthly_cap_version_id
)
select
  cv.monthly_cap_id,
  cv.monthly_cap_version_id,
  cv.household_id,
  cv.name,
  cv.period_month,
  cv.base_amount as cap_amount,
  cv.base_amount as base_cap_amount,
  cv.carry_forward_enabled,
  0::numeric(14,2) as carry_forward_amount,
  cv.base_amount as effective_cap_amount,
  coalesce(progress.spent_amount, 0)::numeric(14,2) as spent_amount,
  (cv.base_amount - coalesce(progress.spent_amount, 0))::numeric(14,2)
    as remaining_amount,
  case
    when cv.base_amount > 0 then
      round(coalesce(progress.spent_amount, 0) / cv.base_amount, 4)
    else null
  end as percent_used,
  coalesce(progress.spent_amount, 0) > cv.base_amount as is_over_budget,
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
from cap_versions cv
left join progress
  on progress.monthly_cap_id = cv.monthly_cap_id
  and progress.monthly_cap_version_id is not distinct from
    cv.monthly_cap_version_id
left join category_targets
  on category_targets.household_id = cv.household_id
  and category_targets.monthly_cap_id = cv.monthly_cap_id
  and category_targets.monthly_cap_version_id is not distinct from
    cv.monthly_cap_version_id
left join label_targets
  on label_targets.household_id = cv.household_id
  and label_targets.monthly_cap_id = cv.monthly_cap_id
  and label_targets.monthly_cap_version_id is not distinct from
    cv.monthly_cap_version_id;

create view public.v_budget_progress
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
where mcp.monthly_cap_version_id is null
  and cardinality(mcp.category_target_ids) = 1
  and cardinality(mcp.label_target_ids) = 0
union all
select
  mcp.household_id,
  mcp.period_month,
  mvc.category_id,
  c.name as category_name,
  mcp.cap_amount,
  mcp.spent_amount,
  mcp.remaining_amount,
  mcp.percent_used,
  mcp.is_over_budget
from public.v_monthly_cap_progress mcp
join public.monthly_cap_version_categories mvc
  on mvc.monthly_cap_version_id = mcp.monthly_cap_version_id
  and mvc.household_id = mcp.household_id
join public.categories c
  on c.id = mvc.category_id
  and c.household_id = mvc.household_id
where mcp.monthly_cap_version_id is not null
  and cardinality(mcp.category_target_ids) = 1
  and cardinality(mcp.label_target_ids) = 0;

create function public.get_monthly_cap_progress(
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
  with active_versions as (
    select
      mcs.id as monthly_cap_id,
      mcv.id as monthly_cap_version_id,
      mcs.household_id,
      mcv.name,
      v_period_month as period_month,
      mcv.base_amount,
      mcv.carry_forward_enabled
    from public.monthly_cap_series mcs
    join lateral (
      select version_rows.*
      from public.monthly_cap_versions version_rows
      where version_rows.household_id = mcs.household_id
        and version_rows.monthly_cap_series_id = mcs.id
        and version_rows.effective_month <= v_period_month
      order by version_rows.effective_month desc, version_rows.created_at desc
      limit 1
    ) mcv on true
    where mcs.household_id = p_household_id
      and (
        mcs.stopped_from_month is null
        or v_period_month < mcs.stopped_from_month
      )
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
    join public.categories c
      on c.id = mvc.category_id
      and c.household_id = mvc.household_id
    join active_versions av
      on av.monthly_cap_version_id = mvc.monthly_cap_version_id
      and av.household_id = mvc.household_id
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
    join public.labels l
      on l.id = mvl.label_id
      and l.household_id = mvl.household_id
    join active_versions av
      on av.monthly_cap_version_id = mvl.monthly_cap_version_id
      and av.household_id = mvl.household_id
    group by mvl.household_id, mvl.monthly_cap_version_id
  ),
  matched_transactions as (
    select
      av.monthly_cap_id,
      av.monthly_cap_version_id,
      t.id as transaction_id,
      t.net_expense
    from active_versions av
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
  ),
  progress as (
    select
      matched_transactions.monthly_cap_id,
      matched_transactions.monthly_cap_version_id,
      count(distinct matched_transactions.transaction_id)::integer
        as matched_transaction_count,
      coalesce(sum(matched_transactions.net_expense), 0)::numeric(14,2)
        as spent_amount
    from matched_transactions
    group by
      matched_transactions.monthly_cap_id,
      matched_transactions.monthly_cap_version_id
  )
  select
    av.monthly_cap_id,
    av.monthly_cap_version_id,
    av.household_id,
    av.name,
    av.period_month,
    av.base_amount,
    av.base_amount,
    av.carry_forward_enabled,
    0::numeric(14,2),
    av.base_amount,
    coalesce(progress.spent_amount, 0)::numeric(14,2),
    (av.base_amount - coalesce(progress.spent_amount, 0))::numeric(14,2),
    case
      when av.base_amount > 0 then
        round(coalesce(progress.spent_amount, 0) / av.base_amount, 4)
      else null
    end,
    coalesce(progress.spent_amount, 0) > av.base_amount,
    coalesce(progress.matched_transaction_count, 0)::integer,
    coalesce(category_targets.category_target_ids, '{}'::uuid[]),
    coalesce(category_targets.category_target_names, '{}'::text[]),
    coalesce(label_targets.label_target_ids, '{}'::uuid[]),
    coalesce(label_targets.label_target_names, '{}'::text[])
  from active_versions av
  left join progress
    on progress.monthly_cap_id = av.monthly_cap_id
    and progress.monthly_cap_version_id = av.monthly_cap_version_id
  left join category_targets
    on category_targets.household_id = av.household_id
    and category_targets.monthly_cap_version_id = av.monthly_cap_version_id
  left join label_targets
    on label_targets.household_id = av.household_id
    and label_targets.monthly_cap_version_id = av.monthly_cap_version_id
  order by
    case
      when av.base_amount > 0 then
        coalesce(progress.spent_amount, 0) / av.base_amount
      else null
    end desc nulls last,
    av.name;
end;
$$;

create function public.get_available_reporting_months(
  p_household_id uuid
)
returns table (
  period_month date
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
    raise exception 'A signed-in profile is required to read reporting months.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.active_household_ids()) then
    raise exception 'You do not have permission to read reporting months for this household.';
  end if;

  return query
  with spend_months as (
    select vms.period_month
    from public.v_monthly_spend vms
    where vms.household_id = p_household_id
  ),
  cap_bounds as (
    select
      mcs.id,
      min(mcv.effective_month) as start_month,
      case
        when mcs.stopped_from_month is not null then
          (mcs.stopped_from_month - interval '1 month')::date
        else greatest(
          date_trunc('month', current_date)::date,
          max(mcv.effective_month)
        )
      end as end_month
    from public.monthly_cap_series mcs
    join public.monthly_cap_versions mcv
      on mcv.monthly_cap_series_id = mcs.id
      and mcv.household_id = mcs.household_id
    where mcs.household_id = p_household_id
    group by mcs.id, mcs.stopped_from_month
  ),
  cap_months as (
    select generated.month_value::date as period_month
    from cap_bounds
    cross join lateral generate_series(
      cap_bounds.start_month,
      cap_bounds.end_month,
      interval '1 month'
    ) as generated(month_value)
    where cap_bounds.end_month >= cap_bounds.start_month
  )
  select distinct combined.period_month
  from (
    select spend_months.period_month from spend_months
    union all
    select cap_months.period_month from cap_months
  ) combined
  order by combined.period_month desc;
end;
$$;

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
    and not exists (
      select 1
      from public.monthly_cap_version_categories mvc
      where mvc.household_id = categories.household_id
        and mvc.category_id = categories.id
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
    and not exists (
      select 1
      from public.monthly_cap_version_labels mvl
      where mvl.household_id = labels.household_id
        and mvl.label_id = labels.id
    )
  );

create or replace function app_private.delete_orphan_monthly_cap_versions(
  p_household_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_deleted_count integer := 0;
begin
  with orphan_versions as (
    select mcv.id
    from public.monthly_cap_versions mcv
    where mcv.household_id = p_household_id
      and not exists (
        select 1
        from public.monthly_cap_version_categories mvc
        where mvc.household_id = mcv.household_id
          and mvc.monthly_cap_version_id = mcv.id
      )
      and not exists (
        select 1
        from public.monthly_cap_version_labels mvl
        where mvl.household_id = mcv.household_id
          and mvl.monthly_cap_version_id = mcv.id
      )
  )
  delete from public.monthly_cap_versions mcv
  using orphan_versions
  where mcv.id = orphan_versions.id
    and mcv.household_id = p_household_id;

  get diagnostics v_deleted_count = row_count;

  delete from public.monthly_cap_series mcs
  where mcs.household_id = p_household_id
    and not exists (
      select 1
      from public.monthly_cap_versions mcv
      where mcv.household_id = mcs.household_id
        and mcv.monthly_cap_series_id = mcs.id
    );

  return v_deleted_count;
end;
$$;

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
  v_version_cap_count integer := 0;
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
    status,
    notes,
    created_at,
    updated_at
  )
  select
    t.household_id,
    t.id,
    'category_deleted',
    'open',
    v_note,
    v_now,
    v_now
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
    and not exists (
      select 1
      from public.review_items ri
      where ri.household_id = t.household_id
        and ri.transaction_id = t.id
        and ri.status = 'open'
    );

  get diagnostics v_review_count = row_count;

  update public.merchant_mapping_rules mmr
  set is_active = false,
      updated_at = v_now
  where mmr.household_id = p_household_id
    and mmr.is_active
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

  get diagnostics v_mapping_rule_count = row_count;

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

  update public.transactions t
  set category_id = null,
      subcategory_id = null,
      confidence = 'needs_review',
      classification_source = 'manual_review',
      classification_rule_id = null
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

  delete from public.monthly_cap_version_categories mvc
  where mvc.household_id = p_household_id
    and mvc.category_id = p_category_id;

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

  v_version_cap_count :=
    app_private.delete_orphan_monthly_cap_versions(p_household_id);

  delete from public.categories c
  where c.id = p_category_id
    and c.household_id = p_household_id;

  deleted_category_id := p_category_id;
  affected_transaction_count := v_affected_count;
  opened_review_item_count := v_review_count;
  deactivated_mapping_rule_count := v_mapping_rule_count;
  cleared_merchant_count := v_merchant_count;
  cleared_review_suggestion_count := v_review_suggestion_count;
  deleted_cap_count := v_cap_count + v_version_cap_count;
  return next;
end;
$$;

create or replace function public.merge_household_categories(
  p_household_id uuid,
  p_source_category_ids uuid[],
  p_destination_category_id uuid,
  p_destination_name text,
  p_subcategory_mappings jsonb default '[]'::jsonb
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
  v_source_category_ids uuid[];
  v_source_subcategory_ids uuid[];
  v_subcategory_mappings jsonb := coalesce(p_subcategory_mappings, '[]'::jsonb);
  v_transaction_count integer := 0;
  v_merchant_count integer := 0;
  v_mapping_rule_count integer := 0;
  v_review_suggestion_count integer := 0;
  v_cap_count integer := 0;
  v_created_subcategory_count integer := 0;
  v_deleted_category_count integer := 0;
  v_deleted_subcategory_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();
  v_destination_name := nullif(btrim(p_destination_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to merge categories.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to merge categories for this household.';
  end if;

  if v_destination_name is null then
    raise exception 'Destination category name is required.';
  end if;

  select coalesce(array_agg(distinct source_id order by source_id), '{}'::uuid[])
  into v_source_category_ids
  from unnest(coalesce(p_source_category_ids, '{}'::uuid[])) as provided(source_id)
  where provided.source_id is not null
    and provided.source_id <> p_destination_category_id;

  if cardinality(v_source_category_ids) = 0 then
    raise exception 'At least one source category is required.';
  end if;

  if not exists (
    select 1
    from public.categories c
    where c.id = p_destination_category_id
      and c.household_id = p_household_id
  ) then
    raise exception 'Destination category not found for this household.';
  end if;

  if exists (
    select 1
    from unnest(v_source_category_ids) as source_categories(source_id)
    where not exists (
      select 1
      from public.categories c
      where c.id = source_categories.source_id
        and c.household_id = p_household_id
    )
  ) then
    raise exception 'Source categories must belong to this household.';
  end if;

  select coalesce(array_agg(sc.id order by sc.id), '{}'::uuid[])
  into v_source_subcategory_ids
  from public.subcategories sc
  where sc.household_id = p_household_id
    and sc.category_id = any(v_source_category_ids);

  if exists (
    select 1
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
    where not (
      mappings.element ? 'source_subcategory_id'
      and mappings.element ? 'destination_subcategory_name'
    )
  ) then
    raise exception 'Subcategory mappings must include source_subcategory_id and destination_subcategory_name.';
  end if;

  if exists (
    select 1
    from unnest(v_source_subcategory_ids) as source_subcategories(source_id)
    where not exists (
      select 1
      from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
      where (mappings.element ->> 'source_subcategory_id')::uuid =
        source_subcategories.source_id
    )
  ) then
    raise exception 'Every source subcategory requires an explicit mapping.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
    where (mappings.element ->> 'source_subcategory_id')::uuid
      <> all(v_source_subcategory_ids)
  ) then
    raise exception 'Subcategory mappings reference an unknown source subcategory.';
  end if;

  with requested_destination_names as (
    select
      (mappings.element ->> 'source_subcategory_id')::uuid
        as source_subcategory_id,
      nullif(btrim(mappings.element ->> 'destination_subcategory_name'), '')
        as destination_subcategory_name
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'source_subcategory_id',
      requested_destination_names.source_subcategory_id,
      'destination_subcategory_id',
      destination_subcategories.id,
      'destination_subcategory_name',
      requested_destination_names.destination_subcategory_name
    )
  ), '[]'::jsonb)
  into v_subcategory_mappings
  from requested_destination_names
  left join public.subcategories destination_subcategories
    on destination_subcategories.household_id = p_household_id
    and destination_subcategories.category_id = p_destination_category_id
    and lower(destination_subcategories.name) =
      lower(requested_destination_names.destination_subcategory_name);

  if exists (
    select 1
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
    where nullif(mappings.element ->> 'destination_subcategory_name', '') is null
  ) then
    raise exception 'Destination subcategory names are required.';
  end if;

  with missing_destination_subcategories as (
    select distinct
      mappings.element ->> 'destination_subcategory_name' as name
    from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
    where mappings.element ->> 'destination_subcategory_id' is null
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
      missing_destination_subcategories.name,
      row_number() over (
        order by lower(missing_destination_subcategories.name),
          missing_destination_subcategories.name
      ) + coalesce(
        (
          select max(sc.sort_order)
          from public.subcategories sc
          where sc.household_id = p_household_id
            and sc.category_id = p_destination_category_id
        ),
        0
      )
    from missing_destination_subcategories
    returning id, name
  )
  select
    jsonb_agg(
      case
        when mappings.element ->> 'destination_subcategory_id' is null then
          jsonb_set(
            mappings.element,
            '{destination_subcategory_id}',
            to_jsonb(inserted.id::text)
          )
        else mappings.element
      end
    ),
    count(inserted.id)::integer
  into v_subcategory_mappings, v_created_subcategory_count
  from jsonb_array_elements(v_subcategory_mappings) as mappings(element)
  left join inserted
    on inserted.name = mappings.element ->> 'destination_subcategory_name';

  select coalesce(v_subcategory_mappings, '[]'::jsonb)
  into v_subcategory_mappings;

  select count(*)::integer
  into v_transaction_count
  from public.transactions t
  where t.household_id = p_household_id
    and t.category_id = any(v_source_category_ids);

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
      end
  where t.household_id = p_household_id
    and t.category_id = any(v_source_category_ids);

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

  insert into public.monthly_cap_version_categories (
    household_id,
    monthly_cap_version_id,
    category_id
  )
  select distinct
    mvc.household_id,
    mvc.monthly_cap_version_id,
    p_destination_category_id
  from public.monthly_cap_version_categories mvc
  where mvc.household_id = p_household_id
    and mvc.category_id = any(v_source_category_ids)
  on conflict on constraint monthly_cap_version_categories_pkey do nothing;

  delete from public.monthly_cap_categories mcc
  where mcc.household_id = p_household_id
    and mcc.category_id = any(v_source_category_ids);

  delete from public.monthly_cap_version_categories mvc
  where mvc.household_id = p_household_id
    and mvc.category_id = any(v_source_category_ids);

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

  delete from public.monthly_cap_version_labels mvl
  where mvl.household_id = p_household_id
    and mvl.label_id = p_label_id;

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

  perform app_private.delete_orphan_monthly_cap_versions(p_household_id);

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

drop function if exists public.merge_household_categories(
  uuid,
  uuid[],
  uuid,
  text,
  jsonb
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

create or replace function app_private.sync_monthly_cap_category_insert()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting(
    'app.skip_monthly_cap_legacy_target_sync',
    true
  ) = 'on' then
    return new;
  end if;

  insert into public.monthly_cap_version_categories (
    household_id,
    monthly_cap_version_id,
    category_id,
    created_at
  )
  select
    new.household_id,
    mcv.id,
    new.category_id,
    new.created_at
  from public.monthly_cap_versions mcv
  where mcv.household_id = new.household_id
    and mcv.monthly_cap_series_id = new.monthly_cap_id
  on conflict on constraint monthly_cap_version_categories_pkey do nothing;

  return new;
end;
$$;

create or replace function app_private.sync_monthly_cap_category_delete()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting(
    'app.skip_monthly_cap_legacy_target_sync',
    true
  ) = 'on' then
    return old;
  end if;

  delete from public.monthly_cap_version_categories mvc
  using public.monthly_cap_versions mcv
  where mvc.household_id = old.household_id
    and mvc.category_id = old.category_id
    and mcv.id = mvc.monthly_cap_version_id
    and mcv.household_id = mvc.household_id
    and mcv.monthly_cap_series_id = old.monthly_cap_id;

  perform app_private.delete_orphan_monthly_cap_versions(old.household_id);

  return old;
end;
$$;

create or replace function app_private.sync_monthly_cap_label_insert()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting(
    'app.skip_monthly_cap_legacy_target_sync',
    true
  ) = 'on' then
    return new;
  end if;

  insert into public.monthly_cap_version_labels (
    household_id,
    monthly_cap_version_id,
    label_id,
    created_at
  )
  select
    new.household_id,
    mcv.id,
    new.label_id,
    new.created_at
  from public.monthly_cap_versions mcv
  where mcv.household_id = new.household_id
    and mcv.monthly_cap_series_id = new.monthly_cap_id
  on conflict on constraint monthly_cap_version_labels_pkey do nothing;

  return new;
end;
$$;

create or replace function app_private.sync_monthly_cap_label_delete()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting(
    'app.skip_monthly_cap_legacy_target_sync',
    true
  ) = 'on' then
    return old;
  end if;

  delete from public.monthly_cap_version_labels mvl
  using public.monthly_cap_versions mcv
  where mvl.household_id = old.household_id
    and mvl.label_id = old.label_id
    and mcv.id = mvl.monthly_cap_version_id
    and mcv.household_id = mvl.household_id
    and mcv.monthly_cap_series_id = old.monthly_cap_id;

  perform app_private.delete_orphan_monthly_cap_versions(old.household_id);

  return old;
end;
$$;

drop trigger if exists sync_monthly_cap_category_insert
  on public.monthly_cap_categories;
create trigger sync_monthly_cap_category_insert
  after insert on public.monthly_cap_categories
  for each row execute function app_private.sync_monthly_cap_category_insert();

drop trigger if exists sync_monthly_cap_category_delete
  on public.monthly_cap_categories;
create trigger sync_monthly_cap_category_delete
  after delete on public.monthly_cap_categories
  for each row execute function app_private.sync_monthly_cap_category_delete();

drop trigger if exists sync_monthly_cap_label_insert
  on public.monthly_cap_labels;
create trigger sync_monthly_cap_label_insert
  after insert on public.monthly_cap_labels
  for each row execute function app_private.sync_monthly_cap_label_insert();

drop trigger if exists sync_monthly_cap_label_delete
  on public.monthly_cap_labels;
create trigger sync_monthly_cap_label_delete
  after delete on public.monthly_cap_labels
  for each row execute function app_private.sync_monthly_cap_label_delete();

revoke all privileges on public.monthly_cap_series
  from public, anon, authenticated, service_role;
revoke all privileges on public.monthly_cap_versions
  from public, anon, authenticated, service_role;
revoke all privileges on public.monthly_cap_version_categories
  from public, anon, authenticated, service_role;
revoke all privileges on public.monthly_cap_version_labels
  from public, anon, authenticated, service_role;
revoke all privileges on public.v_monthly_cap_progress
  from public, anon, authenticated, service_role;
revoke all privileges on public.v_budget_progress
  from public, anon, authenticated, service_role;
revoke execute on function public.upsert_monthly_cap(
  uuid,
  uuid,
  text,
  date,
  numeric,
  uuid[],
  uuid[],
  boolean
) from public, anon, authenticated, service_role;
revoke execute on function public.delete_monthly_cap(uuid, uuid, date)
  from public, anon, authenticated, service_role;
revoke execute on function public.get_monthly_cap_progress(uuid, date)
  from public, anon, authenticated, service_role;
revoke execute on function public.get_available_reporting_months(uuid)
  from public, anon, authenticated, service_role;

grant select, insert, update, delete on public.monthly_cap_series
  to authenticated;
grant select, insert, update, delete on public.monthly_cap_versions
  to authenticated;
grant select, insert, update, delete on public.monthly_cap_version_categories
  to authenticated;
grant select, insert, update, delete on public.monthly_cap_version_labels
  to authenticated;
grant select on public.v_monthly_cap_progress to authenticated;
grant select on public.v_budget_progress to authenticated;
grant execute on function public.upsert_monthly_cap(
  uuid,
  uuid,
  text,
  date,
  numeric,
  uuid[],
  uuid[],
  boolean
) to authenticated;
grant execute on function public.delete_monthly_cap(uuid, uuid, date)
  to authenticated;
grant execute on function public.get_monthly_cap_progress(uuid, date)
  to authenticated;
grant execute on function public.get_available_reporting_months(uuid)
  to authenticated;
