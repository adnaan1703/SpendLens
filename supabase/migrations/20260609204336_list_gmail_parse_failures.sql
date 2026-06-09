create index if not exists gmail_parse_attempts_parse_failed_household_received_idx
  on public.gmail_parse_attempts (household_id, source_received_at desc)
  where parse_status = 'parse_failed';

create or replace function public.list_gmail_parse_failures(
  p_household_id uuid,
  p_limit integer default 20
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
    and p_household_id in (select app_private.active_household_ids())
  order by gpa.source_received_at desc, gpa.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

comment on function public.list_gmail_parse_failures(uuid, integer) is
  'Returns sanitized Gmail parse failures for active household members without exposing raw message bodies.';

revoke execute on function public.list_gmail_parse_failures(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.list_gmail_parse_failures(uuid, integer)
  to authenticated, service_role;
