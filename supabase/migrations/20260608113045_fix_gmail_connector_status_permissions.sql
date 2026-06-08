-- Allow authenticated members to read ingestion job metadata used by connector status view.

grant select on public.ingestion_jobs to authenticated;

create policy "ingestion_jobs_select_members"
  on public.ingestion_jobs
  for select
  to authenticated
  using (household_id in (select app_private.active_household_ids()));
