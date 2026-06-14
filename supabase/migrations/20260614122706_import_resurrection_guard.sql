drop function if exists public.ingest_gmail_transaction(uuid, jsonb, jsonb, text);

create or replace function public.ingest_gmail_transaction(
  p_mailbox_id uuid,
  p_message_metadata jsonb,
  p_parsed_transaction jsonb,
  p_source_fingerprint text
)
returns table (
  gmail_transaction_id uuid,
  inserted boolean,
  review_item_id uuid,
  matched_mapping boolean,
  suppressed boolean,
  suppression_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mailbox public.linked_mailboxes;
  v_source_account_id uuid;
  v_statement_merchant text;
  v_normalized_merchant text;
  v_transaction_type public.transaction_type;
  v_amount numeric(14,2);
  v_abs_amount numeric(14,2);
  v_gross_spend numeric(14,2) := 0;
  v_refund_amount numeric(14,2) := 0;
  v_net_expense numeric(14,2) := 0;
  v_category_id uuid;
  v_subcategory_id uuid;
  v_merchant_id uuid;
  v_rule_id uuid;
  v_confidence public.confidence;
  v_transaction_id uuid;
  v_review_item_id uuid;
  v_existed boolean;
  v_source_hint jsonb := coalesce(p_parsed_transaction->'source_account_hint', '{}'::jsonb);
  v_message_id text := nullif(btrim(p_message_metadata->>'id'), '');
  v_thread_id text := nullif(btrim(p_message_metadata->>'threadId'), '');
  v_received_at timestamptz := nullif(btrim(p_message_metadata->>'receivedAt'), '')::timestamptz;
  v_source_reference text := nullif(btrim(p_parsed_transaction->>'source_reference'), '');
  v_parser_name text := nullif(btrim(p_parsed_transaction->>'parser_name'), '');
  v_parser_version text := nullif(btrim(p_parsed_transaction->>'parser_version'), '');
  v_fingerprint text := nullif(btrim(p_source_fingerprint), '');
begin
  if v_fingerprint is null then
    raise exception 'Gmail transaction fingerprint is required.';
  end if;

  select *
  into v_mailbox
  from public.linked_mailboxes lm
  where lm.id = p_mailbox_id
    and lm.provider = 'gmail'
    and lm.is_active;

  if not found then
    raise exception 'Active Gmail mailbox not found.';
  end if;

  if exists (
    select 1
    from public.deleted_transaction_sources dts
    where dts.household_id = v_mailbox.household_id
      and dts.source_type = 'gmail'
      and dts.source_fingerprint = v_fingerprint
  ) then
    return query
    select
      null::uuid,
      false,
      null::uuid,
      false,
      true,
      'deleted_transaction_source'::text;
    return;
  end if;

  v_statement_merchant := nullif(btrim(p_parsed_transaction->>'statement_merchant'), '');
  if v_statement_merchant is null then
    raise exception 'Parsed Gmail transaction is missing statement merchant.';
  end if;

  v_normalized_merchant := public.normalize_merchant_name(v_statement_merchant);
  v_transaction_type := coalesce(
    nullif(btrim(p_parsed_transaction->>'transaction_type'), '')::public.transaction_type,
    'unknown'
  );
  v_amount := coalesce((p_parsed_transaction->>'amount')::numeric, 0)::numeric(14,2);
  v_abs_amount := abs(v_amount)::numeric(14,2);

  if v_transaction_type = 'debit_spend' then
    v_gross_spend := v_abs_amount;
    v_net_expense := v_abs_amount;
    v_amount := v_abs_amount;
  elsif v_transaction_type = 'refund_reversal' then
    v_refund_amount := v_abs_amount;
    v_net_expense := -v_abs_amount;
    v_amount := -v_abs_amount;
  else
    v_amount := 0;
  end if;

  select sa.id
  into v_source_account_id
  from public.source_accounts sa
  where sa.household_id = v_mailbox.household_id
    and sa.type = coalesce(nullif(v_source_hint->>'type', ''), 'credit_card')::public.source_account_type
    and coalesce(sa.institution_name, '') = coalesce(nullif(v_source_hint->>'institution_name', ''), '')
    and coalesce(sa.masked_identifier, '') = coalesce(nullif(v_source_hint->>'masked_identifier', ''), '')
  order by sa.created_at
  limit 1;

  if v_source_account_id is null then
    insert into public.source_accounts (
      household_id,
      type,
      display_name,
      institution_name,
      masked_identifier,
      cardholder_name
    )
    values (
      v_mailbox.household_id,
      coalesce(nullif(v_source_hint->>'type', ''), 'credit_card')::public.source_account_type,
      coalesce(
        nullif(v_source_hint->>'display_name', ''),
        'Gmail credit card ending ' || coalesce(nullif(v_source_hint->>'masked_identifier', ''), 'unknown')
      ),
      nullif(v_source_hint->>'institution_name', ''),
      nullif(v_source_hint->>'masked_identifier', ''),
      nullif(v_source_hint->>'cardholder_name', '')
    )
    returning id into v_source_account_id;
  end if;

  select
    ma.merchant_id,
    m.category_id,
    m.subcategory_id,
    m.confidence
  into
    v_merchant_id,
    v_category_id,
    v_subcategory_id,
    v_confidence
  from public.merchant_aliases ma
  join public.merchants m
    on m.id = ma.merchant_id
   and m.household_id = ma.household_id
  where ma.household_id = v_mailbox.household_id
    and ma.normalized_name = v_normalized_merchant
  limit 1;

  if v_merchant_id is null then
    select
      rule_id,
      merchant_id,
      category_id,
      subcategory_id,
      confidence
    into
      v_rule_id,
      v_merchant_id,
      v_category_id,
      v_subcategory_id,
      v_confidence
    from public.match_merchant_mapping_rule(v_mailbox.household_id, v_statement_merchant)
    limit 1;
  end if;

  v_confidence := coalesce(v_confidence, 'low');

  select exists (
    select 1
    from public.transactions t
    where t.household_id = v_mailbox.household_id
      and t.source_fingerprint = v_fingerprint
  )
  into v_existed;

  insert into public.transactions (
    household_id,
    source_account_id,
    source_type,
    occurred_at,
    transaction_date,
    transaction_time,
    cardholder_name,
    statement_merchant,
    normalized_statement_merchant,
    merchant_id,
    category_id,
    subcategory_id,
    transaction_type,
    amount,
    gross_spend,
    refund_amount,
    net_expense,
    currency_code,
    confidence,
    notes,
    source_fingerprint,
    classification_rule_id
  )
  values (
    v_mailbox.household_id,
    v_source_account_id,
    'gmail',
    (
      (p_parsed_transaction->>'transaction_date')::date
      + coalesce(nullif(p_parsed_transaction->>'transaction_time', '')::time, time '00:00')
    ) at time zone 'Asia/Kolkata',
    (p_parsed_transaction->>'transaction_date')::date,
    nullif(p_parsed_transaction->>'transaction_time', '')::time,
    nullif(v_source_hint->>'cardholder_name', ''),
    v_statement_merchant,
    v_normalized_merchant,
    v_merchant_id,
    v_category_id,
    v_subcategory_id,
    v_transaction_type,
    v_amount,
    v_gross_spend,
    v_refund_amount,
    v_net_expense,
    coalesce(nullif(p_parsed_transaction->>'currency_code', ''), 'INR'),
    v_confidence,
    nullif(btrim(p_parsed_transaction->>'notes'), ''),
    v_fingerprint,
    v_rule_id
  )
  on conflict (household_id, source_fingerprint)
  do update
    set
      source_account_id = excluded.source_account_id,
      occurred_at = excluded.occurred_at,
      transaction_date = excluded.transaction_date,
      transaction_time = excluded.transaction_time,
      cardholder_name = excluded.cardholder_name,
      statement_merchant = excluded.statement_merchant,
      normalized_statement_merchant = excluded.normalized_statement_merchant,
      merchant_id = excluded.merchant_id,
      category_id = excluded.category_id,
      subcategory_id = excluded.subcategory_id,
      transaction_type = excluded.transaction_type,
      amount = excluded.amount,
      gross_spend = excluded.gross_spend,
      refund_amount = excluded.refund_amount,
      net_expense = excluded.net_expense,
      currency_code = excluded.currency_code,
      confidence = excluded.confidence,
      notes = excluded.notes,
      classification_rule_id = excluded.classification_rule_id,
      updated_at = now()
  returning id into v_transaction_id;

  insert into public.transaction_sources (
    household_id,
    transaction_id,
    source_type,
    source_message_id,
    source_thread_id,
    source_reference,
    source_received_at,
    parser_name,
    parser_version,
    parse_status,
    diagnostics
  )
  values (
    v_mailbox.household_id,
    v_transaction_id,
    'gmail',
    v_message_id,
    v_thread_id,
    v_source_reference,
    v_received_at,
    v_parser_name,
    v_parser_version,
    'parsed',
    coalesce(p_parsed_transaction->'diagnostics', '{}'::jsonb)
  )
  on conflict (
    household_id,
    source_message_id,
    parser_name,
    parser_version
  )
  where source_type = 'gmail' and source_message_id is not null
  do update
    set
      transaction_id = excluded.transaction_id,
      source_thread_id = excluded.source_thread_id,
      source_reference = excluded.source_reference,
      source_received_at = excluded.source_received_at,
      parse_status = excluded.parse_status,
      diagnostics = excluded.diagnostics;

  if v_merchant_id is null or v_category_id is null or v_confidence in ('low', 'medium') then
    insert into public.review_items (
      household_id,
      transaction_id,
      reason,
      suggested_merchant_id,
      suggested_category_id,
      suggested_subcategory_id
    )
    values (
      v_mailbox.household_id,
      v_transaction_id,
      case
        when v_merchant_id is null then 'Gmail parser found an unknown merchant.'
        when v_category_id is null then 'Gmail parser could not assign a category.'
        else 'Gmail parser imported a transaction with non-high classification confidence.'
      end,
      v_merchant_id,
      v_category_id,
      v_subcategory_id
    )
    on conflict (household_id, transaction_id, reason)
    where status = 'open' and transaction_id is not null
    do update
      set
        suggested_merchant_id = excluded.suggested_merchant_id,
        suggested_category_id = excluded.suggested_category_id,
        suggested_subcategory_id = excluded.suggested_subcategory_id
    returning id into v_review_item_id;
  end if;

  return query
  select
    v_transaction_id,
    not v_existed,
    v_review_item_id,
    v_merchant_id is not null or v_rule_id is not null,
    false,
    null::text;
end;
$$;

comment on function public.ingest_gmail_transaction(uuid, jsonb, jsonb, text) is
  'Service-role Gmail transaction ingestion boundary. Tombstoned fingerprints return a suppressed handled result without recreating transaction rows.';

revoke execute on function public.ingest_gmail_transaction(uuid, jsonb, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.ingest_gmail_transaction(uuid, jsonb, jsonb, text)
  to service_role;
