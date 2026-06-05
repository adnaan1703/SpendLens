alter table public.merchant_mapping_rules
  add column notes text,
  add constraint merchant_mapping_rules_id_household_key unique (id, household_id);

alter table public.review_items
  add constraint review_items_id_household_key unique (id, household_id);

alter table public.transactions
  add column classification_rule_id uuid,
  add column classification_review_item_id uuid,
  add column classification_updated_by uuid references public.profiles (id) on delete set null,
  add column classification_updated_at timestamptz,
  add column classification_note text,
  add constraint transactions_classification_rule_household_fk foreign key (classification_rule_id, household_id)
    references public.merchant_mapping_rules (id, household_id) on delete set null (classification_rule_id),
  add constraint transactions_classification_review_item_household_fk foreign key (classification_review_item_id, household_id)
    references public.review_items (id, household_id) on delete set null (classification_review_item_id);

create unique index merchants_household_lower_display_name_key
  on public.merchants (household_id, lower(display_name));

create unique index merchant_mapping_rules_manual_exact_match_key
  on public.merchant_mapping_rules (household_id, lower(pattern), match_type)
  where confidence = 'manual';

create index transactions_classification_rule_id_idx
  on public.transactions (classification_rule_id)
  where classification_rule_id is not null;

create index transactions_classification_review_item_id_idx
  on public.transactions (classification_review_item_id)
  where classification_review_item_id is not null;

create or replace function public.normalize_merchant_name(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
    btrim(
      regexp_replace(
        lower(replace(coalesce(value, ''), '&', ' and ')),
        '[^a-z0-9]+',
        ' ',
        'g'
      )
    ),
    '\s+',
    ' ',
    'g'
  );
$$;

create or replace function public.merchant_rule_matches(
  match_type text,
  pattern text,
  normalized_statement_merchant text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case match_type
    when 'exact' then normalized_statement_merchant = pattern
    when 'contains' then normalized_statement_merchant like '%' || pattern || '%'
    when 'prefix' then normalized_statement_merchant like pattern || '%'
    when 'suffix' then normalized_statement_merchant like '%' || pattern
    when 'regex' then normalized_statement_merchant ~ pattern
    else false
  end;
$$;

create or replace function public.match_merchant_mapping_rule(
  p_household_id uuid,
  p_statement_merchant text
)
returns table (
  rule_id uuid,
  merchant_id uuid,
  category_id uuid,
  subcategory_id uuid,
  confidence public.confidence
)
language sql
stable
security invoker
set search_path = ''
as $$
  with normalized_input as (
    select public.normalize_merchant_name(p_statement_merchant) as normalized_name
  )
  select
    mmr.id as rule_id,
    mmr.merchant_id,
    mmr.category_id,
    mmr.subcategory_id,
    mmr.confidence
  from public.merchant_mapping_rules mmr
  cross join normalized_input ni
  where mmr.household_id = p_household_id
    and mmr.apply_to_future
    and public.merchant_rule_matches(mmr.match_type, mmr.pattern, ni.normalized_name)
  order by
    case mmr.match_type
      when 'exact' then 0
      when 'prefix' then 1
      when 'suffix' then 2
      when 'contains' then 3
      else 4
    end,
    mmr.priority,
    mmr.created_at desc
  limit 1;
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
  v_profile_id uuid;
  v_statement_merchant text;
  v_normalized_statement_merchant text;
  v_merchant_group text;
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
    raise exception 'A signed-in profile is required to apply a merchant correction.';
  end if;

  if p_household_id not in (select app_private.write_household_ids()) then
    raise exception 'You do not have permission to correct merchant mappings for this household.';
  end if;

  if v_merchant_group is null then
    raise exception 'Merchant group is required.';
  end if;

  select
    t.statement_merchant,
    t.normalized_statement_merchant
  into v_statement_merchant, v_normalized_statement_merchant
  from public.review_items ri
  join public.transactions t
    on t.id = ri.transaction_id
   and t.household_id = ri.household_id
  where ri.id = p_review_item_id
    and ri.household_id = p_household_id
    and ri.status = 'open';

  if not found then
    raise exception 'Open review item not found.';
  end if;

  v_normalized_statement_merchant := public.normalize_merchant_name(
    coalesce(v_normalized_statement_merchant, v_statement_merchant)
  );

  if v_normalized_statement_merchant is null or v_normalized_statement_merchant = '' then
    raise exception 'Review item transaction has no statement merchant to match.';
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
      'manual',
      v_notes
    )
    returning id into v_merchant_id;
  else
    update public.merchants
    set display_name = v_merchant_group,
        category_id = p_category_id,
        subcategory_id = p_subcategory_id,
        confidence = 'manual',
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
    and mmr.confidence = 'manual'
    and mmr.match_type = 'exact'
    and lower(mmr.pattern) = lower(v_normalized_statement_merchant)
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
      'manual',
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
        confidence = 'manual',
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
      confidence = 'manual',
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

create or replace view public.v_review_queue
with (security_invoker = true)
as
select
  ri.id,
  ri.household_id,
  ri.transaction_id,
  ri.reason,
  ri.status,
  ri.created_at,
  t.transaction_date,
  t.statement_merchant,
  t.normalized_statement_merchant,
  t.amount,
  t.net_expense,
  t.confidence as transaction_confidence,
  ri.suggested_merchant_id,
  sm.display_name as suggested_merchant_name,
  ri.suggested_category_id,
  sc.name as suggested_category_name,
  ri.suggested_subcategory_id,
  ssc.name as suggested_subcategory_name,
  t.merchant_id as current_merchant_id,
  cm.display_name as current_merchant_name,
  t.category_id as current_category_id,
  cc.name as current_category_name,
  t.subcategory_id as current_subcategory_id,
  csc.name as current_subcategory_name
from public.review_items ri
left join public.transactions t on t.id = ri.transaction_id and t.household_id = ri.household_id
left join public.merchants sm on sm.id = ri.suggested_merchant_id and sm.household_id = ri.household_id
left join public.categories sc on sc.id = ri.suggested_category_id and sc.household_id = ri.household_id
left join public.subcategories ssc on ssc.id = ri.suggested_subcategory_id and ssc.household_id = ri.household_id
left join public.merchants cm on cm.id = t.merchant_id and cm.household_id = t.household_id
left join public.categories cc on cc.id = t.category_id and cc.household_id = t.household_id
left join public.subcategories csc on csc.id = t.subcategory_id and csc.household_id = t.household_id
where ri.status = 'open';

revoke execute on function public.normalize_merchant_name(text) from public, anon, authenticated;
revoke execute on function public.merchant_rule_matches(text, text, text) from public, anon, authenticated;
revoke execute on function public.match_merchant_mapping_rule(uuid, text) from public, anon, authenticated;
revoke execute on function public.apply_merchant_review_correction(uuid, uuid, text, uuid, uuid, text) from public, anon, authenticated;

grant execute on function public.normalize_merchant_name(text) to authenticated, service_role;
grant execute on function public.merchant_rule_matches(text, text, text) to authenticated, service_role;
grant execute on function public.match_merchant_mapping_rule(uuid, text) to authenticated, service_role;
grant execute on function public.apply_merchant_review_correction(uuid, uuid, text, uuid, uuid, text) to authenticated, service_role;
