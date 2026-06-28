create or replace function app_private.is_bill_payment_category(
  p_household_id uuid,
  p_category_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.categories c
    where c.household_id = p_household_id
      and c.id = p_category_id
      and c.name = 'Payments/Credits (not expense)'
  );
$$;

comment on function app_private.is_bill_payment_category(uuid, uuid)
  is 'Returns true when a household category id has the exact bill-payment category name.';

create or replace function app_private.normalize_bill_payment_transaction_shape()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_new_is_bill_payment boolean := false;
  v_old_was_bill_payment boolean := false;
begin
  if new.category_id is not null then
    v_new_is_bill_payment := app_private.is_bill_payment_category(
      new.household_id,
      new.category_id
    );
  end if;

  if v_new_is_bill_payment then
    new.transaction_type := 'bill_payment_credit'::public.transaction_type;
    new.gross_spend := 0;
    new.refund_amount := 0;
    new.net_expense := 0;
    return new;
  end if;

  if tg_op = 'UPDATE'
    and old.category_id is not null
    and old.category_id is distinct from new.category_id then
    v_old_was_bill_payment := app_private.is_bill_payment_category(
      old.household_id,
      old.category_id
    );

    if v_old_was_bill_payment then
      if abs(new.amount) = 0 then
        raise exception
          'Cannot move a zero-amount Payments/Credits transaction out of the bill-payment category.';
      end if;

      new.transaction_type := 'debit_spend'::public.transaction_type;
      new.gross_spend := abs(new.amount)::numeric(14,2);
      new.refund_amount := 0;
      new.net_expense := abs(new.amount)::numeric(14,2);
    end if;
  end if;

  return new;
end;
$$;

comment on function app_private.normalize_bill_payment_transaction_shape()
  is 'Forces transactions in the exact Payments/Credits category to bill-payment money shape and converts direct moves away to debit spend.';

drop trigger if exists normalize_bill_payment_transaction_shape
  on public.transactions;

create trigger normalize_bill_payment_transaction_shape
before insert or update on public.transactions
for each row
execute function app_private.normalize_bill_payment_transaction_shape();

create or replace function app_private.reshape_bill_payment_transactions_after_category_rename()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.name = 'Payments/Credits (not expense)'
    and new.name <> 'Payments/Credits (not expense)' then
    if exists (
      select 1
      from public.transactions t
      where t.household_id = new.household_id
        and t.category_id = new.id
        and abs(t.amount) = 0
    ) then
      raise exception
        'Cannot rename Payments/Credits away while zero-amount bill-payment transactions use the category.';
    end if;

    update public.transactions t
    set
      transaction_type = 'debit_spend'::public.transaction_type,
      gross_spend = abs(t.amount)::numeric(14,2),
      refund_amount = 0,
      net_expense = abs(t.amount)::numeric(14,2)
    where t.household_id = new.household_id
      and t.category_id = new.id;
  elsif old.name <> 'Payments/Credits (not expense)'
    and new.name = 'Payments/Credits (not expense)' then
    update public.transactions t
    set
      transaction_type = 'bill_payment_credit'::public.transaction_type,
      gross_spend = 0,
      refund_amount = 0,
      net_expense = 0
    where t.household_id = new.household_id
      and t.category_id = new.id;
  end if;

  return new;
end;
$$;

comment on function app_private.reshape_bill_payment_transactions_after_category_rename()
  is 'Reshapes existing transactions when a category is renamed to or from the exact bill-payment category name.';

drop trigger if exists reshape_bill_payment_transactions_after_category_rename
  on public.categories;

create trigger reshape_bill_payment_transactions_after_category_rename
after update of name on public.categories
for each row
when (old.name is distinct from new.name)
execute function app_private.reshape_bill_payment_transactions_after_category_rename();

update public.transactions t
set
  transaction_type = 'bill_payment_credit'::public.transaction_type,
  gross_spend = 0,
  refund_amount = 0,
  net_expense = 0
from public.categories c
where c.household_id = t.household_id
  and c.id = t.category_id
  and c.name = 'Payments/Credits (not expense)'
  and (
    t.transaction_type is distinct from 'bill_payment_credit'::public.transaction_type
    or t.gross_spend <> 0
    or t.refund_amount <> 0
    or t.net_expense <> 0
  );
