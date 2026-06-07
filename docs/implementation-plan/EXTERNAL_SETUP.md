# External Setup Checklist

This document lists tasks that must happen outside the codebase. Codex should notify the user before each external dependency becomes necessary.

## Accounts Needed

### Supabase

Needed by Milestone 2.

User actions:

- Create a Supabase account.
- Create a development project.
- Choose a region close to the expected primary usage.
- Save the project URL and anon key for local development.
- Keep the service-role key private; never put it in Flutter.

Later production actions:

- Create a separate production project.
- Enable daily backups if using a paid plan.
- Configure spend cap or billing alerts.
- Add team access only if needed.

### Google Cloud

Needed by Milestone 9.

User actions:

- Create or choose a Google Cloud project.
- Enable Gmail API.
- Enable Cloud Pub/Sub API.
- Configure OAuth consent screen.
- Create OAuth client IDs for:
  - Server-side web application OAuth callback for Supabase/Edge Functions, not a frontend web app.
  - Android app.
- Create a Pub/Sub topic for Gmail notifications.
- Create a push subscription targeting the Supabase Gmail webhook URL.
- Grant `gmail-api-push@system.gserviceaccount.com` publish permission on the Pub/Sub topic.
- Add authorized redirect URIs for Supabase/Edge Function OAuth callback.

Milestone 9 dev setup values confirmed on 2026-06-07:

- Gmail API enabled.
- Cloud Pub/Sub API enabled.
- OAuth consent configured for SpendLens external/testing.
- Web OAuth client ID:
  `583318923554-43inqfbgrpsk8lc2ntitr2b50ladofg4.apps.googleusercontent.com`
- Gmail OAuth callback URL:
  `https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-oauth-callback`
- Pub/Sub topic:
  `projects/spendlens-498416/topics/gmail-notifications`
- Push subscription name:
  `gmail-notifications-push`
- Push endpoint:
  `https://bslsitzdvrdosubbdxpd.supabase.co/functions/v1/gmail-pubsub-webhook`

Remaining before final live OAuth/Pub/Sub testing:

- Add/request Gmail scope:
  `https://www.googleapis.com/auth/gmail.readonly`
- Add the Edge Function callback URL to the Web OAuth client.
- Deploy the Gmail Edge Functions.
- Set hosted Edge Function secrets:
  - `GOOGLE_OAUTH_CLIENT_SECRET`
  - `PUBSUB_VERIFICATION_SECRET`
- Create the push subscription after the webhook is deployed. For the shared-secret
  path implemented in Milestone 9, include `?token=<PUBSUB_VERIFICATION_SECRET>`
  on the push endpoint or provide the same value through a trusted proxy header.

### Web Hosting

Deferred. Do not set up Cloudflare Pages or another web host during the current Android-first implementation plan. Revisit this only when the user explicitly resumes web interface work.

### iOS Setup

Deferred. Do not install Xcode, CocoaPods, configure an iOS bundle identifier, create an iOS OAuth client, or enroll in the Apple Developer Program during the current Android-first implementation plan. Revisit this only when the user explicitly resumes iOS app work.

### Google Play Console

Needed before Play Store distribution.

User actions:

- Create Google Play Console account.
- Choose Android package name.
- Configure Android OAuth client ID in Google Cloud.
- Configure signing key and release track.

## Supabase Project Configuration

Required configuration:

- Enable Google Auth provider for app sign-in.
- Add redirect URLs for Android auth flows:
  - `com.olympus.spendlens://login-callback/`
- Enable required Postgres extensions:
  - `pgcrypto` or UUID generation support.
  - Supabase Vault if storing encrypted connector secrets there.
  - Supabase Queues/PGMQ if using queues.
- Apply database migrations.
- Enable RLS on app tables.
- Deploy Edge Functions.
- Configure function secrets:
  - Google OAuth client ID.
  - Google OAuth client secret.
  - Pub/Sub verification secret if used.
  - Future LLM provider API key.
- Configure scheduled functions:
  - Gmail watch renewal.
  - Gmail backfill check.
  - Optional job sweeper/retry.

## Google OAuth and Gmail Notes

Important decisions:

- App sign-in and Gmail access are separate user actions.
- Use read-only Gmail access for ingestion.
- Store refresh tokens securely.
- Allow users to disconnect Gmail.
- On disconnect, deactivate `linked_mailboxes`, stop Gmail watch if possible, and remove/rotate stored tokens.

## Billing and Cost Alerts

Set up alerts before production:

- Supabase spend/billing alerts.
- Google Cloud budget alert.
- LLM provider monthly budget limit before AI features are enabled.

Cost expectations for personal/household use:

- Edge Function invocation count should be far below normal included quotas.
- Google Pub/Sub volume should be tiny.
- LLM tokens and web search are the main future cost risk.

## Information Codex Should Ask For When Needed

Do not ask for these upfront. Ask only when the relevant milestone begins:

- Supabase project URL.
- Supabase anon key.
- Supabase service-role key, only if a local server-side command requires it.
- Google OAuth client IDs.
- Google OAuth callback URL.
- Pub/Sub topic and subscription names.
- Android package name.
- iOS bundle identifier, only when iOS app work resumes.
- Preferred web production domain, only when web interface work resumes.

Secrets should be entered into local `.env` files or platform secret stores, not pasted into source-controlled documents.
