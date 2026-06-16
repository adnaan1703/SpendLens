alter table public.linked_mailboxes
  add column if not exists watched_gmail_label_id text,
  add column if not exists watched_gmail_label_name text,
  add column if not exists watched_gmail_label_resolved_at timestamptz,
  add constraint linked_mailboxes_watched_gmail_label_id_nonempty
    check (watched_gmail_label_id is null or btrim(watched_gmail_label_id) <> ''),
  add constraint linked_mailboxes_watched_gmail_label_name_exact
    check (
      watched_gmail_label_name is null
      or btrim(watched_gmail_label_name) = 'Banking/HDFC Transactions'
    ),
  add constraint linked_mailboxes_watched_gmail_label_shape
    check (
      (
        watched_gmail_label_id is null
        and watched_gmail_label_name is null
        and watched_gmail_label_resolved_at is null
      )
      or (
        watched_gmail_label_id is not null
        and watched_gmail_label_name is not null
        and watched_gmail_label_resolved_at is not null
      )
    );

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
  j.latest_job_error,
  lm.watched_gmail_label_id,
  lm.watched_gmail_label_name,
  lm.watched_gmail_label_resolved_at
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

drop function if exists public.upsert_gmail_mailbox(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
);

create or replace function public.upsert_gmail_mailbox(
  p_household_id uuid,
  p_profile_id uuid,
  p_email text,
  p_refresh_token text,
  p_provider_subject text,
  p_scope text,
  p_gmail_history_id text,
  p_watch_expires_at timestamptz,
  p_token_expires_at timestamptz,
  p_watched_gmail_label_id text,
  p_watched_gmail_label_name text,
  p_watched_gmail_label_resolved_at timestamptz
)
returns table (
  id uuid,
  household_id uuid,
  profile_id uuid,
  email text,
  gmail_history_id text,
  watched_gmail_label_id text,
  watched_gmail_label_name text,
  watched_gmail_label_resolved_at timestamptz,
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
  v_watched_label_id text := nullif(btrim(p_watched_gmail_label_id), '');
  v_watched_label_name text := nullif(btrim(p_watched_gmail_label_name), '');
  v_mailbox public.linked_mailboxes;
  v_secret_ref uuid;
  v_secret_name text;
  v_now timestamptz := now();
begin
  if v_email is null then
    raise exception 'Gmail email is required.';
  end if;

  if v_watched_label_id is null then
    raise exception 'Watched Gmail label id is required.';
  end if;

  if v_watched_label_name is distinct from 'Banking/HDFC Transactions' then
    raise exception 'Watched Gmail label name must be Banking/HDFC Transactions.';
  end if;

  if p_watched_gmail_label_resolved_at is null then
    raise exception 'Watched Gmail label resolution timestamp is required.';
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
    watched_gmail_label_id = v_watched_label_id,
    watched_gmail_label_name = v_watched_label_name,
    watched_gmail_label_resolved_at = p_watched_gmail_label_resolved_at,
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
        'gmailHistoryId', v_mailbox.gmail_history_id,
        'watchedGmailLabelId', v_mailbox.watched_gmail_label_id,
        'watchedGmailLabelName', v_mailbox.watched_gmail_label_name
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
    v_mailbox.watched_gmail_label_id,
    v_mailbox.watched_gmail_label_name,
    v_mailbox.watched_gmail_label_resolved_at,
    v_mailbox.watch_expires_at,
    v_mailbox.is_active;
end;
$$;

comment on column public.linked_mailboxes.watched_gmail_label_id is
  'Resolved Gmail label id for the readonly Banking/HDFC Transactions ingestion label.';
comment on column public.linked_mailboxes.watched_gmail_label_name is
  'Exact Gmail label name used for transaction candidate discovery; expected to be Banking/HDFC Transactions.';
comment on column public.linked_mailboxes.watched_gmail_label_resolved_at is
  'Timestamp when the Gmail label id/name was last resolved from Gmail.';

grant select on public.v_linked_mailbox_status to authenticated, service_role;

grant select (
  watched_gmail_label_id,
  watched_gmail_label_name,
  watched_gmail_label_resolved_at
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
  timestamptz,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

grant execute on function public.upsert_gmail_mailbox(
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  text,
  text,
  timestamptz
) to service_role;
