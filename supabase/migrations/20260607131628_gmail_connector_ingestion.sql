create extension if not exists supabase_vault with schema vault;

alter table public.linked_mailboxes
  add column if not exists connected_at timestamptz,
  add column if not exists disconnected_at timestamptz,
  add column if not exists last_watch_renewed_at timestamptz,
  add column if not exists last_notification_at timestamptz,
  add column if not exists last_sync_started_at timestamptz,
  add column if not exists last_sync_status public.job_status not null default 'queued',
  add column if not exists has_oauth_secret boolean not null default false,
  add column if not exists provider_subject text,
  add column if not exists scope text,
  add column if not exists token_expires_at timestamptz,
  add constraint linked_mailboxes_oauth_secret_ref_nonempty
    check (oauth_secret_ref is null or btrim(oauth_secret_ref) <> ''),
  add constraint linked_mailboxes_gmail_history_id_nonempty
    check (gmail_history_id is null or btrim(gmail_history_id) <> ''),
  add constraint linked_mailboxes_provider_subject_nonempty
    check (provider_subject is null or btrim(provider_subject) <> '');

create unique index linked_mailboxes_active_gmail_email_key
  on public.linked_mailboxes (household_id, provider, lower(email))
  where is_active;

create table public.gmail_oauth_states (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  state_hash text not null unique,
  redirect_after text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint gmail_oauth_states_state_hash_nonempty check (btrim(state_hash) <> ''),
  constraint gmail_oauth_states_expires_after_created check (expires_at > created_at)
);

create table public.ingestion_jobs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  linked_mailbox_id uuid,
  source_type public.source_type not null default 'gmail',
  job_type text not null,
  status public.job_status not null default 'queued',
  idempotency_key text not null,
  priority integer not null default 100,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  run_after timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  error_message text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ingestion_jobs_mailbox_household_fk foreign key (linked_mailbox_id, household_id)
    references public.linked_mailboxes (id, household_id) on delete cascade,
  constraint ingestion_jobs_gmail_only check (source_type = 'gmail'),
  constraint ingestion_jobs_type_supported check (
    job_type in ('gmail_sync', 'gmail_backfill', 'gmail_watch_renewal')
  ),
  constraint ingestion_jobs_idempotency_key_nonempty check (btrim(idempotency_key) <> ''),
  constraint ingestion_jobs_attempts_shape check (
    attempts >= 0 and max_attempts > 0 and attempts <= max_attempts
  ),
  constraint ingestion_jobs_completion_shape check (
    (status in ('queued', 'processing') and completed_at is null)
    or status in ('completed', 'failed', 'cancelled')
  )
);

create trigger set_ingestion_jobs_updated_at
  before update on public.ingestion_jobs
  for each row
  execute function app_private.set_updated_at();

alter table public.gmail_oauth_states enable row level security;
alter table public.ingestion_jobs enable row level security;

create index gmail_oauth_states_expiry_idx
  on public.gmail_oauth_states (expires_at)
  where consumed_at is null;
create index ingestion_jobs_due_idx
  on public.ingestion_jobs (status, run_after, priority, created_at)
  where status = 'queued';
create unique index ingestion_jobs_mailbox_idempotency_key
  on public.ingestion_jobs (linked_mailbox_id, job_type, idempotency_key)
  where linked_mailbox_id is not null;
create unique index transaction_sources_gmail_message_parser_key
  on public.transaction_sources (
    household_id,
    source_message_id,
    parser_name,
    parser_version
  )
  where source_type = 'gmail' and source_message_id is not null;
create unique index review_items_open_transaction_reason_key
  on public.review_items (household_id, transaction_id, reason)
  where status = 'open' and transaction_id is not null;

