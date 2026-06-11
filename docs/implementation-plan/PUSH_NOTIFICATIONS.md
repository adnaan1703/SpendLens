# Push Notifications Plan

Last updated: 2026-06-11

This document is the implementation plan for Android push notifications when
new SpendLens transactions are processed. Each milestone below is a standalone
milestone intended to be executed in a separate Codex thread. Stop after
completing and documenting the current milestone; do not automatically continue
to the next milestone.

## Target Behavior

SpendLens should notify signed-in Android users when new transactions are
processed for a household they belong to. The v1 push provider is Firebase Cloud
Messaging (FCM). Supabase remains the source of truth for device registration,
notification preferences, notification queueing, delivery state, and ingestion
events.

Notifications should be emitted after successful transaction processing, not
while parsing is still speculative. Gmail sync and future batch processors should
send one notification per completed processing batch. Direct one-off
non-workbook transaction inserts can send a single-transaction notification.
Reprocessing an existing Gmail message or duplicate source fingerprint must not
notify again.

Default notification content should include transaction details because the
selected product default is full details. A user-facing setting must allow a
user to hide merchant and amount details later without changing backend
delivery.

Example single-transaction notification:

```text
New transaction processed
INR 899.00 at Zomato is ready in SpendLens
```

Example batch notification:

```text
5 new transactions processed
Latest: INR 899.00 at Zomato and 4 more
```

## Existing Foundation

- Flutter Android app lives under `apps/mobile` and uses Riverpod providers,
  `SupabaseFinanceRepository`, `SupabaseAuthRepository`, and Settings cards for
  account, Gmail connector, categories, and AI settings.
- The active Android package is `com.olympus.spendlens`.
- Supabase schema already has `profiles`, `households`, `household_members`,
  `transactions`, `transaction_sources`, `linked_mailboxes`, and
  `ingestion_jobs`.
- Gmail sync is service-key protected and calls
  `public.ingest_gmail_transaction(...)`, which returns `inserted boolean`.
  `gmail-sync` already counts inserted vs updated rows.
- Gmail ingestion is idempotent on `(household_id, source_fingerprint)`.
  Notification enqueueing must use the same duplicate boundary.
- Edge Functions use shared helpers in `supabase/functions/_shared`, including
  `createServiceClient`, `requireServiceRequest`, `requiredEnv`, and
  `logOperationalEvent`.
- Service-only operational behavior is documented in `PRODUCTION_READINESS.md`;
  structured logs must not expose raw Gmail bodies, OAuth codes, Supabase secret
  keys, FCM tokens, or Firebase private keys.

## Global Rules For M18-M21

- Execute exactly one milestone when asked. After the requested milestone is
  implemented, verified, cleaned up, and documented, stop and report the result.
  Do not start, partially implement, or prepare later milestones unless the user
  explicitly asks to proceed.
- Preserve the Android-first scope. Do not add iOS or web push support in this
  sequence.
- Use FCM for push delivery and Supabase for all app state, RLS, queueing,
  auditing, and privileged dispatch.
- Do not commit or print real FCM service account JSON, Supabase secret keys, or
  production Firebase project values.
- Ask the user for Firebase project/app values when M18 starts. Do not invent
  Firebase project IDs, sender IDs, app IDs, package names, or service account
  values.
- Prefer app-facing `security invoker` RPCs for registration/preferences when
  this keeps validation centralized. Keep dispatcher and outbox mutation
  service-only.
- Enable RLS on app-accessible tables. Revoke app-role access from service-only
  queue/delivery tables even if they live in `public`.
- Keep transaction notification dispatch asynchronous. Transaction imports and
  Gmail sync jobs must still complete if FCM is unavailable.
- Use one notification per Gmail sync/backfill job with at least one newly
  inserted transaction. Do not notify for duplicate reprocessing where
  `inserted = false`.
- Do not notify for workbook seed imports by default. Historical imports can be
  summarized manually in future work if the user asks.
- Default `include_sensitive_details` to `true`, matching the selected product
  default, but include a per-user Settings toggle that can hide merchant and
  amount details.
- Use `net_expense` only for spend summaries. For notification display amounts,
  use the transaction source amount display helper specified in M19 so refunds,
  credits, and card payments are not mislabeled as spend.
