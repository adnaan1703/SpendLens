create table public.labels (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  name text not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, household_id),
  constraint labels_name_trimmed_nonempty check (
    btrim(name) <> ''
    and name = btrim(name)
  )
);

create table public.transaction_labels (
  household_id uuid not null references public.households (id) on delete cascade,
  transaction_id uuid not null,
  label_id uuid not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (transaction_id, label_id),
  constraint transaction_labels_transaction_household_fk
    foreign key (transaction_id, household_id)
    references public.transactions (id, household_id) on delete cascade,
  constraint transaction_labels_label_household_fk
    foreign key (label_id, household_id)
    references public.labels (id, household_id) on delete cascade
);

create unique index labels_household_lower_name_key
  on public.labels (household_id, lower(name));
create index labels_household_id_idx on public.labels (household_id);
create index transaction_labels_household_label_idx
  on public.transaction_labels (household_id, label_id);
create index transaction_labels_household_transaction_idx
  on public.transaction_labels (household_id, transaction_id);

create trigger set_labels_updated_at
  before update on public.labels
  for each row execute function app_private.set_updated_at();

alter table public.labels enable row level security;
alter table public.transaction_labels enable row level security;

create policy "labels_select_members"
  on public.labels
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "labels_insert_writers"
  on public.labels
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "labels_update_writers"
  on public.labels
  for update
  to authenticated
  using (household_id in (select app_private.write_household_ids()))
  with check (household_id in (select app_private.write_household_ids()));
create policy "labels_delete_writers"
  on public.labels
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create policy "transaction_labels_select_members"
  on public.transaction_labels
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
create policy "transaction_labels_insert_writers"
  on public.transaction_labels
  for insert
  to authenticated
  with check (
    household_id in (select app_private.write_household_ids())
    and (created_by is null or created_by = app_private.current_profile_id())
  );
create policy "transaction_labels_delete_writers"
  on public.transaction_labels
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create view public.v_label_usage
with (security_invoker = true)
as
select
  l.id,
  l.household_id,
  l.name,
  l.created_by,
  l.created_at,
  l.updated_at,
  count(tl.transaction_id)::integer as transaction_count,
  max(coalesce(t.occurred_at, t.transaction_date::timestamptz)) as recent_used_at
from public.labels l
left join public.transaction_labels tl
  on tl.label_id = l.id
  and tl.household_id = l.household_id
left join public.transactions t
  on t.id = tl.transaction_id
  and t.household_id = tl.household_id
group by
  l.id,
  l.household_id,
  l.name,
  l.created_by,
  l.created_at,
  l.updated_at;

