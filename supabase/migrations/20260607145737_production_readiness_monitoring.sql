create or replace view public.v_ingestion_operational_health
with (security_invoker = true)
as
with mailbox_rollup as (
  select
    lm.household_id,
    count(*) filter (where lm.provider = 'gmail' and lm.is_active)::integer
      as active_mailbox_count,
    count(*) filter (where lm.provider = 'gmail' and not lm.is_active)::integer
      as disconnected_mailbox_count,
    count(*) filter (
      where lm.provider = 'gmail'
        and lm.is_active
        and lm.last_error is not null
    )::integer as mailbox_error_count,
    count(*) filter (
      where lm.provider = 'gmail'
        and lm.is_active
        and not lm.has_oauth_secret
    )::integer as oauth_missing_count,
    count(*) filter (
      where lm.provider = 'gmail'
        and lm.is_active
        and lm.watch_expires_at <= now()
    )::integer as watch_expired_count,
    count(*) filter (
      where lm.provider = 'gmail'
        and lm.is_active
        and (
          lm.watch_expires_at is null
          or lm.watch_expires_at <= now() + interval '48 hours'
        )
    )::integer as watch_expiring_48h_count,
    count(*) filter (
      where lm.provider = 'gmail'
        and lm.is_active
        and (
          lm.last_sync_at is null
          or lm.last_sync_at < now() - interval '24 hours'
        )
    )::integer as stale_sync_mailbox_count,
    (
      array_agg(left(lm.last_error, 500) order by lm.updated_at desc)
        filter (
          where lm.provider = 'gmail'
            and lm.is_active
            and lm.last_error is not null
        )
    )[1] as latest_mailbox_error
  from public.linked_mailboxes lm
  group by lm.household_id
),
job_rollup as (
  select
    ij.household_id,
    count(*) filter (where ij.status = 'queued')::integer as queued_job_count,
    count(*) filter (where ij.status = 'processing')::integer
      as processing_job_count,
    count(*) filter (
      where ij.status = 'queued'
        and ij.attempts > 0
        and ij.attempts < ij.max_attempts
    )::integer as retrying_job_count,
    count(*) filter (where ij.status = 'failed')::integer as failed_job_count,
    count(*) filter (
      where ij.status = 'failed'
        or ij.attempts >= ij.max_attempts
    )::integer as permanently_failed_job_count,
    min(ij.created_at) filter (where ij.status = 'queued') as oldest_queued_job_at,
    max(ij.updated_at) filter (
      where ij.status = 'failed'
        or ij.error_message is not null
    ) as latest_failure_at,
    (
      array_agg(left(ij.error_message, 500) order by ij.updated_at desc)
        filter (where ij.error_message is not null)
    )[1] as latest_job_error
  from public.ingestion_jobs ij
  group by ij.household_id
)
select
  coalesce(m.household_id, j.household_id) as household_id,
  now() as generated_at,
  coalesce(m.active_mailbox_count, 0) as active_mailbox_count,
  coalesce(m.disconnected_mailbox_count, 0) as disconnected_mailbox_count,
  coalesce(m.mailbox_error_count, 0) as mailbox_error_count,
  coalesce(m.oauth_missing_count, 0) as oauth_missing_count,
  coalesce(m.watch_expired_count, 0) as watch_expired_count,
  coalesce(m.watch_expiring_48h_count, 0) as watch_expiring_48h_count,
  coalesce(m.stale_sync_mailbox_count, 0) as stale_sync_mailbox_count,
  coalesce(j.queued_job_count, 0) as queued_job_count,
  coalesce(j.processing_job_count, 0) as processing_job_count,
  coalesce(j.retrying_job_count, 0) as retrying_job_count,
  coalesce(j.failed_job_count, 0) as failed_job_count,
  coalesce(j.permanently_failed_job_count, 0) as permanently_failed_job_count,
  j.oldest_queued_job_at,
  j.latest_failure_at,
  m.latest_mailbox_error,
  j.latest_job_error
from mailbox_rollup m
full join job_rollup j
  on j.household_id = m.household_id;

comment on view public.v_ingestion_operational_health is
  'Service-role production health view for Gmail connector watches, stale syncs, failed jobs, and retry backlog.';

create or replace view public.v_parser_operational_health
with (security_invoker = true)
as
select
  ts.household_id,
  ts.source_type,
  coalesce(nullif(btrim(ts.parser_name), ''), 'unknown') as parser_name,
  coalesce(nullif(btrim(ts.parser_version), ''), 'unknown') as parser_version,
  coalesce(nullif(btrim(ts.parse_status), ''), 'unknown') as parse_status,
  count(*)::integer as transaction_source_count,
  min(ts.source_received_at) as first_source_received_at,
  max(ts.source_received_at) as last_source_received_at,
  max(ts.created_at) as latest_recorded_at
from public.transaction_sources ts
where ts.source_type = 'gmail'
group by
  ts.household_id,
  ts.source_type,
  coalesce(nullif(btrim(ts.parser_name), ''), 'unknown'),
  coalesce(nullif(btrim(ts.parser_version), ''), 'unknown'),
  coalesce(nullif(btrim(ts.parse_status), ''), 'unknown');

comment on view public.v_parser_operational_health is
  'Service-role parser health view for Gmail parser volume and parse status rates.';

revoke all on table public.v_ingestion_operational_health from public, anon, authenticated;
revoke all on table public.v_parser_operational_health from public, anon, authenticated;
grant select on public.v_ingestion_operational_health to service_role;
grant select on public.v_parser_operational_health to service_role;