- Add focused tests in the same milestone as any schema, RPC, Edge Function, or
  Flutter behavior change.
- At completion, update `SESSION_HANDOFF.md` and include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M18 - Firebase Client And Device Registration

Purpose: Add the Android Firebase/FCM client foundation and a secure Supabase
registration surface for user device tokens.

Instructions:

- Start by reading:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - this plan
  - `apps/mobile/pubspec.yaml`
  - `apps/mobile/android/settings.gradle.kts`
  - `apps/mobile/android/app/build.gradle.kts`
  - `apps/mobile/android/app/src/main/AndroidManifest.xml`
  - `apps/mobile/lib/main.dart`
  - `apps/mobile/lib/src/core/bootstrap/app_bootstrap.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
  - `apps/mobile/lib/src/features/settings/settings_screen.dart`
- Ask the user for the Firebase Android app configuration before editing
  Firebase-specific files:
  - Firebase project id.
  - Firebase Android app id for package `com.olympus.spendlens`.
  - Whether the generated Android Firebase config file may be committed for the
    selected dev/staging project. Recommended default: commit the non-secret
    dev/staging Android config if the user confirms this is the repo's intended
    dev/staging Firebase app.
  - Do not ask for FCM service account JSON in this milestone; that belongs to
    M20.
- Add Flutter dependencies:
  - `firebase_core`
  - `firebase_messaging`
  - `shared_preferences`
  - Add only packages needed by this milestone. Do not add local notification,
    analytics, crash reporting, or deep-link packages unless a compile-time FCM
    requirement proves they are necessary.
- Configure Android Firebase for Flutter:
  - Apply the Google Services Gradle plugin in the Android Gradle files using
    the current Kotlin DSL style.
  - Add the user-provided Firebase Android config in the standard Android app
    location when the user confirms it may be tracked.
  - Keep any private Firebase admin/service-account credentials out of the
    mobile app.
- Update `AndroidManifest.xml`:
  - Add `android.permission.POST_NOTIFICATIONS`.
  - Keep existing auth deep-link configuration unchanged.
  - Do not add broad notification services manually unless
    `firebase_messaging` requires a manifest entry not generated by the plugin.
- Add a small notification client layer under `apps/mobile/lib/src/core` or
  `apps/mobile/lib/src/data/repositories`:
  - Initialize Firebase before `runApp`.
  - Obtain the FCM registration token only after the user requests/accepts
    notification setup from Settings.
  - Listen for token refresh and re-register the device when the token changes.
  - Create or load a stable local installation id using `shared_preferences`.
    This id is not a secret and should survive app restarts.
  - Expose permission, token registration, and preference state through Riverpod
    providers.
- Add Supabase schema through a migration created with
  `supabase migration new <descriptive_name>`:
  - `public.push_devices`
    - `id uuid primary key default gen_random_uuid()`
    - `household_id uuid not null references public.households(id) on delete cascade`
    - `profile_id uuid not null references public.profiles(id) on delete cascade`
    - `installation_id text not null`
    - `platform text not null check (platform in ('android'))`
    - `fcm_token text not null`
    - `token_hash text not null`
    - `app_version text`
    - `device_label text`
    - `is_active boolean not null default true`
    - `last_seen_at timestamptz not null default now()`
    - `revoked_at timestamptz`
    - timestamps
    - unique `(profile_id, installation_id)`
    - unique `(token_hash)`
  - `public.notification_preferences`
    - `id uuid primary key default gen_random_uuid()`
    - `household_id uuid not null references public.households(id) on delete cascade`
    - `profile_id uuid not null references public.profiles(id) on delete cascade`
    - `transaction_push_enabled boolean not null default true`
    - `include_sensitive_details boolean not null default true`
    - timestamps
    - unique `(household_id, profile_id)`
  - Use SHA-256 for `token_hash` so tests and service logic can dedupe without
    logging raw FCM tokens.
- Add app-facing RPCs:
  - `public.register_push_device(p_household_id uuid, p_installation_id text, p_fcm_token text, p_app_version text default null, p_device_label text default null)`
    - `security invoker`.
    - Resolve the signed-in `profiles` row from `auth.uid()`.
    - Require active membership in `p_household_id`.
    - Trim and reject blank installation ids and FCM tokens.
    - Upsert by `(profile_id, installation_id)`.
    - Set `platform = 'android'`, `is_active = true`, `revoked_at = null`,
      `last_seen_at = now()`, and `token_hash = encode(digest(..., 'sha256'), 'hex')`.
    - Ensure a default `notification_preferences` row exists.
  - `public.unregister_push_device(p_household_id uuid, p_installation_id text)`
    - `security invoker`.
    - Mark only the signed-in profile's matching device inactive.
  - `public.set_notification_preferences(p_household_id uuid, p_transaction_push_enabled boolean, p_include_sensitive_details boolean)`
    - `security invoker`.
    - Upsert only the signed-in profile's preference row for an active
      household membership.
  - `public.get_notification_settings(p_household_id uuid)` or a
    `security_invoker` view that returns current preference and active device
    status for the signed-in profile.
- RLS and grants:
  - Enable RLS on `push_devices` and `notification_preferences`.
  - Let authenticated users select only their own rows through profile and
    active household membership checks.
  - Prefer RPC-only writes; if direct writes are granted, include strict `USING`
    and `WITH CHECK` ownership policies.
  - Do not expose raw FCM tokens to other household members.
- Update Settings UI:
  - Add a Notifications card below Gmail or AI.
  - Show Android notification permission state.
  - Show whether this app installation is registered for the current household.
  - Include actions:
    - Enable/register notifications.
    - Disable notifications for this installation.
    - Toggle transaction push notifications.
    - Toggle merchant/amount details in notifications.
  - Use existing Settings card visual style and Riverpod invalidation patterns.
  - Do not request notification permission during app startup.
- Tests:
  - Add pgTAP tests for RPC success, non-member rejection, viewer behavior if
    write access should be allowed for notification preference only, duplicate
    installation upsert, token rotation, unregister behavior, and RLS isolation.
  - Add Flutter tests with fake notification/repository providers for Settings
    card states: not configured, permission denied, registered, disabled, and
    sensitive-details toggle.

Expected code shape:

- Firebase initialization belongs in the app bootstrap path before
  `SpendLensApp` is rendered.
- Notification registration should be a small repository/service, not embedded
  directly in `SettingsScreen`.
- `FinanceRepository` may expose notification preference methods if that remains
  the repo's broad app-data pattern, but keep platform permission/token logic in
  a mobile notification service.
- Tests should avoid contacting Firebase. Mock token and permission state.

Acceptance criteria:

- A signed-in Android user can enable push notifications from Settings.
- The app obtains an FCM token only after user action and registers it in
  Supabase for the active household/profile.
- Token refresh updates the existing installation row instead of creating
  duplicate active devices.
- A user can disable transaction notifications or hide sensitive details.
- Non-members cannot register a device or update preferences for another
  household.
- No service keys or Firebase admin credentials are present in Flutter files.

Verification:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --no-pub
cd ../..
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Do not start M19.

## M19 - Notification Outbox And Transaction Enqueue Contract

Purpose: Add durable notification queueing and connect successful transaction
creation to one queued notification per processing batch.

Instructions:

- Start by reading:
  - this plan
  - `docs/implementation-plan/INGESTION.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `supabase/migrations/20260604203957_create_spendlens_foundation.sql`
  - `supabase/migrations/20260607131628_gmail_connector_ingestion.sql`
  - `supabase/functions/gmail-sync/index.ts`
  - `supabase/functions/_shared/observability.ts`
  - M18 completion notes in `SESSION_HANDOFF.md`
