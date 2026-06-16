alter type public.source_account_type add value if not exists 'netbanking_imps' after 'upi';

alter table public.gmail_parse_attempts
  drop constraint if exists gmail_parse_attempts_candidate_type_supported;

alter table public.gmail_parse_attempts
  add constraint gmail_parse_attempts_candidate_type_supported check (
    candidate_type::text in ('credit_card', 'upi', 'netbanking_imps', 'other')
  );

create or replace function public.record_gmail_parse_attempt(
  p_mailbox_id uuid,
  p_transaction_id uuid,
  p_source_message_id text,
  p_source_thread_id text,
  p_source_received_at timestamptz,
  p_sender_email text,
  p_subject text,
  p_candidate_type public.source_account_type,
  p_parser_name text,
  p_parser_version text,
  p_parse_status text,
  p_transaction_date date,
  p_source_reference text,
  p_diagnostics jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mailbox public.linked_mailboxes;
  v_attempt_id uuid;
  v_source_message_id text := nullif(btrim(p_source_message_id), '');
  v_sender_email text := lower(nullif(btrim(p_sender_email), ''));
  v_subject text := nullif(btrim(p_subject), '');
  v_parser_name text := nullif(btrim(p_parser_name), '');
  v_parser_version text := nullif(btrim(p_parser_version), '');
begin
  if v_source_message_id is null then
    raise exception 'Gmail parse attempt source message id is required.';
  end if;

  if p_source_received_at is null then
    raise exception 'Gmail parse attempt received timestamp is required.';
  end if;

  if v_sender_email is null then
    raise exception 'Gmail parse attempt sender email is required.';
  end if;

  if v_subject is null then
    raise exception 'Gmail parse attempt subject is required.';
  end if;

  if v_parser_name is null or v_parser_version is null then
    raise exception 'Gmail parse attempt parser name and version are required.';
  end if;

  if p_candidate_type::text not in ('credit_card', 'upi', 'netbanking_imps', 'other') then
    raise exception 'Unsupported Gmail parse candidate type: %.', p_candidate_type;
  end if;

  if p_parse_status not in ('parsed', 'parse_failed', 'outside_date_range') then
    raise exception 'Unsupported Gmail parse status: %.', p_parse_status;
  end if;

  select *
  into v_mailbox
  from public.linked_mailboxes lm
  where lm.id = p_mailbox_id
    and lm.provider = 'gmail'
    and lm.is_active;

  if not found then
    raise exception 'Active Gmail mailbox not found for parse attempt.';
  end if;

  if p_transaction_id is not null and not exists (
    select 1
    from public.transactions t
    where t.id = p_transaction_id
      and t.household_id = v_mailbox.household_id
  ) then
    raise exception 'Gmail parse attempt transaction does not belong to mailbox household.';
  end if;

  insert into public.gmail_parse_attempts (
    household_id,
    linked_mailbox_id,
    transaction_id,
    candidate_type,
    source_message_id,
    source_thread_id,
    source_received_at,
    sender_email,
    subject,
    parser_name,
    parser_version,
    parse_status,
    transaction_date,
    source_reference,
    diagnostics
  )
  values (
    v_mailbox.household_id,
    v_mailbox.id,
    p_transaction_id,
    p_candidate_type,
    v_source_message_id,
    nullif(btrim(p_source_thread_id), ''),
    p_source_received_at,
    v_sender_email,
    v_subject,
    v_parser_name,
    v_parser_version,
    p_parse_status,
    p_transaction_date,
    nullif(btrim(p_source_reference), ''),
    coalesce(p_diagnostics, '{}'::jsonb)
  )
  on conflict (
    linked_mailbox_id,
    source_message_id,
    candidate_type,
    parser_name,
    parser_version
  )
  do update
    set
      transaction_id = excluded.transaction_id,
      source_thread_id = excluded.source_thread_id,
      source_received_at = excluded.source_received_at,
      sender_email = excluded.sender_email,
      subject = excluded.subject,
      parse_status = excluded.parse_status,
      transaction_date = excluded.transaction_date,
      source_reference = excluded.source_reference,
      diagnostics = excluded.diagnostics,
      updated_at = now()
  returning id into v_attempt_id;

  return v_attempt_id;
end;
$$;

comment on constraint gmail_parse_attempts_candidate_type_supported
  on public.gmail_parse_attempts is
  'Allows supported Gmail parser candidates plus sanitized other watched-label failures.';

revoke execute on function public.record_gmail_parse_attempt(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  text,
  text,
  public.source_account_type,
  text,
  text,
  text,
  date,
  text,
  jsonb
) from public, anon, authenticated;

grant execute on function public.record_gmail_parse_attempt(
  uuid,
  uuid,
  text,
  text,
  timestamptz,
  text,
  text,
  public.source_account_type,
  text,
  text,
  text,
  date,
  text,
  jsonb
) to service_role;
