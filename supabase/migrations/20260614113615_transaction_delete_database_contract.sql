create table public.deleted_transaction_sources (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  source_type public.source_type not null,
  source_fingerprint text not null,
  deleted_transaction_id uuid not null,
  source_message_id text,
  source_reference text,
  deleted_by uuid references public.profiles (id) on delete set null,
  deleted_at timestamptz not null default now(),
  reason text,
  unique (household_id, source_fingerprint),
  constraint deleted_transaction_sources_fingerprint_nonempty check (
    btrim(source_fingerprint) <> ''
  ),
  constraint deleted_transaction_sources_message_id_nonempty check (
    source_message_id is null
    or btrim(source_message_id) <> ''
  ),
  constraint deleted_transaction_sources_reference_nonempty check (
    source_reference is null
    or btrim(source_reference) <> ''
  ),
  constraint deleted_transaction_sources_reason_nonempty check (
    reason is null
    or btrim(reason) <> ''
  )
);

create index deleted_transaction_sources_lookup_idx
  on public.deleted_transaction_sources (
    household_id,
    source_type,
    source_fingerprint
  );

create index deleted_transaction_sources_message_lookup_idx
  on public.deleted_transaction_sources (
    household_id,
    source_message_id
  )
  where source_message_id is not null;

alter table public.deleted_transaction_sources enable row level security;

create policy "deleted_transaction_sources_select_owners"
  on public.deleted_transaction_sources
  for select
  to authenticated
  using (household_id in (select app_private.owner_household_ids()));

create policy "deleted_transaction_sources_insert_owners"
  on public.deleted_transaction_sources
  for insert
  to authenticated
  with check (household_id in (select app_private.owner_household_ids()));

create or replace function app_private.record_deleted_transaction_source()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_by uuid;
  v_reason text;
  v_source_message_id text;
  v_source_reference text;
begin
  v_deleted_by := app_private.current_profile_id();
  v_reason := nullif(
    btrim(current_setting('app.transaction_delete_reason', true)),
    ''
  );

  select
    nullif(btrim(ts.source_message_id), ''),
    nullif(btrim(ts.source_reference), '')
  into
    v_source_message_id,
    v_source_reference
  from public.transaction_sources ts
  where ts.household_id = old.household_id
    and ts.transaction_id = old.id
  order by
    (ts.source_type = old.source_type) desc,
    (
      nullif(btrim(ts.source_message_id), '') is not null
      or nullif(btrim(ts.source_reference), '') is not null
    ) desc,
    ts.created_at desc,
    ts.id desc
  limit 1;

  insert into public.deleted_transaction_sources (
    household_id,
    source_type,
    source_fingerprint,
    deleted_transaction_id,
    source_message_id,
    source_reference,
    deleted_by,
    reason
  )
  values (
    old.household_id,
    old.source_type,
    old.source_fingerprint,
    old.id,
    v_source_message_id,
    v_source_reference,
    v_deleted_by,
    v_reason
  )
  on conflict (household_id, source_fingerprint) do nothing;

  return old;
end;
$$;

