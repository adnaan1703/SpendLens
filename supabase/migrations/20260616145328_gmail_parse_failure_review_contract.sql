drop function if exists public.list_gmail_parse_failures(uuid, integer);

create index if not exists gmail_parse_attempts_visible_failure_page_idx
  on public.gmail_parse_attempts (
    household_id,
    source_received_at desc,
    created_at desc,
    id desc
  )
  where parse_status = 'parse_failed'
    and ignored_at is null;

create or replace function public.list_gmail_parse_failures(
  p_household_id uuid,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  failure_id uuid,
  candidate_type public.source_account_type,
  source_received_at timestamptz,
  sender_email text,
  subject text,
  parser_name text,
  parser_version text,
  reason_code text,
  source_message_id text,
  source_thread_id text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    gpa.id as failure_id,
    gpa.candidate_type,
    gpa.source_received_at,
    gpa.sender_email,
    gpa.subject,
    gpa.parser_name,
    gpa.parser_version,
    nullif(btrim(gpa.diagnostics->>'reason'), '') as reason_code,
    gpa.source_message_id,
    gpa.source_thread_id
  from public.gmail_parse_attempts gpa
  join public.linked_mailboxes lm
    on lm.id = gpa.linked_mailbox_id
   and lm.household_id = gpa.household_id
   and lm.provider = 'gmail'
   and lm.is_active
  where gpa.household_id = p_household_id
    and gpa.parse_status = 'parse_failed'
    and gpa.ignored_at is null
    and p_household_id in (select app_private.active_household_ids())
  order by
    gpa.source_received_at desc,
    gpa.created_at desc,
    gpa.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.authorize_gmail_parse_failure_body(
  p_failure_id uuid
)
returns table (
  failure_id uuid,
  household_id uuid,
  linked_mailbox_id uuid,
  mailbox_email text,
  candidate_type public.source_account_type,
  source_message_id text,
  source_thread_id text,
  source_received_at timestamptz,
  sender_email text,
  subject text,
  parser_name text,
  parser_version text,
  reason_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    gpa.id as failure_id,
    gpa.household_id,
    gpa.linked_mailbox_id,
    lm.email as mailbox_email,
    gpa.candidate_type,
    gpa.source_message_id,
    gpa.source_thread_id,
    gpa.source_received_at,
    gpa.sender_email,
    gpa.subject,
    gpa.parser_name,
    gpa.parser_version,
    nullif(btrim(gpa.diagnostics->>'reason'), '') as reason_code
  from public.gmail_parse_attempts gpa
  join public.linked_mailboxes lm
    on lm.id = gpa.linked_mailbox_id
   and lm.household_id = gpa.household_id
   and lm.provider = 'gmail'
   and lm.is_active
  where gpa.id = p_failure_id
    and gpa.parse_status = 'parse_failed'
    and gpa.ignored_at is null
    and gpa.household_id in (select app_private.active_household_ids())
  limit 1;
$$;

comment on function public.list_gmail_parse_failures(uuid, integer, integer) is
  'Returns a deterministic page of unignored sanitized Gmail parse failures for active household members without exposing raw message bodies.';

comment on function public.authorize_gmail_parse_failure_body(uuid) is
  'Authorizes one visible Gmail parse failure for body fetch and returns only safe metadata needed by the authenticated Edge Function.';

revoke execute on function public.list_gmail_parse_failures(uuid, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.authorize_gmail_parse_failure_body(uuid)
  from public, anon, authenticated;

grant execute on function public.list_gmail_parse_failures(uuid, integer, integer)
  to authenticated, service_role;
grant execute on function public.authorize_gmail_parse_failure_body(uuid)
  to authenticated, service_role;
