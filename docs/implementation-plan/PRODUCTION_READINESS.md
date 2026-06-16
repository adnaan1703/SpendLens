# Production Readiness

Milestone 11 prepares SpendLens for real personal finance data without choosing
undocumented production project values. Use this checklist once the production
Supabase project, Google Cloud project, and Android release path are confirmed.

## Environment Split

Keep development, staging, and production values separate.

- Mobile runtime examples live in `apps/mobile/env`.
- Edge Function secret examples live in `supabase/functions/env`.
- Real `.env`, `key.properties`, and keystore files are ignored by Git.
- Flutter must use `SUPABASE_PUBLISHABLE_KEY`, not service or secret keys.
- Edge Functions and schedulers should use `SUPABASE_SECRET_KEY` or the hosted
  default `SUPABASE_SECRET_KEYS` value. Legacy `SUPABASE_SERVICE_ROLE_KEY`
  remains supported only as compatibility fallback.

## Local Readiness Gate

Start from a clean local database before the smoke gate:

```sh
supabase db reset --local
tools/production-readiness/local-smoke.sh
```

For the slower mobile release smoke:

```sh
RUN_MOBILE=1 tools/production-readiness/local-smoke.sh
```

The smoke script checks:

- no tracked local secret files;
- no backend secret references in Flutter client code;
- service-only operational views are not granted to app roles;
- public base tables have RLS;
- public reporting views use `security_invoker`;
- Supabase pgTAP, lint, and advisors;
- Edge Function formatting, linting, type-checking, and parser tests.

## Supabase Production Deployment

Do not run these against production until the production project ref is confirmed.

```sh
supabase link --project-ref <production-project-ref>
supabase db push --linked --dry-run
```

After reviewing the dry-run migration list:

```sh
supabase db push --linked
supabase secrets set --env-file supabase/functions/env/production.env
SUPABASE_PROJECT_REF=<production-project-ref> \
  tools/production-readiness/deploy-edge-functions.sh
supabase db advisors --linked --type security --level warn --fail-on none
supabase db advisors --linked --type performance --level warn --fail-on none
```

Production Supabase settings to confirm:

- Google Auth provider enabled for app sign-in.
- Android redirect URL allowed: `com.olympus.spendlens://login-callback/`.
- API keys include a publishable key for Flutter and a secret key for backend
  calls.
- Data API exposure is explicit; new public tables are not automatically exposed.
- RLS is enabled on every public base table.
- Edge Function secrets are set in the hosted secret store.
- `GEMINI_API_KEY` is set only in Edge Function secrets when AI features are
  enabled.
- `GEMINI_INPUT_COST_PER_MILLION_USD` and
  `GEMINI_OUTPUT_COST_PER_MILLION_USD` are set before disabling free-tier-only
  AI mode.
- `FCM_SERVICE_ACCOUNT_JSON` is set only in Edge Function secrets after Android
  push dispatch is implemented.
- Daily backups or PITR are enabled according to the chosen Supabase plan.
- Supabase billing/spend alerts are configured.

## Firebase Production Setup

Use production Firebase values only after the production Android app and
Supabase project are confirmed.

- Create or choose a Firebase project for Android push notifications.
- Register the Android app package `com.olympus.spendlens`.
- Add the production Android Firebase config to the app only after the user
  confirms whether the config should be committed or injected locally.
- Create a service account with permission to send Firebase Cloud Messaging HTTP
  v1 messages.
- Store the service account JSON as `FCM_SERVICE_ACCOUNT_JSON` in Supabase Edge
  Function secrets; never put it in Flutter or source-controlled docs.
- Verify Android 13+ notification permission behavior on a real device or
  emulator with Google Play services.

## Google Production Setup

Use production Google Cloud OAuth and Pub/Sub values, not the dev project values.

- Enable Gmail API and Cloud Pub/Sub API.
- Add/request Gmail scope:
  `https://www.googleapis.com/auth/gmail.readonly`.
- Add the production callback URL to the Web OAuth client:
  `https://<production-project-ref>.supabase.co/functions/v1/gmail-oauth-callback`.
- Create a production Pub/Sub topic and push subscription.
- Grant `gmail-api-push@system.gserviceaccount.com` publisher access to the
  topic.
- Confirm the connected mailbox has the nested Gmail label
  `Banking/HDFC Transactions`; Gmail watch, history sync, and backfill use the
  resolved label id and do not fall back to Inbox/sender discovery.
- Configure the push endpoint after `gmail-pubsub-webhook` is deployed:
  `https://<production-project-ref>.supabase.co/functions/v1/gmail-pubsub-webhook?token=<PUBSUB_VERIFICATION_SECRET>`.
