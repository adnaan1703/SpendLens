create or replace view public.v_merchant_group_usage
with (security_invoker = true)
as
select
  m.household_id,
  m.id as merchant_id,
  m.display_name,
  m.category_id,
  c.name as category_name,
  m.subcategory_id,
  sc.name as subcategory_name,
  coalesce(tx.transaction_count, 0)::integer as transaction_count,
  coalesce(tx.net_spend, 0)::numeric(14,2) as net_spend,
  coalesce(alias_counts.alias_count, 0)::integer as alias_count,
  coalesce(rule_counts.active_mapping_rule_count, 0)::integer
    as active_mapping_rule_count,
  coalesce(review_counts.open_review_suggestion_count, 0)::integer
    as open_review_suggestion_count,
  tx.last_transaction_date
from public.merchants m
left join public.categories c
  on c.id = m.category_id
 and c.household_id = m.household_id
left join public.subcategories sc
  on sc.id = m.subcategory_id
 and sc.category_id = m.category_id
 and sc.household_id = m.household_id
left join lateral (
  select
    count(*)::integer as transaction_count,
    coalesce(sum(t.net_expense), 0)::numeric(14,2) as net_spend,
    max(t.transaction_date) as last_transaction_date
  from public.transactions t
  where t.household_id = m.household_id
    and t.merchant_id = m.id
) tx on true
left join lateral (
  select count(*)::integer as alias_count
  from public.merchant_aliases ma
  where ma.household_id = m.household_id
    and ma.merchant_id = m.id
) alias_counts on true
left join lateral (
  select count(*)::integer as active_mapping_rule_count
  from public.merchant_mapping_rules mmr
  where mmr.household_id = m.household_id
    and mmr.merchant_id = m.id
    and mmr.apply_to_future
) rule_counts on true
left join lateral (
  select count(*)::integer as open_review_suggestion_count
  from public.review_items ri
  where ri.household_id = m.household_id
    and ri.suggested_merchant_id = m.id
    and ri.status = 'open'
) review_counts on true;

grant select on public.v_merchant_group_usage to authenticated;

create policy "merchants_delete_merge_writers"
  on public.merchants
  for delete
  to authenticated
  using (
    household_id in (select app_private.write_household_ids())
    and current_setting('app.merchant_group_merge', true) = 'on'
  );

