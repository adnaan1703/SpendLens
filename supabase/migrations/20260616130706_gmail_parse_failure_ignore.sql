alter table public.gmail_parse_attempts
  add column if not exists ignored_at timestamptz,
  add column if not exists ignored_by uuid references public.profiles (id) on delete set null;

alter table public.gmail_parse_attempts
  add constraint gmail_parse_attempts_ignore_fields_consistent check (
    (ignored_at is null and ignored_by is null)
    or (ignored_at is not null and ignored_by is not null)
  );

create index if not exists gmail_parse_attempts_visible_failure_idx
  on public.gmail_parse_attempts (household_id, source_received_at desc)
  where parse_status = 'parse_failed'
    and ignored_at is null;

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
    and gpa.ignored_at is null
    and p_household_id in (select app_private.active_household_ids())
  order by gpa.source_received_at desc, gpa.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

create or replace function public.ignore_gmail_parse_failure(
  p_failure_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := app_private.current_profile_id();
  v_updated_count integer := 0;
begin
  if v_profile_id is null then
    raise exception 'A signed-in profile is required to ignore Gmail parse failures.';
  end if;

  update public.gmail_parse_attempts gpa
  set
    ignored_at = coalesce(gpa.ignored_at, now()),
    ignored_by = coalesce(gpa.ignored_by, v_profile_id),
    updated_at = now()
  from public.linked_mailboxes lm
  where gpa.id = p_failure_id
    and gpa.linked_mailbox_id = lm.id
    and gpa.household_id = lm.household_id
    and gpa.parse_status = 'parse_failed'
    and lm.provider = 'gmail'
    and lm.is_active
    and gpa.household_id in (select app_private.active_household_ids());

  get diagnostics v_updated_count = row_count;

  if v_updated_count <> 1 then
    raise exception 'Visible Gmail parse failure not found.';
  end if;
end;
$$;

comment on column public.gmail_parse_attempts.ignored_at is
  'Timestamp when an active household member hid this sanitized Gmail parse failure from Review.';

comment on column public.gmail_parse_attempts.ignored_by is
  'Profile that first hid this sanitized Gmail parse failure from Review.';

comment on function public.list_gmail_parse_failures(uuid, integer) is
  'Returns unignored sanitized Gmail parse failures for active household members without exposing raw message bodies.';

comment on function public.ignore_gmail_parse_failure(uuid) is
  'Marks one visible Gmail parse failure ignored for the active household while keeping service-only diagnostics.';

revoke execute on function public.ignore_gmail_parse_failure(uuid)
  from public, anon, authenticated;

grant execute on function public.ignore_gmail_parse_failure(uuid)
  to authenticated, service_role;