- Add queue/delivery schema through a new Supabase migration:
  - `public.notification_outbox`
    - `id uuid primary key default gen_random_uuid()`
    - `household_id uuid not null references public.households(id) on delete cascade`
    - `event_type text not null check (event_type in ('transaction_batch'))`
    - `source_type public.source_type not null`
    - `source_job_id uuid`
    - `idempotency_key text not null`
    - `transaction_ids uuid[] not null`
    - `transaction_count integer not null check (transaction_count > 0)`
    - `detail_title text not null`
    - `detail_body text not null`
    - `private_title text not null`
    - `private_body text not null`
    - `data jsonb not null default '{}'::jsonb`
    - `status text not null default 'queued' check (status in ('queued', 'processing', 'sent', 'failed', 'cancelled'))`
    - `attempt_count integer not null default 0`
    - `max_attempts integer not null default 5`
    - `next_attempt_at timestamptz not null default now()`
    - `locked_at timestamptz`
    - `locked_by text`
    - `sent_at timestamptz`
    - `failed_at timestamptz`
    - `last_error text`
    - timestamps
    - unique `(household_id, event_type, idempotency_key)`
  - `public.notification_deliveries`
    - `id uuid primary key default gen_random_uuid()`
    - `outbox_id uuid not null references public.notification_outbox(id) on delete cascade`
    - `push_device_id uuid references public.push_devices(id) on delete set null`
    - `profile_id uuid references public.profiles(id) on delete set null`
    - `fcm_token_hash text`
    - `status text not null default 'queued' check (status in ('queued', 'sent', 'failed', 'skipped'))`
    - `attempt_count integer not null default 0`
    - `provider_message_id text`
    - `provider_error_code text`
    - `last_error text`
    - `sent_at timestamptz`
    - timestamps
    - unique `(outbox_id, push_device_id)`
  - Keep both tables service-only:
    - Enable RLS.
    - Revoke all from `anon` and `authenticated`.
    - Grant required access to `service_role`.
    - Add no app-user policies unless a later UI needs read-only history.
