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
  from public.category_caps cc
  where cc.household_id = p_household_id
    and cc.category_id = any(v_source_category_ids);

  with source_cap_totals as (
    select
      cc.period_month,
      sum(cc.cap_amount) as cap_amount
    from public.category_caps cc
    where cc.household_id = p_household_id
      and cc.category_id = any(v_source_category_ids)
    group by cc.period_month
  )
  insert into public.category_caps (
    household_id,
    category_id,
    period_month,
    cap_amount,
    created_by
  )
  select
    p_household_id,
    p_destination_category_id,
    source_cap_totals.period_month,
    source_cap_totals.cap_amount,
    v_profile_id
  from source_cap_totals
  on conflict (household_id, category_id, period_month)
  do update
    set cap_amount = public.category_caps.cap_amount + excluded.cap_amount,
        updated_at = v_now;

  delete from public.category_caps cc
  where cc.household_id = p_household_id
    and cc.category_id = any(v_source_category_ids);

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

revoke execute on function public.merge_household_categories(
  uuid,
  uuid,
  text,
  uuid[],
  jsonb
) from public, anon;
grant execute on function public.merge_household_categories(
  uuid,
  uuid,
  text,
  uuid[],
  jsonb
) to authenticated, service_role;
