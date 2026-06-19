# Workbook Import

Milestone 3 uses a local admin import script to seed `docs/Credit Card Spend Analysis - FY 2025-26.xlsx` into the normalized Supabase schema.

## Safe Local Rerun

Start or reset the local Supabase stack first:

```sh
supabase start
supabase db reset --local
```

Install the pinned importer dependencies once:

```sh
pnpm --dir tools/workbook-import install --frozen-lockfile
```

Validate the workbook without writing to Postgres:

```sh
pnpm --dir tools/workbook-import run validate
```

Run the local import:

```sh
pnpm --dir tools/workbook-import run import
```

The script defaults to `postgresql://postgres:postgres@127.0.0.1:54322/postgres` and creates a deterministic local seed auth user, profile, household, and owner membership. It uses direct Postgres access for a local/admin import only; do not move this DB URL or any privileged credentials into Flutter client code.

The import is safe to rerun. It uses deterministic IDs for the import batch,
source accounts, merchants, transactions, transaction source metadata, and
review items, plus the schema's stable `(household_id, source_fingerprint)`
transaction guard. A second run updates the same rows instead of duplicating
them.

In the completed M52-M55 transaction deletion flow, the importer honors
`deleted_transaction_sources`. A workbook row whose source fingerprint has been
tombstoned by owner transaction deletion is intentionally skipped and must not
recreate a deleted transaction; validation totals subtract suppressed rows
before comparing imported database totals.

Milestones 74-77 plan the Regex Backend Migration. Today the importer fetches
active `merchant_mapping_rules` and evaluates rule matching in Node. After M76,
the importer should call the backend `classify_statement_merchant(...)` helper
for every workbook transaction that needs future-rule classification. The
importer remains responsible for workbook parsing, deterministic IDs,
tombstone-aware suppression, upsert orchestration, and validation; Postgres owns
exact, contains, prefix, suffix, and regex matching semantics.

## Expected Fixture Totals

- Transactions: `475`
- Gross spend: `1,548,630.69`
- Refunds: `26,242.46`
- Net expense: `1,522,388.23`
- Card bill payments: `1,349,006.00`
- Initial review items: `29`

The importer validates workbook detail rows against monthly, category, merchant, and cardholder workbook summaries, then validates the inserted database rows against the same workbook summaries before marking the import batch `completed`.

## Remote or Shared Database Use

Milestone 3 does not require a remote import. If a future session imports into a shared Supabase project, pass an explicit database URL through `SPENDLENS_DB_URL` or `--db-url`, confirm the target project first, and take a backup before running. Keep privileged database URLs in local shell environment or secret storage only.
