create or replace function public.update_household_category_taxonomy(
  p_household_id uuid,
  p_category_id uuid,
  p_category_name text,
  p_subcategories jsonb
)
returns table (
  category_id uuid,
  category_name text,
  subcategory_id uuid,
  subcategory_name text,
  subcategory_sort_order integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_category_name text;
  v_new_sort_order integer;
begin
  v_profile_id := app_private.current_profile_id();
  v_category_name := nullif(btrim(p_category_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to update categories.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to update categories for this household.';
  end if;

  if v_category_name is null then
    raise exception 'Category name is required.';
  end if;

  if p_subcategories is null or jsonb_typeof(p_subcategories) <> 'array' then
    raise exception 'Subcategories must be provided as an array.';
  end if;

  perform 1
  from public.categories c
  where c.id = p_category_id
    and c.household_id = p_household_id;

  if not found then
    raise exception 'Category not found for this household.';
  end if;

  perform 1
  from public.categories c
  where c.household_id = p_household_id
    and c.id <> p_category_id
    and lower(c.name) = lower(v_category_name);

  if found then
    raise exception 'A category with this name already exists.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_subcategories) as payload(element)
    where jsonb_typeof(payload.element) <> 'object'
  ) then
    raise exception 'Each subcategory entry must be an object.';
  end if;

  if exists (
    with payload as (
      select
        entry.ordinality::integer as ordinal,
        nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
        nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
      from jsonb_array_elements(p_subcategories) with ordinality
        as entry(element, ordinality)
    )
    select 1
    from payload
    where payload.subcategory_name is null
  ) then
    raise exception 'Subcategory name is required.';
  end if;

  if exists (
    with payload as (
      select
        entry.ordinality::integer as ordinal,
        nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
        nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
      from jsonb_array_elements(p_subcategories) with ordinality
        as entry(element, ordinality)
    )
    select 1
    from payload
    where payload.subcategory_id is not null
    group by payload.subcategory_id
    having count(*) > 1
  ) then
    raise exception 'A subcategory can only appear once.';
  end if;

  if exists (
    with payload as (
      select
        entry.ordinality::integer as ordinal,
        nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
        nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
      from jsonb_array_elements(p_subcategories) with ordinality
        as entry(element, ordinality)
    )
    select 1
    from payload
    where payload.subcategory_id is not null
      and not exists (
        select 1
        from public.subcategories sc
        where sc.id = payload.subcategory_id
          and sc.category_id = p_category_id
          and sc.household_id = p_household_id
      )
  ) then
    raise exception 'Subcategory not found for this category.';
  end if;

  if exists (
    with payload as (
      select
        entry.ordinality::integer as ordinal,
        nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
        nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
      from jsonb_array_elements(p_subcategories) with ordinality
        as entry(element, ordinality)
    )
    select 1
    from payload
    group by lower(payload.subcategory_name)
    having count(*) > 1
  ) then
    raise exception 'Subcategory names must be unique within a category.';
  end if;

  if exists (
    with payload as (
      select
        entry.ordinality::integer as ordinal,
        nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
        nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
      from jsonb_array_elements(p_subcategories) with ordinality
        as entry(element, ordinality)
    )
    select 1
    from public.subcategories sc
    join payload
      on lower(sc.name) = lower(payload.subcategory_name)
    where sc.household_id = p_household_id
      and sc.category_id = p_category_id
      and (
        payload.subcategory_id is null
        or sc.id <> payload.subcategory_id
      )
      and not exists (
        select 1
        from payload payload_existing
        where payload_existing.subcategory_id = sc.id
      )
  ) then
    raise exception 'A subcategory with this name already exists in this category.';
  end if;

  update public.categories c
  set name = v_category_name
  where c.id = p_category_id
    and c.household_id = p_household_id;

  update public.subcategories sc
  set name = '__renaming_' || sc.id::text
  from (
    select
      nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id
    from jsonb_array_elements(p_subcategories) with ordinality
      as entry(element, ordinality)
  ) payload
  where sc.id = payload.subcategory_id
    and sc.category_id = p_category_id
    and sc.household_id = p_household_id;

  update public.subcategories sc
  set name = payload.subcategory_name
  from (
    select
      nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
      nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
    from jsonb_array_elements(p_subcategories) with ordinality
      as entry(element, ordinality)
  ) payload
  where sc.id = payload.subcategory_id
    and sc.category_id = p_category_id
    and sc.household_id = p_household_id;

  select coalesce(max(sc.sort_order), 0)
  into v_new_sort_order
  from public.subcategories sc
  where sc.household_id = p_household_id
    and sc.category_id = p_category_id;

  insert into public.subcategories (
    household_id,
    category_id,
    name,
    sort_order
  )
  select
    p_household_id,
    p_category_id,
    payload.subcategory_name,
    v_new_sort_order + row_number() over (order by payload.ordinal)
  from (
    select
      entry.ordinality::integer as ordinal,
      nullif(btrim(entry.element ->> 'id'), '')::uuid as subcategory_id,
      nullif(btrim(entry.element ->> 'name'), '') as subcategory_name
    from jsonb_array_elements(p_subcategories) with ordinality
      as entry(element, ordinality)
  ) payload
  where payload.subcategory_id is null;

  return query
  select
    c.id,
    c.name,
    sc.id,
    sc.name,
    sc.sort_order
  from public.categories c
  left join public.subcategories sc
    on sc.category_id = c.id
    and sc.household_id = c.household_id
  where c.id = p_category_id
    and c.household_id = p_household_id
  order by sc.sort_order nulls last, sc.name nulls last;
exception
  when unique_violation then
    raise exception 'Category or subcategory already exists.';
end;
$$;

revoke execute on function public.update_household_category_taxonomy(
  uuid,
  uuid,
  text,
  jsonb
) from public, anon;
grant execute on function public.update_household_category_taxonomy(
  uuid,
  uuid,
  text,
  jsonb
) to authenticated, service_role;