create or replace function public.set_transaction_labels(
  p_household_id uuid,
  p_transaction_id uuid,
  p_label_ids uuid[] default '{}',
  p_new_label_names text[] default '{}'
)
returns table (
  id uuid,
  household_id uuid,
  name text,
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_label_ids uuid[] := coalesce(p_label_ids, '{}'::uuid[]);
  v_new_label_names text[] := coalesce(p_new_label_names, '{}'::text[]);
  v_new_label_ids uuid[] := '{}'::uuid[];
  v_final_label_ids uuid[] := '{}'::uuid[];
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to set transaction labels.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to set labels for this household.';
  end if;

  perform 1
  from public.transactions t
  where t.id = p_transaction_id
    and t.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Transaction not found for this household.';
  end if;

  if exists (
    select 1
    from unnest(v_label_ids) as provided(label_id)
    where provided.label_id is null
  ) then
    raise exception 'Label IDs cannot be blank.';
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

  if exists (
    select 1
    from unnest(v_new_label_names) as provided(label_name)
    where nullif(btrim(provided.label_name), '') is null
  ) then
    raise exception 'Label name is required.';
  end if;

  with raw_names as (
    select
      btrim(provided.label_name) as label_name,
      lower(btrim(provided.label_name)) as label_key
    from unnest(v_new_label_names) as provided(label_name)
  ),
  distinct_names as (
    select distinct on (label_key)
      label_name,
      label_key
    from raw_names
    order by label_key, label_name
  )
  insert into public.labels (
    household_id,
    name,
    created_by
  )
  select
    p_household_id,
    distinct_names.label_name,
    v_profile_id
  from distinct_names
  on conflict do nothing;

  with raw_names as (
    select
      btrim(provided.label_name) as label_name,
      lower(btrim(provided.label_name)) as label_key
    from unnest(v_new_label_names) as provided(label_name)
  ),
  distinct_names as (
    select distinct on (label_key)
      label_name,
      label_key
    from raw_names
    order by label_key, label_name
  )
  select coalesce(array_agg(l.id order by lower(l.name), l.name, l.id), '{}'::uuid[])
  into v_new_label_ids
  from public.labels l
  join distinct_names
    on distinct_names.label_key = lower(l.name)
  where l.household_id = p_household_id;

  with final_ids as (
    select distinct provided.label_id
    from unnest(v_label_ids || v_new_label_ids) as provided(label_id)
    where provided.label_id is not null
  )
  select coalesce(array_agg(final_ids.label_id order by final_ids.label_id), '{}'::uuid[])
  into v_final_label_ids
  from final_ids;

  delete from public.transaction_labels tl
  where tl.household_id = p_household_id
    and tl.transaction_id = p_transaction_id
    and not exists (
      select 1
      from unnest(v_final_label_ids) as final_ids(label_id)
      where final_ids.label_id = tl.label_id
    );

  insert into public.transaction_labels (
    household_id,
    transaction_id,
    label_id,
    created_by
  )
  select
    p_household_id,
    p_transaction_id,
    final_ids.label_id,
    v_profile_id
  from unnest(v_final_label_ids) as final_ids(label_id)
  on conflict (transaction_id, label_id) do nothing;

  return query
  select
    l.id,
    l.household_id,
    l.name,
    l.created_by,
    l.created_at,
    l.updated_at
  from public.transaction_labels tl
  join public.labels l
    on l.id = tl.label_id
    and l.household_id = tl.household_id
  where tl.household_id = p_household_id
    and tl.transaction_id = p_transaction_id
  order by lower(l.name), l.name, l.id;
end;
$$;

create or replace function public.rename_household_label(
  p_household_id uuid,
  p_label_id uuid,
  p_name text
)
returns table (
  id uuid,
  household_id uuid,
  name text,
  created_by uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_name text;
begin
  v_profile_id := app_private.current_profile_id();
  v_name := nullif(btrim(p_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to rename labels.';
  end if;

  if p_household_id is null
      or p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to rename labels for this household.';
  end if;

  if v_name is null then
    raise exception 'Label name is required.';
  end if;

  perform 1
  from public.labels l
  where l.id = p_label_id
    and l.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Label not found for this household.';
  end if;

  perform 1
  from public.labels l
  where l.household_id = p_household_id
    and l.id <> p_label_id
    and lower(l.name) = lower(v_name);

  if found then
    raise exception 'A label with this name already exists.';
  end if;

  return query
  update public.labels l
  set name = v_name
  where l.id = p_label_id
    and l.household_id = p_household_id
  returning
    l.id,
    l.household_id,
    l.name,
    l.created_by,
    l.created_at,
    l.updated_at;
exception
  when unique_violation then
    raise exception 'A label with this name already exists.';
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

revoke all privileges on public.labels from public, anon, authenticated, service_role;
revoke all privileges on public.transaction_labels
  from public, anon, authenticated, service_role;
revoke all privileges on public.v_label_usage
  from public, anon, authenticated, service_role;
revoke execute on function public.set_transaction_labels(uuid, uuid, uuid[], text[])
  from public, anon, authenticated;
revoke execute on function public.rename_household_label(uuid, uuid, text)
  from public, anon, authenticated;
revoke execute on function public.delete_household_label(uuid, uuid)
  from public, anon, authenticated;

grant select, insert, delete on public.labels to authenticated;
grant update (name) on public.labels to authenticated;
grant select, insert, delete on public.transaction_labels to authenticated;
grant select on public.v_label_usage to authenticated;
grant execute on function public.set_transaction_labels(uuid, uuid, uuid[], text[])
  to authenticated;
grant execute on function public.rename_household_label(uuid, uuid, text)
  to authenticated;
grant execute on function public.delete_household_label(uuid, uuid)
  to authenticated;