create or replace function app_private.count_gmail_parse_attempts_for_transaction(
  p_household_id uuid,
  p_transaction_id uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_household_id in (select app_private.owner_household_ids()) then
      (
        select count(*)::integer
        from public.gmail_parse_attempts gpa
        where gpa.household_id = p_household_id
          and gpa.transaction_id = p_transaction_id
      )
    else 0
  end;
$$;

drop trigger if exists record_deleted_transaction_source
  on public.transactions;
create trigger record_deleted_transaction_source
  before delete on public.transactions
  for each row execute function app_private.record_deleted_transaction_source();

drop policy if exists "transactions_delete_admins" on public.transactions;
drop policy if exists "transactions_delete_owners" on public.transactions;
create policy "transactions_delete_owners"
  on public.transactions
  for delete
  to authenticated
  using (household_id in (select app_private.owner_household_ids()));

create or replace function public.delete_transaction(
  p_household_id uuid,
  p_transaction_id uuid,
  p_reason text default null
)
returns table (
  deleted_transaction_id uuid,
  source_type public.source_type,
  source_fingerprint text,
  deleted_label_count integer,
  deleted_source_row_count integer,
  deleted_review_item_count integer,
  unlinked_piggy_bank_entry_count integer,
  unlinked_gmail_parse_attempt_count integer,
  deleted_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_transaction public.transactions%rowtype;
  v_reason text := nullif(btrim(p_reason), '');
  v_deleted_at timestamptz := statement_timestamp();
  v_deleted_label_count integer := 0;
  v_deleted_source_row_count integer := 0;
  v_deleted_review_item_count integer := 0;
  v_unlinked_piggy_bank_entry_count integer := 0;
  v_unlinked_gmail_parse_attempt_count integer := 0;
begin
  v_profile_id := app_private.current_profile_id();

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to delete transactions.';
  end if;

  if p_household_id is null then
    raise exception 'Household id is required to delete transactions.';
  end if;

  if p_transaction_id is null then
    raise exception 'Transaction id is required to delete transactions.';
  end if;

  if p_household_id not in (select app_private.owner_household_ids()) then
    raise exception 'You do not have permission to delete transactions for this household.';
  end if;

  select *
  into v_transaction
  from public.transactions t
  where t.id = p_transaction_id;

  if not found then
    raise exception 'Transaction not found.';
  end if;

  if v_transaction.household_id <> p_household_id then
    raise exception 'Transaction does not belong to this household.';
  end if;

  select count(*)::integer
  into v_deleted_label_count
  from public.transaction_labels tl
  where tl.household_id = p_household_id
    and tl.transaction_id = p_transaction_id;

  select count(*)::integer
  into v_deleted_source_row_count
  from public.transaction_sources ts
  where ts.household_id = p_household_id
    and ts.transaction_id = p_transaction_id;

  select count(*)::integer
  into v_deleted_review_item_count
  from public.review_items ri
  where ri.household_id = p_household_id
    and ri.transaction_id = p_transaction_id;

  select count(*)::integer
  into v_unlinked_piggy_bank_entry_count
  from public.piggy_bank_entries pbe
  where pbe.household_id = p_household_id
    and pbe.linked_transaction_id = p_transaction_id;

  select app_private.count_gmail_parse_attempts_for_transaction(
    p_household_id,
    p_transaction_id
  )
  into v_unlinked_gmail_parse_attempt_count
  ;

  perform set_config(
    'app.transaction_delete_reason',
    coalesce(v_reason, ''),
    true
  );

  delete from public.transactions t
  where t.id = p_transaction_id
    and t.household_id = p_household_id;

  if not found then
    raise exception 'Transaction could not be deleted.';
  end if;

  perform set_config('app.transaction_delete_reason', '', true);

  select dts.deleted_at
  into v_deleted_at
  from public.deleted_transaction_sources dts
  where dts.household_id = p_household_id
    and dts.source_fingerprint = v_transaction.source_fingerprint;

  deleted_transaction_id := v_transaction.id;
  source_type := v_transaction.source_type;
  source_fingerprint := v_transaction.source_fingerprint;
  deleted_label_count := v_deleted_label_count;
  deleted_source_row_count := v_deleted_source_row_count;
  deleted_review_item_count := v_deleted_review_item_count;
  unlinked_piggy_bank_entry_count := v_unlinked_piggy_bank_entry_count;
  unlinked_gmail_parse_attempt_count := v_unlinked_gmail_parse_attempt_count;
  deleted_at := v_deleted_at;
  return next;
exception
  when others then
    perform set_config('app.transaction_delete_reason', '', true);
    raise;
end;
$$;

comment on table public.deleted_transaction_sources is
  'Minimal household-scoped source tombstones for intentionally deleted transactions.';
comment on column public.deleted_transaction_sources.source_fingerprint is
  'Original transaction source fingerprint used to suppress later re-import.';
comment on column public.deleted_transaction_sources.deleted_transaction_id is
  'Identifier of the hard-deleted transaction row; no FK is kept because the transaction is deleted.';
comment on column public.deleted_transaction_sources.source_message_id is
  'Optional minimal Gmail message identity copied from transaction source metadata.';
comment on column public.deleted_transaction_sources.source_reference is
  'Optional minimal source reference copied from transaction source metadata.';
comment on column public.deleted_transaction_sources.reason is
  'Optional user-provided deletion reason; must not contain transaction payload or email body content.';
comment on function public.delete_transaction(uuid, uuid, text) is
  'Owner-only hard delete contract for transactions with cascade/unlink impact counts and source tombstone recording.';

revoke all privileges on public.deleted_transaction_sources
  from public, anon, authenticated, service_role;
revoke execute on function app_private.record_deleted_transaction_source()
  from public, anon, authenticated, service_role;
revoke execute on function app_private.count_gmail_parse_attempts_for_transaction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke execute on function public.delete_transaction(uuid, uuid, text)
  from public, anon, authenticated, service_role;

grant select, insert on public.deleted_transaction_sources to authenticated;
grant select on public.deleted_transaction_sources to service_role;
grant execute on function app_private.count_gmail_parse_attempts_for_transaction(uuid, uuid)
  to authenticated;
grant execute on function public.delete_transaction(uuid, uuid, text)
  to authenticated;
