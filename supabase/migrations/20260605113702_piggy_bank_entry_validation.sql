create or replace function public.create_piggy_bank_entry(
  p_household_id uuid,
  p_piggy_bank_id uuid,
  p_entry_type public.piggy_entry_type,
  p_amount numeric,
  p_entry_date date default current_date,
  p_note text default null,
  p_linked_transaction_id uuid default null
)
returns table (
  id uuid,
  household_id uuid,
  piggy_bank_id uuid,
  entry_type public.piggy_entry_type,
  amount numeric(14,2),
  entry_date date,
  note text,
  linked_transaction_id uuid,
  created_by uuid,
  created_at timestamptz
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile_id uuid;
  v_amount numeric(14,2);
  v_current_balance numeric(14,2);
  v_note text;
begin
  v_profile_id := app_private.current_profile_id();
  v_amount := p_amount::numeric(14,2);
  v_note := nullif(btrim(p_note), '');

  if v_profile_id is null then
    raise exception 'A signed-in profile is required to create a piggy-bank entry.';
  end if;

  if not exists (
    select 1
    from app_private.write_household_ids() as writable_household(id)
    where writable_household.id = p_household_id
  ) then
    raise exception 'You do not have write access to this household.'
      using errcode = '42501';
  end if;

  perform 1
  from public.piggy_banks pb
  where pb.id = p_piggy_bank_id
    and pb.household_id = p_household_id
    and not pb.is_archived
  for update;

  if not found then
    raise exception 'Piggy bank not found.';
  end if;

  if p_entry_type is null then
    raise exception 'Entry type is required.';
  end if;

  if p_entry_type in ('deposit', 'withdrawal') and (v_amount is null or v_amount <= 0) then
    raise exception 'Deposits and withdrawals require a positive amount.';
  end if;

  if p_entry_type = 'adjustment' and (v_amount is null or v_amount = 0) then
    raise exception 'Adjustment amount cannot be zero.';
  end if;

  if p_linked_transaction_id is not null and not exists (
    select 1
    from public.transactions t
    where t.id = p_linked_transaction_id
      and t.household_id = p_household_id
  ) then
    raise exception 'Linked transaction not found.';
  end if;

  select coalesce(
    sum(
      case pbe.entry_type
        when 'deposit' then pbe.amount
        when 'withdrawal' then -pbe.amount
        when 'adjustment' then pbe.amount
      end
    ),
    0
  )::numeric(14,2)
  into v_current_balance
  from public.piggy_bank_entries pbe
  where pbe.household_id = p_household_id
    and pbe.piggy_bank_id = p_piggy_bank_id;

  if p_entry_type = 'withdrawal' and v_amount > v_current_balance then
    raise exception 'Withdrawal cannot exceed current piggy-bank balance.';
  end if;

  return query
  insert into public.piggy_bank_entries as inserted_entry (
    household_id,
    piggy_bank_id,
    entry_type,
    amount,
    entry_date,
    note,
    linked_transaction_id,
    created_by
  )
  values (
    p_household_id,
    p_piggy_bank_id,
    p_entry_type,
    v_amount,
    coalesce(p_entry_date, current_date),
    v_note,
    p_linked_transaction_id,
    v_profile_id
  )
  returning
    inserted_entry.id,
    inserted_entry.household_id,
    inserted_entry.piggy_bank_id,
    inserted_entry.entry_type,
    inserted_entry.amount,
    inserted_entry.entry_date,
    inserted_entry.note,
    inserted_entry.linked_transaction_id,
    inserted_entry.created_by,
    inserted_entry.created_at;
end;
$$;

revoke execute on function public.create_piggy_bank_entry(
  uuid,
  uuid,
  public.piggy_entry_type,
  numeric,
  date,
  text,
  uuid
) from public, anon, authenticated;

grant execute on function public.create_piggy_bank_entry(
  uuid,
  uuid,
  public.piggy_entry_type,
  numeric,
  date,
  text,
  uuid
) to authenticated, service_role;
