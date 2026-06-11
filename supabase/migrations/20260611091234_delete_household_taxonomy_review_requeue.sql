drop policy if exists "categories_delete_admins" on public.categories;
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
      from public.category_caps cc
      where cc.household_id = categories.household_id
        and cc.category_id = categories.id
    )
  );

drop policy if exists "subcategories_delete_admins" on public.subcategories;
create policy "subcategories_delete_writers"
  on public.subcategories
  for delete
  to authenticated
  using (
    household_id in (select app_private.write_household_ids())
    and not exists (
      select 1
      from public.transactions t
      where t.household_id = subcategories.household_id
        and t.category_id = subcategories.category_id
        and t.subcategory_id = subcategories.id
    )
    and not exists (
      select 1
      from public.merchants m
      where m.household_id = subcategories.household_id
        and m.category_id = subcategories.category_id
        and m.subcategory_id = subcategories.id
    )
    and not exists (
      select 1
      from public.merchant_mapping_rules mmr
      where mmr.household_id = subcategories.household_id
        and mmr.category_id = subcategories.category_id
        and mmr.subcategory_id = subcategories.id
    )
    and not exists (
      select 1
      from public.review_items ri
      where ri.household_id = subcategories.household_id
        and ri.suggested_category_id = subcategories.category_id
        and ri.suggested_subcategory_id = subcategories.id
    )
  );

drop policy if exists "category_caps_delete_admins" on public.category_caps;
create policy "category_caps_delete_writers"
  on public.category_caps
  for delete
  to authenticated
  using (household_id in (select app_private.write_household_ids()));

create or replace function public.delete_household_subcategory(
  p_household_id uuid,
  p_category_id uuid,
  p_subcategory_id uuid
)
returns table (
  deleted_subcategory_id uuid,
  affected_transaction_count integer,
  opened_review_item_count integer,
  cleared_mapping_rule_count integer,
  cleared_merchant_count integer,
  cleared_review_suggestion_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_note text := 'Taxonomy deleted: subcategory removed.';
  v_now timestamptz := now();
  v_affected_count integer := 0;
  v_review_count integer := 0;
  v_mapping_rule_count integer := 0;
  v_merchant_count integer := 0;
  v_review_suggestion_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete subcategories.';
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

  perform 1
  from public.subcategories sc
  where sc.id = p_subcategory_id
    and sc.category_id = p_category_id
    and sc.household_id = p_household_id;

  if not found then
    raise exception 'Subcategory not found for this category.';
  end if;

  select count(*)::integer
  into v_affected_count
  from public.transactions t
  where t.household_id = p_household_id
    and t.category_id = p_category_id
    and t.subcategory_id = p_subcategory_id;

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
    p_category_id,
    null::uuid
  from public.transactions t
  where t.household_id = p_household_id
    and t.category_id = p_category_id
    and t.subcategory_id = p_subcategory_id
  on conflict (household_id, transaction_id, reason)
  where status = 'open' and transaction_id is not null
  do update
    set suggested_merchant_id = excluded.suggested_merchant_id,
        suggested_category_id = excluded.suggested_category_id,
        suggested_subcategory_id = null;

  get diagnostics v_review_count = row_count;

  update public.transactions t
  set subcategory_id = null,
      classification_updated_by = v_profile_id,
      classification_updated_at = v_now,
      classification_note = v_note
  where t.household_id = p_household_id
    and t.category_id = p_category_id
    and t.subcategory_id = p_subcategory_id;

  update public.merchants m
  set subcategory_id = null
  where m.household_id = p_household_id
    and m.category_id = p_category_id
    and m.subcategory_id = p_subcategory_id;

  get diagnostics v_merchant_count = row_count;

  update public.merchant_mapping_rules mmr
  set subcategory_id = null
  where mmr.household_id = p_household_id
    and mmr.category_id = p_category_id
    and mmr.subcategory_id = p_subcategory_id;

  get diagnostics v_mapping_rule_count = row_count;

  update public.review_items ri
  set suggested_subcategory_id = null
  where ri.household_id = p_household_id
    and ri.suggested_category_id = p_category_id
    and ri.suggested_subcategory_id = p_subcategory_id;

  get diagnostics v_review_suggestion_count = row_count;

  delete from public.subcategories sc
  where sc.id = p_subcategory_id
    and sc.category_id = p_category_id
    and sc.household_id = p_household_id;

  deleted_subcategory_id := p_subcategory_id;
  affected_transaction_count := v_affected_count;
  opened_review_item_count := v_review_count;
  cleared_mapping_rule_count := v_mapping_rule_count;
  cleared_merchant_count := v_merchant_count;
  cleared_review_suggestion_count := v_review_suggestion_count;
  return next;
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

  delete from public.category_caps cc
  where cc.household_id = p_household_id
    and cc.category_id = p_category_id;

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

revoke execute on function public.delete_household_subcategory(uuid, uuid, uuid)
  from public, anon;
revoke execute on function public.delete_household_category(uuid, uuid)
  from public, anon;

grant execute on function public.delete_household_subcategory(uuid, uuid, uuid)
  to authenticated, service_role;
grant execute on function public.delete_household_category(uuid, uuid)
  to authenticated, service_role;