- Add service-only helper functions:
  - `public.enqueue_transaction_notification_batch(p_household_id uuid, p_source_type public.source_type, p_source_job_id uuid, p_idempotency_key text, p_transaction_ids uuid[])`
    - `security definer`, narrow `search_path`, executable only by
      `service_role`.
    - Remove null/duplicate ids from `p_transaction_ids`.
    - Validate all selected transactions belong to `p_household_id`.
    - Return without enqueueing if the final transaction id list is empty.
    - Build both detailed and private notification text.
    - Insert one outbox row with unique idempotency. On conflict, keep the
      existing queued/sent row and return it instead of creating a duplicate.
  - `public.claim_notification_outbox(p_limit integer, p_worker_id text)`
    - Service-only.
    - Select queued rows where `next_attempt_at <= now()`.
    - Use row locking/skip-locked semantics where available.
    - Mark claimed rows `processing`, increment `attempt_count`, set
      `locked_at`, `locked_by`, and return rows for the dispatcher.
  - `public.mark_notification_outbox_sent(...)` and
    `public.mark_notification_outbox_failed(...)`, or one status-update RPC with
    strict status validation.
- Notification text rules:
  - Use `coalesce(merchants.display_name, transactions.statement_merchant)` as
    the merchant label.
  - Use `currency_code` plus a two-decimal display amount.
  - For `debit_spend`, display `gross_spend`.
  - For refunds/reversals, display `refund_amount` and use wording that does
    not call it spend.
  - For card bill payments/credits with `net_expense = 0`, use neutral wording
    such as `payment or credit`.
  - For private content, use:
    - Title: `New transaction processed` or `<n> new transactions processed`
    - Body: `Open SpendLens to review the latest transaction.`
  - Include `data` fields: `event_type`, `household_id`, `transaction_count`,
    `notification_id`, `source_type`, and `route = '/transactions'`.
- Update Gmail sync:
  - Continue using `public.ingest_gmail_transaction(...)` as the only write path
    for parsed Gmail transactions.
  - Accumulate transaction ids only when `result.inserted === true`.
  - After a job completes successfully and before marking `ingestion_jobs`
    completed, call `enqueue_transaction_notification_batch`.
  - Use idempotency key `gmail-job:<ingestion_jobs.id>` for Gmail sync/backfill
    jobs.
  - Preserve current processing if notification enqueue fails only because of a
    duplicate idempotency key. For unexpected enqueue errors, fail/retry the job
    so the transaction batch and notification queue remain auditable.
  - Add structured logs:
    - `transaction_notification_batch_queued`
    - `transaction_notification_batch_skipped`
    - Do not log raw FCM tokens.