- Configure a Google Cloud budget alert before live ingestion.

## Scheduling

Schedule these service-key protected functions after hosted secrets are set:

- `gmail-sync`: every few minutes, or triggered by a lightweight scheduler.
- `gmail-watch-renewal`: daily.
- `gmail-backfill-check`: daily.
- `send-push-notifications`: every minute or every few minutes after push
  dispatch is implemented.

For Supabase-hosted scheduling, use `pg_cron` plus `pg_net` and store the
project URL plus secret key in Vault. With the new Supabase key model, send the
secret key on the `apikey` header.

## Monitoring

Edge Functions now write structured JSON log events. Monitor these event names:

- `gmail_oauth_start_created`
- `gmail_oauth_callback_completed`
- `gmail_pubsub_notification_queued`
- `gmail_sync_job_completed`
- `gmail_sync_job_failed`
- `gmail_sync_run_completed`
- `gmail_watch_renewal_completed`
- `gmail_backfill_check_completed`
- `gmail_disconnect_completed`
- `expense_qa_completed`
- `expense_qa_failed`
- `transaction_metadata_suggestion_completed`
- `transaction_metadata_suggestion_failed`
- `transaction_notification_batch_queued`
- `transaction_notification_batch_skipped`
- `push_dispatch_started`
- `push_outbox_claimed`
- `push_delivery_sent`
- `push_delivery_skipped`
- `push_delivery_failed`
- `push_device_deactivated`
- `push_outbox_completed`
- `push_dispatch_failed`

Service-role SQL health views:

```sql
select *
from public.v_ingestion_operational_health
order by mailbox_error_count desc, failed_job_count desc;
```

```sql
select *
from public.v_parser_operational_health
order by last_source_received_at desc nulls last;
```

Operational response rules:

- `mailbox_error_count > 0`: inspect `latest_mailbox_error`, then ask the user
  to reconnect Gmail if the token was revoked.
- `watch_expiring_48h_count > 0`: run or inspect `gmail-watch-renewal`.
- `stale_sync_mailbox_count > 0`: run or inspect `gmail-backfill-check`.
- `retrying_job_count > 0`: inspect Edge logs for transient Gmail/API failures.
- `permanently_failed_job_count > 0`: inspect `latest_job_error` before retrying.
- Parse-failure spikes: inspect `v_gmail_parse_attempt_health` and sanitized
  `gmail_parse_attempts` metadata; keep raw email bodies out of logs/docs.
- Parse-failure body inspection after Milestones 70-73: use the app-facing
  row-scoped body viewer for visible Review failures or the service-key admin
  helper for operator diagnostics. Do not paste raw email bodies into logs,
  tickets, or docs.
- Push delivery failures: inspect `notification_outbox`,
  `notification_deliveries`, and Edge Function logs before retrying. Permanent
  token failures should deactivate only the affected device.

## Android Release

Create local signing material outside Git:

```sh
cp apps/mobile/android/key.properties.example apps/mobile/android/key.properties
```

Fill `apps/mobile/android/key.properties` with upload-key values and keep the
keystore file outside source control. Then build a production app bundle:

```sh
cd apps/mobile
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<production-project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production-publishable-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

The `rm` removes an ignored generated registrant that can be left behind after
integration-test runs; Flutter regenerates the release-safe registrant during the
build.

Use a Google Play internal test track before wider distribution.

## Hosted Smoke

After deploying production:

- Install the internal-test Android build.
- Sign in with Google.
- Confirm the app creates or loads the profile and household.
- Confirm the target mailbox has the `Banking/HDFC Transactions` label, then
  connect Gmail from Settings.
- Confirm `v_ingestion_operational_health` reports an active mailbox with no
  current mailbox error and the resolved watched label metadata.
- Send or receive one supported HDFC credit-card, UPI debit, or
  `Netbanking :: IMPS` debit email carrying the watched label.
- Confirm the transaction appears once, source filters work, and unknown
  merchants create review items.
- Confirm unsupported watched-label messages appear only as sanitized Review
  parse failures, can be paged through when there are more than one page, can
  open a plain-text body dialog after Milestones 70-73, and can be hidden with
  `Ignore for now`.
- If push notifications are enabled, confirm the Android device is registered,
  run or wait for `send-push-notifications`, receive one transaction
  notification, tap it, and verify the app opens Transactions.
- Disconnect Gmail and confirm the mailbox is inactive with no queued jobs.

Do not import production email fixtures or raw email bodies into Git.