create or replace function public.rename_household_merchant(
  p_household_id uuid,
  p_merchant_id uuid,
  p_display_name text
)
returns table (
  id uuid,
  display_name text,
  category_id uuid,
  subcategory_id uuid
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_display_name text;
begin
  v_profile_id := app_private.current_profile_id();
  v_display_name := nullif(btrim(p_display_name), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to rename merchant groups.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to rename merchant groups for this household.';
  end if;

  if v_display_name is null then
    raise exception 'Merchant group name is required.';
  end if;

  perform 1
  from public.merchants m
  where m.id = p_merchant_id
    and m.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Merchant group not found for this household.';
  end if;

  if exists (
    select 1
    from public.merchants m
    where m.household_id = p_household_id
      and m.id <> p_merchant_id
      and lower(m.display_name) = lower(v_display_name)
  ) then
    raise exception 'A merchant group with this name already exists.';
  end if;

  return query
  update public.merchants m
  set display_name = v_display_name
  where m.id = p_merchant_id
    and m.household_id = p_household_id
  returning m.id, m.display_name, m.category_id, m.subcategory_id;
exception
  when unique_violation then
    raise exception 'A merchant group with this name already exists.';
end;
$$;

create or replace function public.merge_household_merchants(
  p_household_id uuid,
  p_destination_merchant_id uuid,
  p_destination_display_name text,
  p_source_merchant_ids uuid[],
  p_category_strategy text
)
returns table (
  destination_merchant_id uuid,
  destination_display_name text,
  destination_category_id uuid,
  destination_subcategory_id uuid,
  moved_transaction_count integer,
  moved_alias_count integer,
  moved_mapping_rule_count integer,
  moved_review_suggestion_count integer,
  deleted_source_merchant_count integer,
  category_updated_transaction_count integer,
  category_updated_mapping_rule_count integer,
  category_updated_review_suggestion_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_destination_display_name text;
  v_category_strategy text;
  v_source_merchant_ids uuid[];
  v_destination_category_id uuid;
  v_destination_subcategory_id uuid;
  v_input_source_count integer := 0;
  v_distinct_source_count integer := 0;
  v_source_count integer := 0;
  v_transaction_count integer := 0;
  v_alias_count integer := 0;
  v_mapping_rule_count integer := 0;
  v_inactive_mapping_rule_count integer := 0;
  v_review_suggestion_count integer := 0;
  v_deleted_source_count integer := 0;
  v_category_transaction_count integer := 0;
  v_category_mapping_rule_count integer := 0;
  v_category_review_suggestion_count integer := 0;
  v_note text;
  v_now timestamptz := now();
begin
  v_profile_id := app_private.current_profile_id();
  v_destination_display_name := nullif(btrim(p_destination_display_name), '');
  v_category_strategy := lower(nullif(btrim(p_category_strategy), ''));

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to merge merchant groups.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to merge merchant groups for this household.';
  end if;

  if v_destination_display_name is null then
    raise exception 'Destination merchant group name is required.';
  end if;

  if p_source_merchant_ids is null or cardinality(p_source_merchant_ids) = 0 then
    raise exception 'At least one source merchant group is required.';
  end if;

  if v_category_strategy not in ('preserve', 'destination') then
    raise exception 'Category strategy must be preserve or destination.';
  end if;

  select
    count(*)::integer,
    count(distinct source_id)::integer
  into v_input_source_count, v_distinct_source_count
  from unnest(p_source_merchant_ids) as source_ids(source_id);

  if v_input_source_count <> v_distinct_source_count then
    raise exception 'A source merchant group can only appear once.';
  end if;

  if exists (
    select 1
    from unnest(p_source_merchant_ids) as source_ids(source_id)
    where source_ids.source_id is null
  ) then
    raise exception 'Source merchant group ids cannot be blank.';
  end if;

  select array_agg(source_ids.source_id order by source_ids.source_id)
  into v_source_merchant_ids
  from (
    select distinct source_id
    from unnest(p_source_merchant_ids) as source_ids(source_id)
  ) source_ids;

  select m.category_id, m.subcategory_id
  into v_destination_category_id, v_destination_subcategory_id
  from public.merchants m
  where m.id = p_destination_merchant_id
    and m.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Destination merchant group not found for this household.';
  end if;

  if p_destination_merchant_id = any(v_source_merchant_ids) then
    raise exception 'Source merchant groups cannot include the destination merchant group.';
  end if;

  select count(*)::integer
  into v_source_count
  from public.merchants m
  where m.household_id = p_household_id
    and m.id = any(v_source_merchant_ids);

  if v_source_count <> cardinality(v_source_merchant_ids) then
    raise exception 'Source merchant groups must belong to the same household.';
  end if;

  if exists (
    select 1
    from public.merchants m
    where m.household_id = p_household_id
      and m.id <> p_destination_merchant_id
      and lower(m.display_name) = lower(v_destination_display_name)
  ) then
    raise exception 'A merchant group with this name already exists.';
  end if;

  if v_category_strategy = 'destination'
      and (
        v_destination_category_id is null
        or v_destination_subcategory_id is null
      ) then
    raise exception 'Destination category strategy requires the destination merchant group to have a category and subcategory.';
  end if;

  update public.merchants m
  set display_name = v_destination_display_name
  where m.id = p_destination_merchant_id
    and m.household_id = p_household_id;

  update public.merchant_aliases ma
  set merchant_id = p_destination_merchant_id
  where ma.household_id = p_household_id
    and ma.merchant_id = any(v_source_merchant_ids);

  get diagnostics v_alias_count = row_count;

  v_note := 'Merchant group merged into: ' || v_destination_display_name || '.';

  if v_category_strategy = 'destination' then
    update public.transactions t
    set merchant_id = p_destination_merchant_id,
        category_id = v_destination_category_id,
        subcategory_id = v_destination_subcategory_id,
        classification_updated_by = v_profile_id,
        classification_updated_at = v_now,
        classification_note = v_note
    where t.household_id = p_household_id
      and t.merchant_id = any(v_source_merchant_ids);

    get diagnostics v_transaction_count = row_count;
    v_category_transaction_count := v_transaction_count;

    update public.merchant_mapping_rules mmr
    set merchant_id = p_destination_merchant_id,
        category_id = v_destination_category_id,
        subcategory_id = v_destination_subcategory_id
    where mmr.household_id = p_household_id
      and mmr.merchant_id = any(v_source_merchant_ids)
      and mmr.apply_to_future;

    get diagnostics v_category_mapping_rule_count = row_count;

    update public.merchant_mapping_rules mmr
    set merchant_id = p_destination_merchant_id
    where mmr.household_id = p_household_id
      and mmr.merchant_id = any(v_source_merchant_ids)
      and not mmr.apply_to_future;

    get diagnostics v_inactive_mapping_rule_count = row_count;
    v_mapping_rule_count :=
      v_category_mapping_rule_count + v_inactive_mapping_rule_count;

    update public.review_items ri
    set suggested_merchant_id = p_destination_merchant_id,
        suggested_category_id = v_destination_category_id,
        suggested_subcategory_id = v_destination_subcategory_id
    where ri.household_id = p_household_id
      and ri.status = 'open'
      and ri.suggested_merchant_id = any(v_source_merchant_ids);

    get diagnostics v_review_suggestion_count = row_count;
    v_category_review_suggestion_count := v_review_suggestion_count;
  else
    update public.transactions t
    set merchant_id = p_destination_merchant_id
    where t.household_id = p_household_id
      and t.merchant_id = any(v_source_merchant_ids);

    get diagnostics v_transaction_count = row_count;

    update public.merchant_mapping_rules mmr
    set merchant_id = p_destination_merchant_id
    where mmr.household_id = p_household_id
      and mmr.merchant_id = any(v_source_merchant_ids);

    get diagnostics v_mapping_rule_count = row_count;

    update public.review_items ri
    set suggested_merchant_id = p_destination_merchant_id
    where ri.household_id = p_household_id
      and ri.status = 'open'
      and ri.suggested_merchant_id = any(v_source_merchant_ids);

    get diagnostics v_review_suggestion_count = row_count;
  end if;

  perform set_config('app.merchant_group_merge', 'on', true);

  delete from public.merchants m
  where m.household_id = p_household_id
    and m.id = any(v_source_merchant_ids);

  get diagnostics v_deleted_source_count = row_count;

  perform set_config('app.merchant_group_merge', 'off', true);

  destination_merchant_id := p_destination_merchant_id;
  destination_display_name := v_destination_display_name;
  destination_category_id := v_destination_category_id;
  destination_subcategory_id := v_destination_subcategory_id;
  moved_transaction_count := v_transaction_count;
  moved_alias_count := v_alias_count;
  moved_mapping_rule_count := v_mapping_rule_count;
  moved_review_suggestion_count := v_review_suggestion_count;
  deleted_source_merchant_count := v_deleted_source_count;
  category_updated_transaction_count := v_category_transaction_count;
  category_updated_mapping_rule_count := v_category_mapping_rule_count;
  category_updated_review_suggestion_count :=
    v_category_review_suggestion_count;
  return next;
exception
  when unique_violation then
    raise exception 'A merchant group with this name already exists.';
end;
$$;

revoke execute on function public.rename_household_merchant(uuid, uuid, text)
  from public, anon;
revoke execute on function public.merge_household_merchants(
  uuid,
  uuid,
  text,
  uuid[],
  text
) from public, anon;

grant execute on function public.rename_household_merchant(uuid, uuid, text)
  to authenticated, service_role;
grant execute on function public.merge_household_merchants(
  uuid,
  uuid,
  text,
  uuid[],
  text
) to authenticated, service_role;
