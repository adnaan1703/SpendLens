create or replace function public.merchant_rule_matches(
  match_type text,
  pattern text,
  normalized_statement_merchant text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_normalized_statement text := public.normalize_merchant_name(normalized_statement_merchant);
  v_effective_pattern text;
begin
  if nullif(v_normalized_statement, '') is null then
    return false;
  end if;

  if nullif(btrim(coalesce(pattern, '')), '') is null then
    return false;
  end if;

  case match_type
    when 'exact' then
      v_effective_pattern := public.normalize_merchant_name(pattern);

      if nullif(v_effective_pattern, '') is null then
        return false;
      end if;

      return v_normalized_statement = v_effective_pattern;
    when 'contains' then
      v_effective_pattern := public.normalize_merchant_name(pattern);

      if nullif(v_effective_pattern, '') is null then
        return false;
      end if;

      return v_normalized_statement like '%' || v_effective_pattern || '%';
    when 'prefix' then
      v_effective_pattern := public.normalize_merchant_name(pattern);

      if nullif(v_effective_pattern, '') is null then
        return false;
      end if;

      return v_normalized_statement like v_effective_pattern || '%';
    when 'suffix' then
      v_effective_pattern := public.normalize_merchant_name(pattern);

      if nullif(v_effective_pattern, '') is null then
        return false;
      end if;

      return v_normalized_statement like '%' || v_effective_pattern;
    when 'regex' then
      v_effective_pattern := nullif(btrim(pattern), '');

      if v_effective_pattern is null then
        return false;
      end if;

      begin
        return v_normalized_statement ~ v_effective_pattern;
      exception
        when invalid_regular_expression then
          return false;
      end;
    else
      return false;
  end case;
end;
$$;

create or replace function public.classify_statement_merchant(
  p_household_id uuid,
  p_statement_merchant text
)
returns table (
  rule_id uuid,
  merchant_id uuid,
  merchant_name text,
  category_id uuid,
  category_name text,
  subcategory_id uuid,
  subcategory_name text,
  confidence public.confidence,
  rule_notes text,
  rule_created_by uuid
)
language sql
stable
security invoker
set search_path = ''
as $$
  with matched_rule as (
    select *
    from public.match_merchant_mapping_rule(p_household_id, p_statement_merchant)
    limit 1
  )
  select
    matched_rule.rule_id,
    matched_rule.merchant_id,
    merchants.display_name as merchant_name,
    matched_rule.category_id,
    categories.name as category_name,
    matched_rule.subcategory_id,
    subcategories.name as subcategory_name,
    matched_rule.confidence,
    merchant_mapping_rules.notes as rule_notes,
    merchant_mapping_rules.created_by as rule_created_by
  from matched_rule
  join public.merchant_mapping_rules
    on merchant_mapping_rules.id = matched_rule.rule_id
   and merchant_mapping_rules.household_id = p_household_id
  left join public.merchants
    on merchants.id = matched_rule.merchant_id
   and merchants.household_id = p_household_id
  left join public.categories
    on categories.id = matched_rule.category_id
   and categories.household_id = p_household_id
  left join public.subcategories
    on subcategories.id = matched_rule.subcategory_id
   and subcategories.household_id = p_household_id;
$$;

revoke execute on function public.merchant_rule_matches(text, text, text) from public, anon, authenticated;
revoke execute on function public.classify_statement_merchant(uuid, text) from public, anon, authenticated;

grant execute on function public.merchant_rule_matches(text, text, text) to authenticated, service_role;
grant execute on function public.classify_statement_merchant(uuid, text) to authenticated, service_role;
