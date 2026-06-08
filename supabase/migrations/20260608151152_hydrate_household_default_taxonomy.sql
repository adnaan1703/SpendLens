create or replace function app_private.hydrate_household_default_taxonomy(target_household_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if target_household_id is null then
    return;
  end if;

  insert into public.categories (
    household_id,
    name,
    sort_order,
    is_system
  )
  select
    target_household_id,
    dc.name,
    dc.sort_order,
    dc.is_system
  from public.default_categories dc
  on conflict (household_id, (lower(name))) do update
    set sort_order = excluded.sort_order,
        is_system = excluded.is_system;

  insert into public.subcategories (
    household_id,
    category_id,
    name,
    sort_order
  )
  select
    target_household_id,
    c.id,
    ds.name,
    ds.sort_order
  from public.default_subcategories ds
  join public.default_categories dc
    on dc.id = ds.default_category_id
  join public.categories c
    on c.household_id = target_household_id
   and lower(c.name) = lower(dc.name)
  on conflict (category_id, (lower(name))) do update
    set sort_order = excluded.sort_order;
end;
$$;

create or replace function app_private.hydrate_household_default_taxonomy_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.hydrate_household_default_taxonomy(new.id);
  return new;
end;
$$;

drop trigger if exists hydrate_household_default_taxonomy_after_insert
  on public.households;

create trigger hydrate_household_default_taxonomy_after_insert
  after insert on public.households
  for each row
  execute function app_private.hydrate_household_default_taxonomy_after_insert();

select app_private.hydrate_household_default_taxonomy(h.id)
from public.households h;
