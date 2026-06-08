create or replace function public.create_household_category(
  p_household_id uuid,
  p_category_name text,
  p_subcategory_name text
)
returns table (
  category_id uuid,
  category_name text,
  subcategory_id uuid,
  subcategory_name text
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_category_id uuid;
  v_subcategory_id uuid;
  v_category_name text;
  v_subcategory_name text;
  v_category_sort_order integer;
begin
  v_profile_id := app_private.current_profile_id();
  v_category_name := nullif(btrim(p_category_name), '');
  v_subcategory_name := nullif(btrim(p_subcategory_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to create categories.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to create categories for this household.';
  end if;

  if v_category_name is null then
    raise exception 'Category name is required.';
  end if;

  if v_subcategory_name is null then
    raise exception 'Subcategory name is required.';
  end if;

  perform 1
  from public.categories c
  where c.household_id = p_household_id
    and lower(c.name) = lower(v_category_name);

  if found then
    raise exception 'A category with this name already exists.';
  end if;

  select coalesce(max(c.sort_order), 0) + 1
  into v_category_sort_order
  from public.categories c
  where c.household_id = p_household_id;

  insert into public.categories (
    household_id,
    name,
    sort_order,
    is_system
  )
  values (
    p_household_id,
    v_category_name,
    v_category_sort_order,
    false
  )
  returning id into v_category_id;

  insert into public.subcategories (
    household_id,
    category_id,
    name,
    sort_order
  )
  values (
    p_household_id,
    v_category_id,
    v_subcategory_name,
    1
  )
  returning id into v_subcategory_id;

  return query
  select
    v_category_id,
    v_category_name,
    v_subcategory_id,
    v_subcategory_name;
exception
  when unique_violation then
    raise exception 'Category or subcategory already exists.';
end;
$$;

revoke execute on function public.create_household_category(uuid, text, text)
  from public, anon;
grant execute on function public.create_household_category(uuid, text, text)
  to authenticated, service_role;
