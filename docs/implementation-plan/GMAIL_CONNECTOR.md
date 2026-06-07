# Gmail Connector

Milestone 9 implements the Gmail connector through Supabase Edge Functions,
Vault-backed refresh-token storage, and database ingestion jobs.

## Functions

- `gmail-oauth-start`: authenticated app call; returns the Google authorization URL.
- `gmail-oauth-callback`: Google OAuth callback; exchanges the code, stores the refresh token in Vault, configures Gmail `watch`, and queues the initial backfill.
- `gmail-connector-status`: authenticated app call; returns non-secret mailbox status.
- `gmail-disconnect`: authenticated app call; stops Gmail watch best-effort, clears the Vault reference, and cancels pending jobs.
- `gmail-pubsub-webhook`: public Pub/Sub push endpoint; verifies the configured secret and queues sync jobs idempotently.
- `gmail-sync`: service-key call; processes queued Gmail sync/backfill jobs.
- `gmail-watch-renewal`: service-key call; renews watches that are missing or near expiry.
- `gmail-backfill-check`: service-key call; queues daily bounded backfills for stale mailboxes.

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

The renewal and backfill functions are implemented as service-key protected
HTTP functions. Schedule them after hosted secrets are set:

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

## Operational Monitoring

Gmail Edge Functions emit structured JSON log events for OAuth, Pub/Sub,
sync, renewal, backfill, and disconnect workflows. Service-role monitoring can
query:

- `public.v_ingestion_operational_health`
- `public.v_parser_operational_health`

These views are not granted to `anon` or `authenticated`.

## Parser Coverage

Current parser support:

- HDFC credit-card debit alerts matching the anonymized samples from Milestone 9.
- HDFC Bank UPI debit alerts matching the anonymized samples from Milestone 10.

Gmail sync expands each candidate message to its Gmail thread before parsing, so
multiple HDFC credit-card or UPI alerts grouped into the same Gmail conversation
are processed as independent messages.

Unsupported Gmail messages are ignored by the sync function and do not create
transactions. Unknown or non-high-confidence merchant classifications create
review items instead of silently assigning bad categories.

UPI credit/refund parser support is still sample-gated. Add anonymized
credit/refund fixtures before implementing that template.

## Privacy Rules

- Raw email bodies are not stored.
- Gmail refresh tokens are stored in Supabase Vault.
- `linked_mailboxes.oauth_secret_ref` stores only the Vault reference.
- The Flutter app reads `v_linked_mailbox_status`, which omits secret references.
- Gmail message IDs, thread IDs, received time, parser name/version, parse
  status, and diagnostics are stored in `transaction_sources`.