- Add direct insert fallback:
  - Add an `AFTER INSERT` trigger for direct one-off rows where
    `source_type in ('manual', 'api')`.
  - Do not trigger for `source_type = 'workbook'` or `source_type = 'gmail'`.
  - Use idempotency key `transaction:<transactions.id>`.
  - This provides future coverage for direct app/API-created transactions
    without duplicating Gmail or workbook behavior.
- Tests:
  - Add pgTAP coverage for outbox RLS/grants, enqueue idempotency, empty
    transaction list no-op, cross-household rejection, detail/private text, and
    direct insert trigger behavior.
  - Add Gmail ingestion test coverage proving:
    - A job with two newly inserted transactions creates one outbox row.
    - Reprocessing the same source fingerprints does not create a second outbox
      row with new delivery work.
    - Workbook imports do not create notification outbox rows.

Expected code shape:

- Notification batching belongs after transaction persistence. Do not put push
  queue writes inside parser functions.
- `gmail-sync` should pass only inserted transaction ids from its existing
  result counts. Do not infer newness by querying timestamps.
- The outbox stores notification intent. It does not call FCM in this milestone.

Acceptance criteria:

- Newly inserted Gmail transactions from one sync/backfill job create exactly
  one queued transaction-batch outbox row.
- Duplicate Gmail reprocessing creates no additional notification work.
- Direct future manual/API transaction inserts create one single-transaction
  outbox row.
- Workbook seed/import rows do not create notification spam.
- Outbox and delivery tables are not readable or writable by normal app roles.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
cd supabase/functions
deno fmt --check gmail-sync _shared tests
deno lint gmail-sync _shared tests
deno check gmail-sync/index.ts
deno test --allow-env --allow-net tests
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Do not start M20.

## M20 - FCM Dispatcher Edge Function

Purpose: Deliver queued transaction notifications through FCM HTTP v1 without
blocking ingestion jobs or exposing Firebase credentials to clients.

Instructions:

- Start by reading:
  - this plan
  - M18 and M19 completion notes in `SESSION_HANDOFF.md`
  - `supabase/functions/_shared/supabase.ts`
  - `supabase/functions/_shared/http.ts`
  - `supabase/functions/_shared/observability.ts`
  - `docs/implementation-plan/PRODUCTION_READINESS.md`
  - Firebase FCM HTTP v1 docs linked at the end of this plan
- Ask the user for the Firebase service account JSON only as a local secret file
  or hosted Supabase secret. Do not ask them to paste the private key into chat.
- Add `supabase/functions/send-push-notifications/index.ts`:
  - Protect the function with `requireServiceRequest(req)`.
  - Accept optional JSON body:
    - `limit` default 10, max 50.
    - `dryRun` default false.
    - `workerId` optional, default to `SB_EXECUTION_ID` or a generated value.
  - Claim queued outbox rows through the service-only RPC from M19.
  - For each outbox row, load active Android `push_devices` joined with
    `notification_preferences` for active household members.
  - Skip users with `transaction_push_enabled = false`.
  - Choose detail vs private title/body per profile using
    `include_sensitive_details`.
  - Create or reuse one `notification_deliveries` row per outbox/device.
  - Send each unsent delivery to FCM.
  - Mark delivery rows as sent, skipped, or failed.
  - Mark the outbox sent only after all eligible deliveries are sent or skipped.
  - If all eligible devices are missing or disabled, mark outbox sent with a
    structured `no_eligible_devices` result instead of retrying forever.
- Add `supabase/functions/_shared/fcm.ts`:
  - Read `FCM_SERVICE_ACCOUNT_JSON` from Edge Function secrets.
  - Parse only these required fields: `project_id`, `client_email`,
    `private_key`.
  - Mint an OAuth JWT using Web Crypto and exchange it for an access token with
    scope `https://www.googleapis.com/auth/firebase.messaging`.
  - Cache the access token in module memory until shortly before expiry.
  - Send to:
    `https://fcm.googleapis.com/v1/projects/<project_id>/messages:send`
  - Use a `message` payload with:
    - `token`
    - `notification.title`
    - `notification.body`
    - `data` values converted to strings
    - Android priority `HIGH`
    - A notification channel id such as `transactions`
  - Do not log full tokens, private keys, or request bodies containing tokens.