create or replace view public.v_linked_mailbox_status
with (security_invoker = true)
as
select
  lm.id,
  lm.household_id,
  lm.profile_id,
  lm.email,
  lm.provider,
  lm.gmail_history_id,
  lm.watch_expires_at,
  lm.last_sync_at,
  lm.last_error,
  lm.is_active,
  lm.connected_at,
  lm.disconnected_at,
  lm.last_watch_renewed_at,
  lm.last_notification_at,
  lm.last_sync_started_at,
  lm.last_sync_status,
  lm.scope,
  lm.created_at,
  lm.updated_at,
  case
    when not lm.is_active then 'disconnected'
    when not lm.has_oauth_secret then 'needs_reconnect'
    when lm.last_error is not null then 'error'
    when lm.watch_expires_at is null then 'watch_pending'
    when lm.watch_expires_at <= now() then 'watch_expired'
    else 'connected'
  end as connector_status,
  coalesce(j.queued_job_count, 0) as queued_job_count,
  j.latest_job_error
from public.linked_mailboxes lm
left join lateral (
  select
    count(*) filter (where status = 'queued')::integer as queued_job_count,
    (
      array_agg(error_message order by updated_at desc)
        filter (where status = 'failed' and error_message is not null)
    )[1] as latest_job_error
  from public.ingestion_jobs ij
  where ij.linked_mailbox_id = lm.id
) j on true;

