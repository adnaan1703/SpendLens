# Gmail Connector

Milestone 9 implements the Gmail connector through Supabase Edge Functions,
Vault-backed refresh-token storage, and database ingestion jobs.

## Functions

- `gmail-oauth-start`: authenticated app call; returns the Google authorization
  URL.
- `gmail-oauth-callback`: Google OAuth callback; exchanges the code, stores the
  refresh token in Vault, configures Gmail `watch`, and queues the initial
  backfill.
- `gmail-connector-status`: authenticated app call; returns non-secret mailbox
  status.
- `gmail-disconnect`: authenticated app call; stops Gmail watch best-effort,
  clears the Vault reference, and cancels pending jobs.
- `gmail-pubsub-webhook`: public Pub/Sub push endpoint; verifies the configured
  secret and queues sync jobs idempotently.
- `gmail-sync`: service-key call; processes queued Gmail sync/backfill jobs.
- `gmail-watch-renewal`: service-key call; renews watches that are missing or
  near expiry.
- `gmail-backfill-check`: service-key call; queues daily bounded backfills for
  stale mailboxes.
- `gmail-backfill-range`: service-key call; queues explicit date-range backfill
  jobs for one active Gmail mailbox.
- `gmail-message-body`: service-key call; fetches the Gmail message body for a
  specific `source_message_id`.

## Configured Dev Values

These values are not secrets:

```sh
GOOGLE_OAUTH_CLIENT_ID=583318923554-43inqfbgrpsk8lc2ntitr2b50ladofg4.apps.googleusercontent.com
GOOGLE_OAUTH_CALLBACK_URL=https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-oauth-callback
GOOGLE_PUBSUB_TOPIC=projects/spendlens-498416/topics/gmail-notifications
PUSH_SUBSCRIPTION_NAME=gmail-notifications-push
PUSH_ENDPOINT=https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-pubsub-webhook
```

Secrets must be stored outside Git:

```sh
GOOGLE_OAUTH_CLIENT_SECRET=<set locally or in Supabase secrets>
PUBSUB_VERIFICATION_SECRET=<set locally or in Supabase secrets>
```

Local function development can use `supabase/functions/.env` or an ignored
`--env-file`. Hosted Supabase should use Edge Function Secrets:

```sh
supabase secrets set --env-file supabase/functions/.env
```

## Deployment Order

1. Apply migrations to the target Supabase project.
2. Set Edge Function secrets:
   - `GOOGLE_OAUTH_CLIENT_SECRET`
   - `PUBSUB_VERIFICATION_SECRET`
3. Deploy the Milestone 9 Edge Functions.
4. Add the callback URL to the Web application OAuth client:
   - `https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-oauth-callback`
5. Add/request the Gmail readonly scope on the Google OAuth consent screen:
   - `https://www.googleapis.com/auth/gmail.readonly`
6. Create the Pub/Sub push subscription after the webhook is deployed.

For the current shared-secret verification path, configure the push endpoint as:

```text
https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-pubsub-webhook?token=<PUBSUB_VERIFICATION_SECRET>
```

The webhook also accepts the same value in the `x-spendlens-pubsub-secret`
header for local/proxy testing.

## Scheduling

The renewal and backfill functions are implemented as service-key protected HTTP
functions. Schedule them after hosted secrets are set:

- `gmail-watch-renewal`: daily.
- `gmail-backfill-check`: daily.
- `gmail-sync`: every few minutes, or triggered by a lightweight scheduler after
  Pub/Sub notifications enqueue jobs.

The scheduled caller must send the Supabase secret key as either:

```text
Authorization: Bearer <SUPABASE_SECRET_KEY>
```

or:

```text
apikey: <SUPABASE_SECRET_KEY>
```

Do not put the secret key in Flutter or committed files.

For production scheduling, monitoring, and hosted smoke checks, use
`docs/implementation-plan/PRODUCTION_READINESS.md`.

## May 2026 Range Backfill

Milestone 13 adds an explicit hosted dev/staging runbook for importing supported
May 2026 Gmail transaction emails from the already connected mailbox.

Scope:

- Target Supabase project: `bslsitzdvrdosubbdxpd` dev/staging.
- Target transaction window: `2026-05-01` inclusive through `2026-06-01`
  exclusive.
- Supported templates only:
  - HDFC credit-card debit alerts.
  - HDFC Bank UPI debit alerts.
- Supported candidates are selected by sender and subject first, then parsed:
  - Sender: `alerts@hdfcbank.bank.in`
  - UPI subject: `You have done a UPI txn. Check details!`, allowing a leading
    alert symbol.
  - Credit-card subject: `A payment was made using your Credit Card`.
- Non-candidate HDFC alert emails are skipped. Candidate emails with body parse
  failures are recorded in `gmail_parse_attempts` with
  `parse_status =
  'parse_failed'`; they are not guessed or imported.

The app login account and connected Gmail mailbox can differ. The Gmail OAuth
URL uses `prompt=consent select_account` so the user can sign into SpendLens
with one account and choose another mailbox during Google consent.