- FCM error handling:
  - Treat `UNREGISTERED`, `INVALID_ARGUMENT` for a token, or equivalent
    permanent token errors as invalid-device outcomes. Mark the `push_devices`
    row inactive with `revoked_at = now()`.
  - Treat 429 and 5xx responses as transient. Leave the outbox retryable with
    exponential backoff.
  - Treat malformed credentials or missing secret as a function-level failure
    that leaves the outbox retryable and logs `push_dispatch_failed`.
  - Store provider message ids when FCM returns success.
- Add dispatcher logs:
  - `push_dispatch_started`
  - `push_outbox_claimed`
  - `push_delivery_sent`
  - `push_delivery_skipped`
  - `push_delivery_failed`
  - `push_device_deactivated`
  - `push_outbox_completed`
  - `push_dispatch_failed`
- Add local and hosted secret examples:
  - Update `supabase/functions/env/staging.env.example` and
    `supabase/functions/env/production.env.example` with
    `FCM_SERVICE_ACCOUNT_JSON=<json stored only in secret manager/local env>`.
  - Do not add real JSON values.
- Scheduling:
  - Add docs/runbook entries for invoking `send-push-notifications` every minute
    or every few minutes with the Supabase secret key.
  - The scheduler can be `pg_cron` plus `pg_net` like other service functions,
    but implementation should first support manual service-key invocation.
  - Do not require Gmail sync to call the dispatcher inline. It may optionally
    invoke it later, but queued outbox rows must be enough for delivery.
- Tests:
  - Add Deno tests for FCM JWT construction with a generated test key or a
    fake signer. Do not commit real service account material.
  - Add Deno tests for send success, permanent token failure, transient retry,
    missing secret, preference-based private vs detailed content, and no
    eligible devices.
  - Add pgTAP or function-level tests for claim/update delivery state if not
    already covered in M19.

Expected code shape:

- Keep FCM integration in `_shared/fcm.ts` so future Edge Functions can reuse it.
- Keep dispatch orchestration in `send-push-notifications/index.ts`.
- Use existing shared HTTP/CORS helpers and operational logging conventions.
- Do not add Firebase Admin SDK to Flutter. Do not add service account JSON to
  repository files.

Acceptance criteria:

- A service-key call can dispatch queued outbox rows to mocked FCM endpoints in
  tests.
- Successful FCM sends create sent delivery rows and mark outbox sent.
- Invalid tokens deactivate only the affected device and do not fail the whole
  batch.
- Transient FCM errors leave outbox rows queued for retry with clear
  operational logs.
- Missing or malformed FCM credentials fail safely without losing queued
  notification intent.

Verification:

```bash
cd supabase/functions
deno fmt --check send-push-notifications _shared tests
deno lint send-push-notifications _shared tests
deno check send-push-notifications/index.ts
deno test --allow-env --allow-net tests
cd ../..
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Do not start M21.

## M21 - End-To-End UX, Observability, And Runbooks

Purpose: Complete the user-facing notification loop and document production
operation, smoke testing, and troubleshooting.

Instructions:

- Start by reading:
  - this plan
  - M18-M20 completion notes in `SESSION_HANDOFF.md`
  - `docs/implementation-plan/EXTERNAL_SETUP.md`
  - `docs/implementation-plan/PRODUCTION_READINESS.md`
  - `apps/mobile/README.md`
  - `supabase/README.md`
  - `apps/mobile/lib/src/app/router.dart`
  - `apps/mobile/lib/src/features/transactions/transactions_screen.dart`
  - `apps/mobile/lib/src/data/repositories/finance_repository.dart`
- Add app notification handling:
  - Configure foreground message handling with `FirebaseMessaging.onMessage`.
  - Configure notification tap handling with `getInitialMessage()` and
    `onMessageOpenedApp`.
  - On a transaction notification tap, route to `/transactions`.
  - Refresh transaction, dashboard, available-month, trend, and review providers
    for the active household where practical.
  - For foreground messages, show a lightweight in-app notice and refresh data.
    Do not rely on a system tray notification while the app is foregrounded.
  - Do not auto-open the exact transaction detail in v1; only route to the
    Transactions screen. Exact-detail navigation can be a later milestone.
- Add notification channel setup if required by the chosen Flutter/Firebase
  implementation:
  - Channel id: `transactions`.
  - Human label: `Transactions`.
  - Purpose: transaction processing notifications.
  - Keep the implementation Android-only.
- Add service observability:
  - Add a service-only view or documented SQL queries for:
    - queued outbox count
    - failed outbox count
    - oldest queued notification age
    - sent count by day
    - invalid/deactivated token count
    - latest push dispatch error
  - If a view is added, keep it service-only unless there is a user-facing need.
- Update documentation:
  - `docs/implementation-plan/README.md`
  - `docs/implementation-plan/ARCHITECTURE.md`
  - `docs/implementation-plan/DATA_MODEL.md`
  - `docs/implementation-plan/EXTERNAL_SETUP.md`
  - `docs/implementation-plan/PRODUCTION_READINESS.md`
  - `apps/mobile/README.md`
  - `supabase/README.md`
  - `docs/implementation-plan/SESSION_HANDOFF.md`
  - Keep docs explicit that FCM service account JSON is a secret and belongs in
    Supabase Edge Function secrets or a local ignored env file only.
- Add hosted smoke checklist:
  - Build/install Android app configured for the hosted Supabase project and the
    user-confirmed Firebase Android app.
  - Sign in.
  - Enable notifications from Settings.
  - Verify a `push_devices` row exists for the signed-in profile and household.
  - Connect Gmail if needed.
  - Process or enqueue one supported transaction batch.
  - Run `send-push-notifications` with service-key auth or wait for scheduler.
  - Verify the Android device receives a notification with full details when the
    sensitive-detail toggle is enabled.
  - Tap notification and verify the Transactions screen opens/refetches.
  - Disable sensitive details and repeat with a private notification body.
- Add tests:
  - Flutter tests for notification tap routing and provider refresh behavior
    using fake message streams/controllers.
  - Flutter tests for foreground notice behavior.
  - Database tests or documented SQL checks for operational view access.
  - If a local emulator/device is unavailable, document that physical push
    receipt was not exercised and list the exact hosted smoke steps remaining.

Expected code shape:

- App notification handling should live in a small controller/service injected
  through Riverpod, not inside individual screens.
- Navigation should use the existing `go_router` setup.
- Provider refresh should reuse existing provider invalidation rather than
  creating a separate transaction cache.
- Operational docs should be concise but executable by a future fresh session.

Acceptance criteria:

- Notification taps route a signed-in user to Transactions.
- Foreground push events refresh app data and show a non-blocking notice.
- Operators have a documented way to see queued, sent, failed, stale, and
  invalid-token notification state.
- External setup and production readiness docs include Firebase/FCM setup,
  secrets, scheduler, and smoke-test steps.
- The sequence leaves iOS/web notification support explicitly deferred.

Verification:

```bash
cd apps/mobile
flutter analyze
flutter test
flutter build apk --debug --no-pub
cd ../..
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
cd supabase/functions
deno fmt --check send-push-notifications _shared tests
deno lint send-push-notifications _shared tests
deno check send-push-notifications/index.ts
deno test --allow-env --allow-net tests
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Do not start any later milestone.

## Deferred Scope

- iOS push notifications.
- Web push notifications.
- Exact transaction-detail deep link from notification tap.
- User-configurable quiet hours or digest schedules.
- Marketing, reminder, budget warning, or AI insight notifications.
- Push notification analytics beyond operational delivery state.
- Retrying notification content generation with an LLM.

## Reference Docs

- Firebase Cloud Messaging Flutter setup:
  https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- Firebase Cloud Messaging HTTP v1 send API:
  https://firebase.google.com/docs/cloud-messaging/send/v1-api
- Android notification runtime permission:
  https://developer.android.com/develop/ui/compose/notifications/notification-permission
- Supabase Edge Function secrets:
  https://supabase.com/docs/guides/functions/secrets
- Supabase Edge Functions:
  https://supabase.com/docs/guides/functions