create or replace function public.upsert_gmail_mailbox(
  p_household_id uuid,
  p_profile_id uuid,
  p_email text,
  p_refresh_token text,
  p_provider_subject text,
  p_scope text,
  p_gmail_history_id text,
  p_watch_expires_at timestamptz,
  p_token_expires_at timestamptz
)
returns table (
  id uuid,
  household_id uuid,
  profile_id uuid,
  email text,
  gmail_history_id text,
  watch_expires_at timestamptz,
  is_active boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(nullif(btrim(p_email), ''));
  v_refresh_token text := nullif(btrim(p_refresh_token), '');
  v_mailbox public.linked_mailboxes;
  v_secret_ref uuid;
  v_secret_name text;
  v_now timestamptz := now();
begin
  if v_email is null then
    raise exception 'Gmail email is required.';
  end if;

  select *
  into v_mailbox
  from public.linked_mailboxes lm
  where lm.household_id = p_household_id
    and lm.profile_id = p_profile_id
    and lm.provider = 'gmail'
    and lower(lm.email) = v_email
  order by lm.is_active desc, lm.created_at desc
  limit 1;

  if not found then
    insert into public.linked_mailboxes (
      household_id,
      profile_id,
      email,
      provider,
      is_active,
      connected_at
    )
    values (
      p_household_id,
      p_profile_id,
      v_email,
      'gmail',
      true,
      v_now
    )
    returning * into v_mailbox;
  end if;

  if v_refresh_token is null and v_mailbox.oauth_secret_ref is null then
    raise exception 'Google did not return a refresh token for this mailbox.';
  end if;

  if v_refresh_token is not null then
    v_secret_name := 'gmail_refresh_token:' || v_mailbox.id::text;

    if v_mailbox.oauth_secret_ref is not null then
      v_secret_ref := v_mailbox.oauth_secret_ref::uuid;
      perform vault.update_secret(
        v_secret_ref,
        v_refresh_token,
        v_secret_name,
        'SpendLens Gmail refresh token for mailbox ' || v_mailbox.id::text,
        null
      );
    else
      select vault.create_secret(
        v_refresh_token,
        v_secret_name,
        'SpendLens Gmail refresh token for mailbox ' || v_mailbox.id::text,
        null
      )
      into v_secret_ref;
    end if;
  elsif v_mailbox.oauth_secret_ref is not null then
    v_secret_ref := v_mailbox.oauth_secret_ref::uuid;
  end if;

  update public.linked_mailboxes lm
  set
    email = v_email,
    oauth_secret_ref = v_secret_ref::text,
    has_oauth_secret = v_secret_ref is not null,
    gmail_history_id = nullif(btrim(p_gmail_history_id), ''),
    watch_expires_at = p_watch_expires_at,
    last_watch_renewed_at = v_now,
    last_error = null,
    is_active = true,
    connected_at = coalesce(lm.connected_at, v_now),
    disconnected_at = null,
    last_sync_status = 'queued',
    provider_subject = nullif(btrim(p_provider_subject), ''),
    scope = nullif(btrim(p_scope), ''),
    token_expires_at = p_token_expires_at
  where lm.id = v_mailbox.id
  returning * into v_mailbox;

  if v_mailbox.gmail_history_id is not null then
    insert into public.ingestion_jobs (
      household_id,
      linked_mailbox_id,
      job_type,
      idempotency_key,
      payload
    )
    values (
      v_mailbox.household_id,
      v_mailbox.id,
      'gmail_backfill',
      'initial:' || v_mailbox.gmail_history_id,
      jsonb_build_object(
        'reason', 'initial_connector_setup',
        'gmailHistoryId', v_mailbox.gmail_history_id
      )
    )
    on conflict (linked_mailbox_id, job_type, idempotency_key)
    where linked_mailbox_id is not null
    do update
      set updated_at = now(),
          status = case
            when public.ingestion_jobs.status = 'completed' then public.ingestion_jobs.status
            else 'queued'::public.job_status
          end,
          payload = public.ingestion_jobs.payload || excluded.payload;
  end if;

  return query
  select
    v_mailbox.id,
    v_mailbox.household_id,
    v_mailbox.profile_id,
    v_mailbox.email,
    v_mailbox.gmail_history_id,
    v_mailbox.watch_expires_at,
    v_mailbox.is_active;
end;
$$;

create or replace function public.disconnect_gmail_mailbox(p_mailbox_id uuid)
returns table (
  id uuid,
  household_id uuid,
  email text,
  is_active boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mailbox public.linked_mailboxes;
  v_secret_ref uuid;
begin
  select *
  into v_mailbox
  from public.linked_mailboxes lm
  where lm.id = p_mailbox_id
    and lm.provider = 'gmail';

  if not found then
    raise exception 'Gmail mailbox not found.';
  end if;

  if v_mailbox.oauth_secret_ref is not null then
    v_secret_ref := v_mailbox.oauth_secret_ref::uuid;
    perform vault.update_secret(
      v_secret_ref,
      '',
      'gmail_refresh_token:' || v_mailbox.id::text,
      'Disconnected SpendLens Gmail refresh token for mailbox ' || v_mailbox.id::text,
      null
    );
  end if;

  update public.linked_mailboxes lm
  set
    oauth_secret_ref = null,
    has_oauth_secret = false,
    is_active = false,
    disconnected_at = now(),
    last_error = null,
    last_sync_status = 'cancelled'
  where lm.id = v_mailbox.id
  returning lm.* into v_mailbox;

  update public.ingestion_jobs
  set
    status = 'cancelled',
    completed_at = now(),
    error_message = 'Mailbox disconnected.'
  where linked_mailbox_id = v_mailbox.id
    and status in ('queued', 'processing');

  return query
  select v_mailbox.id, v_mailbox.household_id, v_mailbox.email, v_mailbox.is_active;
end;
$$;

create or replace function public.get_gmail_refresh_token(p_mailbox_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret_ref text;
  v_token text;
begin
  select oauth_secret_ref
  into v_secret_ref
  from public.linked_mailboxes
  where public.linked_mailboxes.id = p_mailbox_id
    and public.linked_mailboxes.provider = 'gmail'
    and public.linked_mailboxes.is_active;

  if v_secret_ref is null then
    raise exception 'No active Gmail refresh token is stored for this mailbox.';
  end if;

  select decrypted_secret
  into v_token
  from vault.decrypted_secrets
  where vault.decrypted_secrets.id = v_secret_ref::uuid;

  if nullif(v_token, '') is null then
    raise exception 'Stored Gmail refresh token is unavailable.';
  end if;

  return v_token;
end;
$$;

create or replace function public.enqueue_gmail_sync_from_notification(
  p_email text,
  p_history_id text,
  p_pubsub_message_id text,
  p_subscription text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(nullif(btrim(p_email), ''));
  v_history_id text := nullif(btrim(p_history_id), '');
  v_message_id text := nullif(btrim(p_pubsub_message_id), '');
  v_matched integer := 0;
  v_inserted integer := 0;
  v_mailbox record;
  v_exists boolean;
begin
  if v_email is null or v_history_id is null then
    raise exception 'Pub/Sub Gmail notification requires email and history id.';
  end if;

  for v_mailbox in
    select *
    from public.linked_mailboxes lm
    where lm.provider = 'gmail'
      and lm.is_active
      and lower(lm.email) = v_email
  loop
    v_matched := v_matched + 1;

    select exists (
      select 1
      from public.ingestion_jobs ij
      where ij.linked_mailbox_id = v_mailbox.id
        and ij.job_type = 'gmail_sync'
        and ij.idempotency_key = 'gmail-history:' || v_history_id
    )
    into v_exists;

    insert into public.ingestion_jobs (
      household_id,
      linked_mailbox_id,
      job_type,
      idempotency_key,
      payload
    )
    values (
      v_mailbox.household_id,
      v_mailbox.id,
      'gmail_sync',
      'gmail-history:' || v_history_id,
      jsonb_build_object(
        'emailAddress', v_email,
        'notificationHistoryId', v_history_id,
        'startHistoryId', v_mailbox.gmail_history_id,
        'pubsubMessageId', v_message_id,
        'subscription', nullif(btrim(p_subscription), '')
      )
    )
    on conflict (linked_mailbox_id, job_type, idempotency_key)
    where linked_mailbox_id is not null
    do update
      set updated_at = now(),
          payload = public.ingestion_jobs.payload || excluded.payload;

    if not v_exists then
      v_inserted := v_inserted + 1;
    end if;

    update public.linked_mailboxes
    set
      last_notification_at = now(),
      last_error = null
    where public.linked_mailboxes.id = v_mailbox.id;
  end loop;

  return jsonb_build_object(
    'matchedMailboxes', v_matched,
    'insertedJobs', v_inserted
  );
end;
$$;

create or replace function public.mark_gmail_mailbox_error(
  p_mailbox_id uuid,
  p_error text,
  p_status public.job_status default 'failed'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.linked_mailboxes
  set
    last_error = left(coalesce(nullif(btrim(p_error), ''), 'Unknown Gmail connector error.'), 1000),
    last_sync_status = p_status
  where public.linked_mailboxes.id = p_mailbox_id
    and public.linked_mailboxes.provider = 'gmail';
end;
$$;

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
  matched_mapping boolean
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
    v_merchant_id is not null or v_rule_id is not null;
end;
$$;

revoke all on table public.gmail_oauth_states from public, anon, authenticated;
revoke all on table public.ingestion_jobs from public, anon, authenticated;
grant select, insert, update, delete on public.gmail_oauth_states to service_role;
grant select, insert, update, delete on public.ingestion_jobs to service_role;
grant select, insert, update on public.linked_mailboxes to service_role;
grant select, insert, update on public.source_accounts to service_role;
grant select, insert, update on public.transactions to service_role;
grant select, insert, update on public.transaction_sources to service_role;
grant select, insert, update on public.review_items to service_role;
grant select on public.v_linked_mailbox_status to authenticated, service_role;

grant select (
  connected_at,
  disconnected_at,
  last_watch_renewed_at,
  last_notification_at,
  last_sync_started_at,
  last_sync_status,
  has_oauth_secret,
  provider_subject,
  scope,
  token_expires_at
) on public.linked_mailboxes to authenticated;

revoke execute on function public.upsert_gmail_mailbox(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public, anon, authenticated;
revoke execute on function public.disconnect_gmail_mailbox(uuid) from public, anon, authenticated;
revoke execute on function public.get_gmail_refresh_token(uuid) from public, anon, authenticated;
revoke execute on function public.enqueue_gmail_sync_from_notification(text, text, text, text) from public, anon, authenticated;
revoke execute on function public.mark_gmail_mailbox_error(uuid, text, public.job_status) from public, anon, authenticated;
revoke execute on function public.ingest_gmail_transaction(uuid, jsonb, jsonb, text) from public, anon, authenticated;

grant execute on function public.upsert_gmail_mailbox(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to service_role;
grant execute on function public.disconnect_gmail_mailbox(uuid) to service_role;
grant execute on function public.get_gmail_refresh_token(uuid) to service_role;
grant execute on function public.enqueue_gmail_sync_from_notification(text, text, text, text) to service_role;
grant execute on function public.mark_gmail_mailbox_error(uuid, text, public.job_status) to service_role;
grant execute on function public.ingest_gmail_transaction(uuid, jsonb, jsonb, text) to service_role;