After the user connects Gmail from Settings, confirm that hosted
`linked_mailboxes` has one active Gmail mailbox for the household and that the
mailbox email is the intended Gmail account. Then call `gmail-backfill-range`
with a server-side Supabase secret key from an ignored env file or platform
secret store:

```sh
curl -sS \
  -X POST "https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-backfill-range" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  --data '{
    "mailboxId": "<linked_mailboxes.id>",
    "transactionStartDate": "2026-05-01",
    "transactionEndDateExclusive": "2026-06-01",
    "sliceDays": 1,
    "maxCandidatesPerSlice": 200
  }'
```

This enqueues one `gmail_backfill` job per slice with deterministic idempotency
keys such as `manual-range:2026-05-01:2026-05-02`.

Run `gmail-sync` until no queued May range jobs remain:

```sh
curl -sS \
  -X POST "https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-sync" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  --data '{"limit": 10}'
```

Range jobs fetch HDFC alert-sender emails from a slightly buffered Gmail search
window. `gmail-sync` classifies messages by sender and subject, records every
UPI or credit-card parse attempt, and only ingests parsed transactions in the
strict transaction-date window `2026-05-01 <= transaction_date < 2026-06-01`.
Re-running the same range does not duplicate transactions because jobs use
deterministic idempotency keys, parse attempts upsert by message/parser, and
ingestion still upserts by `(household_id, source_fingerprint)`.
After Milestone 53, reprocessing a parsed email whose source fingerprint is
present in `deleted_transaction_sources` is treated as handled but suppressed,
so the deleted transaction does not come back to the app.

To reconcile candidate parsing for May by Gmail received timestamp:

```sql
select candidate_type, parse_status, count(*)
from public.gmail_parse_attempts
where source_received_at >= '2026-05-01'
  and source_received_at < '2026-06-01'
group by candidate_type, parse_status
order by candidate_type, parse_status;
```

To inspect body parse failures without raw email content:

```sql
select
  source_received_at,
  candidate_type,
  source_message_id,
  source_thread_id,
  parser_name,
  diagnostics
from public.gmail_parse_attempts
where parse_status = 'parse_failed'
  and source_received_at >= '2026-05-01'
  and source_received_at < '2026-06-01'
order by source_received_at;
```

To fetch the exact Gmail body for one message, call the admin helper with the
mailbox id and `source_message_id`:

```sh
supabase functions invoke gmail-message-body \
  --data '{"mailbox_id":"6a9ad3af-18bf-422a-8eaf-43ddcd7b81c8","source_message_id":"<gmail_message_id>"}'
```

The helper returns the Gmail metadata plus the extracted plain-text body that
the parser sees. Use the `source_message_id` from `gmail_parse_attempts` to look
up the exact message behind a failed parse.

Hosted verification should check:

- Active mailbox exists for the intended Gmail account.
- May range jobs are completed or intentionally skipped because they already
  completed.
- May 2026 Gmail transaction counts increased.
- `gmail_parse_attempts` shows expected `parsed`, `parse_failed`, and
  `outside_date_range` counts for UPI and credit-card candidates.
- Source account types include expected `credit_card` and/or `upi` rows.
- No duplicate `(household_id, source_fingerprint)` rows exist.
- After Milestone 53, tombstoned source fingerprints are suppressed rather than
  recreated.
- App reads May 2026 Dashboard, Transactions, Trends, and source-type filters
  without privileged credentials.

## Operational Monitoring

Gmail Edge Functions emit structured JSON log events for OAuth, Pub/Sub, sync,
renewal, backfill, and disconnect workflows. Service-role monitoring can query:

- `public.v_ingestion_operational_health`
- `public.v_parser_operational_health`
- `public.v_gmail_parse_attempt_health`

These views are not granted to `anon` or `authenticated`.

## Parser Coverage

Current parser support:

- HDFC credit-card debit alerts from `alerts@hdfcbank.bank.in` with subject
  `A payment was made using your Credit Card`.
- HDFC Bank UPI debit alerts from `alerts@hdfcbank.bank.in` with subject
  `You
  have done a UPI txn. Check details!`, with or without the leading alert
  symbol.

Gmail sync expands each candidate message to its Gmail thread before parsing, so
multiple HDFC credit-card or UPI alerts grouped into the same Gmail conversation
are processed as independent messages.

Unsupported Gmail messages are ignored by the sync function and do not create
transactions or parse-attempt rows. Supported candidates with failed body parses
create service-only `gmail_parse_attempts` rows. Unknown or non-high-confidence
merchant classifications create review items instead of silently assigning bad
categories.

UPI credit/refund parser support is still sample-gated. Add anonymized
credit/refund fixtures before implementing that template.

## Privacy Rules

- Raw email bodies are not stored.
- Body snippets are not stored in parse-attempt diagnostics.
- Gmail refresh tokens are stored in Supabase Vault.
- `linked_mailboxes.oauth_secret_ref` stores only the Vault reference.
- The Flutter app reads `v_linked_mailbox_status`, which omits secret
  references.
- Gmail message IDs, thread IDs, received time, parser name/version, parse
  status, and diagnostics are stored in `transaction_sources`.
- Candidate parse-attempt metadata and diagnostics are stored in
  `gmail_parse_attempts`, which is service-only.
