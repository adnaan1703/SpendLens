create or replace function public.apply_transaction_metadata_correction(
  p_household_id uuid,
  p_transaction_id uuid,
  p_merchant_group text,
  p_category_id uuid,
  p_subcategory_id uuid,
  p_confidence public.confidence default 'manual',
  p_notes text default null,
  p_review_item_id uuid default null
)
returns table (
  rule_id uuid,
  merchant_id uuid,
  category_id uuid,
  subcategory_id uuid,
  updated_transaction_count integer,
  resolved_review_item_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_statement_merchant text;
  v_normalized_statement_merchant text;
  v_merchant_group text;
  v_confidence public.confidence := coalesce(p_confidence, 'manual'::public.confidence);
  v_notes text;
  v_now timestamptz := now();
  v_rule_id uuid;
  v_merchant_id uuid;
  v_updated_count integer := 0;
  v_resolved_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();
  v_merchant_group := nullif(btrim(p_merchant_group), '');
  v_notes := nullif(btrim(p_notes), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to edit transaction metadata.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to edit transaction metadata for this household.';
  end if;

  if v_merchant_group is null then
    raise exception 'Merchant group is required.';
  end if;

  select
    t.statement_merchant,
    t.normalized_statement_merchant
  into v_statement_merchant, v_normalized_statement_merchant
  from public.transactions t
  where t.id = p_transaction_id
    and t.household_id = p_household_id
  for update;

  if not found then
    raise exception 'Transaction not found.';
  end if;

  if p_review_item_id is not null then
    perform 1
    from public.review_items ri
    where ri.id = p_review_item_id
      and ri.household_id = p_household_id
      and ri.transaction_id = p_transaction_id
      and ri.status = 'open'
    for update;

    if not found then
      raise exception 'Open review item not found for this transaction.';
    end if;
  end if;

  v_normalized_statement_merchant := public.normalize_merchant_name(
    coalesce(nullif(v_normalized_statement_merchant, ''), v_statement_merchant)
  );

  if v_normalized_statement_merchant is null or v_normalized_statement_merchant = '' then
    raise exception 'Transaction has no statement merchant to match.';
  end if;

  perform 1
  from public.categories c
  where c.id = p_category_id
    and c.household_id = p_household_id;

  if not found then
    raise exception 'Category does not belong to this household.';
  end if;

  perform 1
  from public.subcategories sc
  where sc.id = p_subcategory_id
    and sc.category_id = p_category_id
    and sc.household_id = p_household_id;

  if not found then
    raise exception 'Subcategory does not belong to the selected category.';
  end if;

  select m.id
  into v_merchant_id
  from public.merchants m
  where m.household_id = p_household_id
    and lower(m.display_name) = lower(v_merchant_group)
  limit 1
  for update;

  if v_merchant_id is null then
    insert into public.merchants (
      household_id,
      display_name,
      category_id,
      subcategory_id,
      confidence,
      notes
    )
    values (
      p_household_id,
      v_merchant_group,
      p_category_id,
      p_subcategory_id,
      v_confidence,
      v_notes
    )
    returning id into v_merchant_id;
  else
    update public.merchants
    set display_name = v_merchant_group,
        category_id = p_category_id,
        subcategory_id = p_subcategory_id,
        confidence = v_confidence,
        notes = coalesce(v_notes, notes)
    where id = v_merchant_id
      and household_id = p_household_id;
  end if;

  insert into public.merchant_aliases (
    household_id,
    merchant_id,
    raw_name,
    normalized_name,
    source_type,
    first_seen_at,
    last_seen_at
  )
  values (
    p_household_id,
    v_merchant_id,
    v_statement_merchant,
    v_normalized_statement_merchant,
    'manual',
    v_now,
    v_now
  )
  on conflict (household_id, normalized_name) do update
    set merchant_id = excluded.merchant_id,
        raw_name = excluded.raw_name,
        source_type = excluded.source_type,
        first_seen_at = coalesce(
          least(public.merchant_aliases.first_seen_at, excluded.first_seen_at),
          public.merchant_aliases.first_seen_at,
          excluded.first_seen_at
        ),
        last_seen_at = coalesce(
          greatest(public.merchant_aliases.last_seen_at, excluded.last_seen_at),
          public.merchant_aliases.last_seen_at,
          excluded.last_seen_at
        );

  select mmr.id
  into v_rule_id
  from public.merchant_mapping_rules mmr
  where mmr.household_id = p_household_id
    and mmr.match_type = 'exact'
    and lower(mmr.pattern) = lower(v_normalized_statement_merchant)
  order by mmr.created_at desc
  limit 1
  for update;

  if v_rule_id is null then
    insert into public.merchant_mapping_rules (
      household_id,
      pattern,
      match_type,
      merchant_id,
      category_id,
      subcategory_id,
      priority,
      confidence,
      apply_to_future,
      created_by,
      notes
    )
    values (
      p_household_id,
      v_normalized_statement_merchant,
      'exact',
      v_merchant_id,
      p_category_id,
      p_subcategory_id,
      10,
      v_confidence,
      true,
      v_profile_id,
      v_notes
    )
    returning id into v_rule_id;
  else
    update public.merchant_mapping_rules
    set merchant_id = v_merchant_id,
        category_id = p_category_id,
        subcategory_id = p_subcategory_id,
        priority = 10,
        confidence = v_confidence,
        apply_to_future = true,
        created_by = coalesce(created_by, v_profile_id),
        notes = v_notes
    where id = v_rule_id
      and household_id = p_household_id;
  end if;

  update public.transactions t
  set merchant_id = v_merchant_id,
      category_id = p_category_id,
      subcategory_id = p_subcategory_id,
      confidence = v_confidence,
      notes = v_notes,
      classification_rule_id = v_rule_id,
      classification_review_item_id = p_review_item_id,
      classification_updated_by = v_profile_id,
      classification_updated_at = v_now,
      classification_note = v_notes
  where t.household_id = p_household_id
    and t.normalized_statement_merchant = v_normalized_statement_merchant;

  get diagnostics v_updated_count = row_count;

  update public.review_items ri
  set status = 'resolved',
      resolved_by = v_profile_id,
      resolved_at = v_now
  where ri.household_id = p_household_id
    and ri.status = 'open'
    and exists (
      select 1
      from public.transactions t
      where t.id = ri.transaction_id
        and t.household_id = ri.household_id
        and t.normalized_statement_merchant = v_normalized_statement_merchant
    );

  get diagnostics v_resolved_count = row_count;

  rule_id := v_rule_id;
  merchant_id := v_merchant_id;
  category_id := p_category_id;
  subcategory_id := p_subcategory_id;
  updated_transaction_count := v_updated_count;
  resolved_review_item_count := v_resolved_count;
  return next;
end;
$$;

create or replace function public.apply_merchant_review_correction(
  p_household_id uuid,
  p_review_item_id uuid,
  p_merchant_group text,
  p_category_id uuid,
  p_subcategory_id uuid,
  p_notes text default null
)
returns table (
  rule_id uuid,
  merchant_id uuid,
  category_id uuid,
  subcategory_id uuid,
  updated_transaction_count integer,
  resolved_review_item_count integer
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_transaction_id uuid;
begin
  select ri.transaction_id
  into v_transaction_id
  from public.review_items ri
  where ri.id = p_review_item_id
    and ri.household_id = p_household_id
    and ri.status = 'open';

  if not found then
    raise exception 'Open review item not found.';
  end if;

  return query
  select *
  from public.apply_transaction_metadata_correction(
    p_household_id => p_household_id,
    p_transaction_id => v_transaction_id,
    p_merchant_group => p_merchant_group,
    p_category_id => p_category_id,
    p_subcategory_id => p_subcategory_id,
    p_confidence => 'manual',
    p_notes => p_notes,
    p_review_item_id => p_review_item_id
  );
end;
$$;

revoke execute on function public.apply_transaction_metadata_correction(
  uuid,
  uuid,
  text,
  uuid,
  uuid,
  public.confidence,
  text,
  uuid
) from public, anon, authenticated;
revoke execute on function public.apply_merchant_review_correction(
  uuid,
  uuid,
  text,
  uuid,
  uuid,
  text
) from public, anon, authenticated;

grant execute on function public.apply_transaction_metadata_correction(
  uuid,
  uuid,
  text,
  uuid,
  uuid,
  public.confidence,
  text,
  uuid
) to authenticated, service_role;
grant execute on function public.apply_merchant_review_correction(
  uuid,
  uuid,
  text,
  uuid,
  uuid,
  text
) to authenticated, service_role;
