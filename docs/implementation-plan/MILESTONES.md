# SpendLens Milestones

Each milestone is intended to be executable in a separate thread. A new thread should read `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `INGESTION.md`, and the active milestone before making changes.

## Milestone 1: Project Foundation

### Objective

Create the initial Flutter Android and Supabase project structure with local development conventions, environment handling, testing scaffolds, and documentation references.

### Tasks

- Create Flutter app scaffold for Android.
- Choose package name and app name consistently across platforms.
- Add core Flutter packages:
  - Supabase Flutter SDK.
  - Routing package.
  - State management package.
  - Charting package.
  - Test packages.
- Add project directories for:
  - App shell.
  - Feature modules.
  - Shared UI components.
  - Data repositories.
  - Supabase functions and migrations.
- Add environment template files for local/staging/prod without committing secrets.
- Add local setup documentation that points back to this implementation plan.
- Add basic CI checks if repository hosting is available:
  - Flutter analyze.
  - Flutter test.
  - Supabase migration lint/check if available.

### External Work

- None required yet.
- User may choose app display name, package name, and repo hosting before this milestone starts.

### Acceptance Criteria

- `flutter test` passes.
- `flutter analyze` passes.
- Flutter app can run locally on an Android emulator and show a placeholder authenticated-app shell.
- Supabase folder structure exists, but no production project is required yet.
- No secrets are committed.

## Milestone 2: Supabase Schema, RLS, and Local Backend

### Objective

Create the database foundation that all later features depend on.

### Tasks

- Create Supabase migrations for identity, household, source, category, merchant, transaction, review, piggy-bank, and import tables.
- Add enum/check constraints listed in `DATA_MODEL.md`.
- Add indexes for:
  - `household_id`.
  - transaction date.
  - source fingerprint.
  - normalized merchant.
  - open review items.
  - monthly budget lookups.
- Enable RLS on all app-accessible tables.
- Add household membership policies.
- Add insert/update/delete policies appropriate for owner/admin/member roles.
- Add summary views:
  - `v_monthly_spend`
  - `v_category_monthly_spend`
  - `v_budget_progress`
  - `v_merchant_summary`
  - `v_review_queue`
  - `v_piggy_bank_balances`
- Add seed migration or seed script for default categories from the workbook.
- Add database tests for RLS isolation and key financial summary views.

### External Work

- User creates a Supabase development project.
- User provides local Supabase configuration values through environment files or CLI login.

### Acceptance Criteria

- Migrations apply cleanly locally.
- RLS tests prove users cannot read another household's data.
- Summary views return correct values for seeded fixture data.
- No table containing finance data is exposed without RLS.

## Milestone 3: Workbook Import and Historical Seed Data

### Objective

Import the existing FY 2025-26 workbook into the normalized database and validate that the imported records match workbook totals.

### Tasks

- Build an import script or Edge Function for workbook ingestion.
- Parse `docs/Credit Card Spend Analysis - FY 2025-26.xlsx`.
- Create one import batch for the workbook.
- Seed source accounts/cardholders.
- Upsert categories and subcategories.
- Upsert merchants and merchant aliases.
- Insert or update transactions using stable fingerprints.
- Insert transaction source metadata with `source_type = 'workbook'`.
- Create review items from `Needs Review` and low-confidence rows.
- Add fixture tests using current workbook totals:
  - 475 transactions.
  - Gross spend 1,548,630.69.
  - Refunds 26,242.46.
  - Net expense 1,522,388.23.
  - Card bill payments 1,349,006.00.
- Validate monthly, category, merchant, and cardholder totals.
- Document how to rerun the import safely.

### External Work

- None if running locally.
- User may need to approve import into Supabase dev once the script is ready.

### Acceptance Criteria

- Import is idempotent: running it twice does not duplicate transactions.
- Workbook validation passes.
- Imported category, merchant, monthly, and cardholder summaries match workbook values.
- Initial review queue is populated.

## Milestone 4: App Shell, Authentication, and Household Context

### Objective

Build the usable Flutter shell with sign-in, household loading, navigation, and route guards.

### Tasks

- Implement Supabase Auth integration.
- Add Google sign-in for Android.
- Create profile on first login.
- Create default household for first-time user.
- Implement household context provider.
- Add responsive navigation:
  - Dashboard.
  - Transactions.
  - Trends.
  - Merchant Review.
  - Piggy Banks.
  - Settings.
- Add loading, empty, and error states.
- Add sign-out flow.
- Add route protection for authenticated screens.
- Add basic design system:
  - Colors.
  - Typography.
  - Spacing.
  - Form controls.
  - Chart container conventions.

### External Work

- User configures Google Auth provider in Supabase dev.
- User configures OAuth redirect URLs for local Android development.

### Acceptance Criteria

- User can sign in and sign out.
- App creates/loads profile and household.
- Navigation works on supported Android screen sizes.
- Unauthenticated users cannot access app routes.
- No finance feature makes privileged calls from the client.

## Milestone 5: Expense Dashboard, Transactions, and Monthly Caps

### Objective

Build the core expense presentation experience using imported data.

### Tasks

- Implement dashboard KPIs:
  - Current month net spend.
  - Month-over-month change.
  - Top categories.
  - Top merchants.
  - Review queue count.
- Implement category cap setup:
  - Add/edit monthly cap per category.
  - Show uncapped categories.
  - Show spent, remaining, percent used, and over-budget state.
- Implement category spend screen:
  - Current month view.
  - Month selector.
  - Category list and progress bars.
- Implement transaction list:
  - Search by merchant text.
  - Filter by date range.
  - Filter by category.
  - Filter by source account/cardholder.
  - Show gross/refund/net semantics clearly.
- Implement transaction detail screen or panel.
- Add repository layer functions for summary views and transaction pagination.
- Add widget and integration tests for dashboard and filters.

### External Work

- None after Supabase dev is configured.

### Acceptance Criteria

- Imported workbook data is visible in dashboard and transactions.
- Category cap progress uses net expense.
- Card bill payments do not inflate spend.
- Refunds reduce category spend.
- Transaction search and filters work on realistic imported data.

## Milestone 6: Merchant Mapping and Review Workflow

### Objective

Allow the user to correct unknown or low-confidence merchant/category mappings and persist those corrections as reusable rules.

### Tasks

- Build merchant review queue UI.
- Show transaction context:
  - Date.
  - Amount.
  - Statement merchant.
  - Current merchant group/category/subcategory.
  - Confidence and reason.
- Add correction form:
  - Merchant group.
  - Category.
  - Subcategory.
  - Optional notes.
- Implement backend function/RPC to apply correction.
- Create or update manual mapping rule.
- Reclassify matching past transactions.
- Apply rule to future imports.
- Resolve related review items.
- Add audit metadata to changed rows.
- Add tests for:
  - One correction updates matching past rows.
  - Future parser/import uses the new rule.
  - Non-matching merchants remain unchanged.

### External Work

- None.

### Acceptance Criteria

- User can resolve review items.
- Correction creates a durable rule.
- Matching historical transactions update consistently.
- Review queue count decreases after resolution.

## Milestone 7: Piggy Banks

### Objective

Build manual future-expense accounts with ledger-derived balances.

### Tasks

- Implement piggy-bank list screen.
- Implement create/edit piggy bank:
  - Name.
  - Description.
  - Target amount.
  - Optional target date.
- Implement piggy-bank detail screen:
  - Current balance.
  - Target progress.
  - Entry timeline.
- Implement ledger entries:
  - Deposit.
  - Withdrawal.
  - Adjustment.
  - Note.
  - Optional linked transaction.
- Add repository functions for piggy banks and balances.
- Add validation:
  - Positive amount required.
  - Target amount cannot be negative.
  - Withdrawal cannot exceed balance in v1 unless implemented as an explicit adjustment flow.
- Add tests for balance calculations and target progress.

### External Work

- None.

### Acceptance Criteria

- User can create a piggy bank.
- Deposits and withdrawals update balance.
- Balance is derived from entries, not stored directly.
- Target progress displays correctly.

## Milestone 8: Trends and Reports

### Objective

Build the trend analysis screens that replace the workbook's monthly and summary tabs with interactive views.

### Tasks

- Implement monthly net spend trend chart.
- Implement gross vs refund vs net chart or table.
- Implement category trend view across months.
- Implement merchant summary view:
  - Merchant group.
  - Category.
  - Subcategory.
  - Transaction count.
  - Gross spend.
  - Refunds.
  - Net spend.
- Add filters shared with transactions:
  - Date range.
  - Category.
  - Cardholder/source.
- Add export option if straightforward:
  - CSV export for filtered transactions.
- Add tests for trend queries and filter behavior.

### External Work

- None.

### Acceptance Criteria

- Monthly trends match imported workbook monthly totals.
- Category and merchant summaries match imported workbook summaries.
- Charts remain legible on supported Android screen sizes.

## Milestone 9: Gmail Connector and Credit-Card Email Ingestion

### Objective

Enable ongoing transaction ingestion from Gmail for supported credit-card transaction emails.

### Tasks

- Implement Gmail connector Edge Functions:
  - Start OAuth.
  - OAuth callback.
  - Disconnect mailbox.
  - Connector status.
- Store mailbox state in `linked_mailboxes`.
- Store OAuth refresh token securely.
- Configure Gmail `watch`.
- Implement Pub/Sub webhook Edge Function.
- Implement sync job:
  - Process Gmail history.
  - Fetch candidate messages.
  - Run parser registry.
  - Upsert transaction idempotently.
  - Store transaction source metadata.
  - Create review items when needed.
- Implement HDFC credit-card transaction parser using anonymized fixtures.
- Implement scheduled watch renewal.
- Implement periodic backfill check.
- Add connector UI in Settings:
  - Connect Gmail.
  - Status.
  - Last sync.
  - Last error.
  - Disconnect.
- Add tests for parser, sync idempotency, duplicate Pub/Sub delivery, and revoked token handling.

### External Work

- User creates/configures Google Cloud project.
- User enables Gmail API and Pub/Sub API.
- User configures OAuth consent screen and client IDs.
- User creates Pub/Sub topic and push subscription.
- User grants Gmail publisher service account access to topic.
- User configures Supabase function secrets.

### Acceptance Criteria

- User can connect Gmail in dev.
- Gmail watch is active and renews.
- Pub/Sub notification enqueues sync.
- Supported HDFC emails create transactions.
- Duplicate notifications do not create duplicate transactions.
- Unsupported emails do not create bad transactions.

## Milestone 10: UPI Ingestion and Parser Expansion

### Objective

Add UPI transaction email parsing and improve ingestion coverage beyond credit-card alerts.

### Tasks

- Collect anonymized sample UPI emails from the user.
- Define parser fixtures before coding.
- Implement UPI debit parser.
- Implement UPI credit/refund parser if samples support it.
- Add source account detection for UPI handles or linked bank hints.
- Add duplicate detection across UPI templates.
- Add parser confidence rules.
- Add review items for ambiguous merchant/payee names.
- Add UI source filters for UPI vs credit card.
- Update ingestion documentation with supported templates.

### External Work

- User provides anonymized UPI email samples.
- User confirms which UPI providers/banks should be supported first.

### Acceptance Criteria

- Supported UPI emails import as transactions.
- UPI and credit-card transactions can coexist without duplicates.
- Ambiguous UPI merchants enter review instead of being misclassified.

## Milestone 11: Deployment, Security, and Production Readiness

### Objective

Prepare the system for real personal finance data and everyday use.

### Tasks

- Split staging and production configuration.
- Configure production Supabase project.
- Apply migrations to production.
- Configure production Google OAuth and Pub/Sub.
- Deploy Edge Functions.
- Configure Android builds.
- Add logging and monitoring:
  - Edge Function errors.
  - Ingestion failures.
  - Parser failure rates.
  - Job retries.
- Add billing alerts:
  - Supabase.
  - Google Cloud.
  - Future LLM provider.
- Add backup/restore checklist.
- Run security review:
  - No service keys in client.
  - RLS enabled.
  - Secrets stored in platform secret store.
  - Raw emails not retained.
- Add smoke tests for production-like environment.

### External Work

- User creates production Supabase project.
- User configures Google Cloud production OAuth details.
- User creates Google Play Console account if Android distribution is required.

### Acceptance Criteria

- Android production or internal-test build is usable.
- Production Supabase has RLS and migrations applied.
- Gmail connector works in production.
- Monitoring can identify failed ingestion.
- Billing alerts are configured.

## Milestone 12: AI-Ready Layer and LLM Features

### Objective

Add controlled LLM features without changing the app's core architecture.

### Tasks

- Add AI tables if not already present:
  - `ai_usage_events`
  - `ai_jobs`
- Add AI budget configuration:
  - Monthly household AI spend cap.
  - Per-feature enable/disable flags.
- Add backend-only LLM provider integration.
- Add expense Q&A function:
  - Validate household membership.
  - Retrieve scoped data through safe SQL views.
  - Call LLM.
  - Store token usage and answer metadata.
- Add transaction metadata suggestion function:
  - Validate household membership.
  - Retrieve scoped transaction, review, taxonomy, and nearby merchant context.
  - Use web search only when the household Suggest search flag is explicitly enabled.
  - Return a structured suggestion to the metadata editor without changing rows automatically.
- Add UI:
  - Ask expenses screen or command panel.
  - Transaction metadata Suggest action in review and transaction detail editors.
  - AI usage/budget status in settings.
- Add tests:
  - AI cannot access another household.
  - AI usage is logged.
  - Transaction metadata suggestions are budget-gated.
  - Budget cap prevents additional AI calls.
- If Edge Function limits become a problem, add a dedicated worker that consumes `ai_jobs`.

### External Work

- User creates LLM provider account.
- User configures API key in Supabase secrets.
- User sets initial monthly AI budget cap.
- User approves whether web search is enabled for transaction metadata Suggest.

### Acceptance Criteria

- LLM calls happen only from backend functions or workers.
- Every AI call is logged with token/cost metadata.
- User can ask scoped expense questions.
- Transaction metadata suggestions populate the editor and require user save before changing rows.
- AI feature respects configured budget caps.

## Milestone 13: May 2026 Gmail Backfill

### Status

Completed on 2026-06-08.

### Objective

Backfill May 2026 Gmail transaction emails for the hosted dev/staging Supabase
project without expanding parser scope or exposing privileged credentials to the
Flutter app.

### Tasks

- Add a service-only `gmail-backfill-range` Edge Function protected by the
  Supabase secret-key check.
- Validate one active Gmail mailbox and queue one `gmail_backfill` job per date
  slice.
- Use deterministic idempotency keys such as
  `manual-range:2026-05-01:2026-05-02`.
- Extend `gmail-sync` so `gmail_backfill` jobs can use payload-provided Gmail
  search date bounds and candidate limits.
- Fetch candidates from a slightly buffered Gmail search window, then ingest
  only parsed transactions in the strict transaction-date range.
- Keep parser scope limited to HDFC credit-card debit alerts and HDFC Bank UPI
  debit alerts.
- Update Gmail OAuth account selection to support connecting one Gmail mailbox
  while signed into the app with another account.
- Update Gmail connector docs and session handoff with the May 2026 runbook.

### External Work

- User signs into SpendLens with the app account.
- User connects Gmail from Settings and intentionally chooses the target Gmail
  mailbox during Google OAuth.
- A server-side caller invokes `gmail-backfill-range` and `gmail-sync` against
  project `bslsitzdvrdosubbdxpd` using a local/platform Supabase secret key.

### Acceptance Criteria

- Gmail can be connected for a different mailbox than the app login account.
- May 2026 supported HDFC credit-card and UPI debit emails are imported into the
  signed-in user's household.
- Re-running the same range does not create duplicate transactions.
- Unsupported templates are skipped and counted instead of guessed.
- Unknown or non-high-confidence merchants continue to create review items
  through the existing ingestion RPC.
- May 2026 app views update through RLS-safe client reads, not Flutter
  privileged credentials.

## Milestone 14: In-App Category Creation

### Status

Completed on 2026-06-08.

### Objective

Allow household writers to create a new category and its first subcategory from
the Android app without privileged client credentials.

### Tasks

- Add a `security invoker` `create_household_category` RPC that:
  - Validates the signed-in profile.
  - Requires household write access.
  - Trims category and subcategory names.
  - Rejects blank names.
  - Rejects case-insensitive duplicate category names within the household.
  - Creates the category and first subcategory atomically.
  - Returns the created category and subcategory IDs/names.
- Add database tests for successful creation, duplicate-name rejection, blank
  name rejection, viewer rejection, and non-member rejection.
- Extend the Flutter finance repository with a category creation request/result.
- Add a Settings category manager card with current categories/subcategories and
  a create dialog.
- Add inline category creation from the Merchant Review correction dialog and
  auto-select the newly created category/subcategory for the correction.
- Refresh shared category lookup providers after creation so filters, caps, and
  correction forms see the new values.

### External Work

- None.

### Acceptance Criteria

- A household owner/admin/member can create a category plus first subcategory
  from Settings.
- A household owner/admin/member can create and immediately select a category
  plus first subcategory while resolving a merchant review item.
- Viewers and non-members cannot create household categories.
- Duplicate category names are rejected case-insensitively.
- No service-role credentials or Edge Functions are used for this workflow.

### Deferred Scope

- Category rename, delete, reorder, merge, historical reclassification, and
  standalone subcategory management remain future taxonomy-admin work.

## Milestone 15: Transaction Metadata Editing

### Status

Completed on 2026-06-09.

### Objective

Allow household writers to edit transaction merchant/category metadata from both
Review and Transactions while keeping matching historical rows and future
ingestion rules consistent.

### Tasks

- Add a `security invoker` transaction metadata correction RPC that:
  - Validates the signed-in profile.
  - Requires household write access.
  - Validates selected transaction ownership.
  - Optionally validates an open review item for the selected transaction.
  - Trims and validates merchant group/readable merchant name.
  - Validates selected category/subcategory ownership and relationship.
  - Applies merchant/category/subcategory/confidence/notes to all transactions
    for the same normalized statement merchant in the household.
  - Creates or updates the exact manual mapping rule used for future imports.
  - Upserts the canonical merchant and merchant alias.
  - Resolves matching open review items.
  - Returns changed transaction and resolved review counts.
- Reuse or wrap the existing merchant-review correction logic to avoid duplicate
  backend behavior.
- Extend the Flutter finance repository models and API request/result types for
  transaction metadata correction.
- Add a shared metadata editor used by both Review and Transactions.
- Keep confidence editable with values `high`, `medium`, `low`, and `manual`.
- Add an Edit action to the Transactions detail bottom sheet.
- Keep Review saves resolving review items immediately.
- Reuse existing inline category creation from the metadata editor.
- Add database and Flutter regression tests for the new behavior.

### External Work

- None.

### Acceptance Criteria

- A user can edit merchant group, category, subcategory, confidence, and notes
  from the Review tab.
- A user can edit the same metadata from a transaction detail bottom sheet.
- Saving applies to matching past transactions for the normalized statement
  merchant and updates the mapping rule used by future imports.
- Review saves resolve matching open review items.
- Viewers and non-members cannot edit transaction metadata.
- Invalid category/subcategory combinations and blank merchant names are
  rejected.
- Flutter does not use service-role credentials or new privileged client code.

### Deferred Scope

- Editing amount, date, source account, transaction type, source fingerprint,
  raw statement merchant, Gmail source metadata, or parser diagnostics.
- Merchant-group-wide alias merging beyond the edited normalized statement
  merchant rule.
- Category rename, delete, reorder, merge, and standalone subcategory
  management.
- iOS and web work.

## Milestone 16: Merchant Research Retirement

### Status

Completed on 2026-06-09.

### Objective

Retire the legacy AI merchant lookup path while keeping the supported
backend-mediated expense Q&A and transaction metadata Suggest features.

### Tasks

- Remove the obsolete merchant research Edge Function and related Flutter
  models.
- Keep historical AI usage/audit rows valid.
- Keep expense Q&A and transaction metadata Suggest as the active AI features.
- Rename Suggest budget/search flags so the remaining AI settings describe the
  active feature accurately.
- Verify the hosted legacy function is absent when deleting remote functions is
  in scope.

### External Work

- None for local cleanup.
- Hosted function deletion requires the intended Supabase project to be
  confirmed before touching remote state.

### Acceptance Criteria

- The legacy merchant research path is no longer callable from the app.
- Expense Q&A and transaction metadata Suggest remain available.
- Historical AI audit data remains queryable.
- No new privileged client code is introduced.

## Milestone 17: Transaction and Trend Month Filter

### Status

Completed on 2026-06-10.

### Objective

Add shared All dates, month, and custom-period filters to Transactions and
Trends using existing date-range query fields.

### Tasks

- Add a reusable period filter component.
- Load available reporting months from `v_monthly_spend`.
- Map All dates, selected month, and custom period choices onto existing
  `startDate` and `endDate` repository query fields.
- Reuse the same filter semantics in Transactions and Trends.
- Preserve transaction search, source-account filters, category filters, and
  existing trend calculations.

### External Work

- None.

### Acceptance Criteria

- Transactions and Trends can show all available history.
- Users can select a specific reporting month.
- Users can choose a custom date range.
- Existing finance semantics still use net expense for spend views.

## Milestone 18: Firebase Client and Device Registration

### Status

Planned. See [Push Notifications](PUSH_NOTIFICATIONS.md#m18---firebase-client-and-device-registration).

### Objective

Add Android FCM client setup, notification permission handling, and Supabase
device/preference registration.

### Tasks

- Confirm Firebase project/app values before implementation:
  - Firebase project id.
  - Firebase Android app id for package `com.olympus.spendlens`.
  - Whether the generated Android Firebase config may be committed.
- Add Flutter Firebase dependencies and Android Firebase Gradle configuration.
- Initialize Firebase in the app bootstrap before rendering `SpendLensApp`.
- Add Android `POST_NOTIFICATIONS` permission and request it only from Settings.
- Add a notification client service that:
  - Creates a stable local installation id.
  - Obtains an FCM token after user action.
  - Handles token refresh.
  - Registers/unregisters the device through Supabase.
- Add `push_devices` and `notification_preferences` schema with RLS.
- Add app-facing RPCs for registering devices, unregistering devices, updating
  preferences, and reading current notification settings.
- Add a Settings Notifications card with permission, registration, transaction
  notification, and sensitive-detail controls.
- Add pgTAP and Flutter widget tests for registration, RLS isolation, token
  rotation, disabled state, and sensitive-detail toggles.

### External Work

- User creates or chooses the Firebase project.
- User registers the Android Firebase app for `com.olympus.spendlens`.
- User provides the Firebase Android app configuration and confirms whether it
  may be tracked in Git.

### Acceptance Criteria

- A signed-in Android user can enable push notifications from Settings.
- The app registers exactly one active device row per profile/installation.
- Token refresh updates the existing installation row.
- Users can disable transaction notifications or hide merchant/amount details.
- Non-members cannot register devices or update preferences for another
  household.
- Flutter contains no service-role keys or Firebase admin credentials.

## Milestone 19: Notification Outbox and Transaction Enqueue Contract

### Status

Planned. See [Push Notifications](PUSH_NOTIFICATIONS.md#m19---notification-outbox-and-transaction-enqueue-contract).

### Objective

Create durable notification queueing and enqueue one notification per successful
transaction processing batch.

### Tasks

- Add service-only `notification_outbox` and `notification_deliveries` tables.
- Add service-only RPCs to enqueue transaction notification batches, claim
  queued outbox rows, and mark outbox rows sent or failed.
- Store both detailed and private notification title/body variants.
- Generate notification data payloads with household id, notification id,
  transaction count, source type, and route `/transactions`.
- Update `gmail-sync` to accumulate only inserted transaction ids from
  `ingest_gmail_transaction`.
- Enqueue exactly one outbox row per completed Gmail sync/backfill job when at
  least one new transaction was inserted.
- Use `gmail-job:<ingestion_jobs.id>` idempotency for Gmail batches.
- Add a direct insert fallback trigger only for future `manual` and `api`
  source transactions; do not trigger for `workbook` or `gmail`.
- Add structured queue logs without exposing raw FCM tokens.
- Add database tests for service-only access, enqueue idempotency, empty lists,
  cross-household rejection, text generation, direct insert fallback, Gmail
  batching, and duplicate reprocessing.

### External Work

- None.

### Acceptance Criteria

- A Gmail job with newly inserted transactions creates one queued outbox row.
- Reprocessing the same Gmail source fingerprints creates no additional
  notification work.
- Workbook imports do not enqueue notifications.
- Future direct manual/API transaction inserts enqueue one single-transaction
  notification.
- Normal app roles cannot read or mutate outbox/delivery tables.

## Milestone 20: FCM Dispatcher Edge Function

### Status

Planned. See [Push Notifications](PUSH_NOTIFICATIONS.md#m20---fcm-dispatcher-edge-function).

### Objective

Deliver queued transaction notifications through FCM HTTP v1 from a service-key
protected Supabase Edge Function.

### Tasks

- Ask the user for FCM service account JSON only as a local ignored secret file
  or hosted Supabase secret; do not ask them to paste private keys into chat.
- Add `send-push-notifications` Edge Function protected by the existing
  Supabase secret-key request check.
- Add shared FCM helper code that:
  - Reads `FCM_SERVICE_ACCOUNT_JSON`.
  - Mints OAuth access tokens for
    `https://www.googleapis.com/auth/firebase.messaging`.
  - Sends FCM HTTP v1 messages to the selected Firebase project.
  - Never logs full FCM tokens or private keys.
- Fan out queued outbox rows to active Android devices for active household
  members with transaction push enabled.
- Choose detailed or private content per user's
  `include_sensitive_details` preference.
- Record one delivery row per outbox/device and mark sent, skipped, or failed.
- Deactivate devices on permanent token errors.
- Retry transient FCM/network failures with outbox backoff.
- Add local/staging/production secret examples using placeholder
  `FCM_SERVICE_ACCOUNT_JSON`.
- Add dispatcher tests with mocked FCM success, permanent token failure,
  transient retry, missing credentials, private-vs-detailed content, and no
  eligible devices.

### External Work

- User stores FCM service account JSON in Supabase Edge Function secrets or an
  ignored local env file as `FCM_SERVICE_ACCOUNT_JSON`.
- Hosted scheduler setup is optional until M21, but the function must support
  manual service-key invocation.

### Acceptance Criteria

- Service-key calls dispatch queued outbox rows to FCM in tested code paths.
- Successful sends create sent delivery rows and mark outbox sent.
- Invalid tokens deactivate only affected devices.
- Transient failures leave queued work retryable.
- Missing/malformed FCM credentials fail safely without losing notification
  intent.

## Milestone 21: End-to-End UX, Observability, and Runbooks

### Status

Planned. See [Push Notifications](PUSH_NOTIFICATIONS.md#m21---end-to-end-ux-observability-and-runbooks).

### Objective

Complete notification tap behavior, foreground refresh behavior, operational
visibility, and production runbooks.

### Tasks

- Handle `FirebaseMessaging.onMessage`, `onMessageOpenedApp`, and
  `getInitialMessage`.
- Route transaction notification taps to `/transactions`.
- Refresh transaction, dashboard, trend, available-month, and review providers
  for the active household where practical.
- Show a lightweight in-app notice for foreground transaction messages.
- Add Android notification channel setup if the final Firebase implementation
  requires it.
- Add service-only operational views or documented SQL queries for queued,
  failed, sent, stale, and invalid-token notification state.
- Update implementation, mobile, Supabase, external setup, and production
  readiness docs with Firebase/FCM setup, secrets, scheduler, and smoke tests.
- Add a hosted smoke checklist covering device registration, transaction batch
  processing, dispatcher run, notification receipt, notification tap, and
  private-details mode.
- Add Flutter tests for tap routing, provider refresh, and foreground notice
  behavior using fake message streams/controllers.

### External Work

- Hosted end-to-end push receipt requires an Android device or emulator with
  Google Play services, a Firebase Android app, and `FCM_SERVICE_ACCOUNT_JSON`
  configured in Supabase Edge Function secrets.

### Acceptance Criteria

- Notification taps open Transactions for signed-in users.
- Foreground messages refresh app data and show a non-blocking notice.
- Operators can inspect queued, sent, failed, stale, and invalid-token
  notification state.
- Production readiness docs include Firebase setup, FCM secret handling,
  dispatcher scheduling, and smoke testing.
- iOS, web push, exact transaction-detail deep links, quiet hours, and marketing
  notifications remain deferred.

## Cross-Milestone Consistency Rules

- Ask the user before proceeding on any undocumented decision. Codex may recommend a default, but must wait for confirmation.
- Keep all finance rows scoped to `household_id`.
- Use RLS for app-accessible tables.
- Do not store raw email bodies by default.
- Do not store FCM service account JSON or private keys in Flutter or tracked
  docs.
- Use `net_expense` for summaries and budgets.
- Exclude card bill payments from spend.
- Treat refunds as reducing net expense.
- Ensure imports and sync jobs are idempotent.
- Keep push delivery asynchronous so FCM failures do not block ingestion.
- Prefer deterministic rules before AI.
- Keep client code free of service credentials.
- Update these docs when architecture decisions change.

## Deferred Future Milestone: iOS App

This milestone is intentionally outside the current implementation plan. Do not start it unless the user explicitly resumes iOS work.

### Objective

Add an iOS app that reuses the existing Flutter codebase and Supabase backend.

### Tasks

- Confirm iOS bundle identifier.
- Install and configure Xcode only when iOS work resumes.
- Install CocoaPods only when iOS plugin builds require it.
- Add iOS platform scaffold and signing configuration.
- Add iOS OAuth client and redirect URLs.
- Verify Supabase Auth and Gmail connector deep-link behavior on iOS.
- Run iOS simulator tests and a physical-device smoke test if available.
- Prepare TestFlight distribution only when the user wants external testing.

### External Work

- User installs Xcode.
- User enrolls in Apple Developer Program if TestFlight/App Store distribution is needed.
- User configures iOS bundle identifier and OAuth client.

### Acceptance Criteria

- iOS build runs on simulator.
- Auth and connector redirects return to the app correctly.
- iOS client does not introduce privileged secrets or bypass RLS.

## Deferred Future Milestone: Web Interface

This milestone is intentionally outside the current implementation plan. Do not start it unless the user explicitly resumes web work.

### Objective

Add a web interface that reuses the existing Supabase backend, RLS policies, summary views, Edge Functions, and ingestion pipeline.

### Tasks

- Confirm whether the web interface should be Flutter web or a separate web stack.
- Confirm target hosting provider and production domain.
- Add web-specific OAuth redirect URLs and frontend configuration.
- Implement responsive layouts for dashboard, transactions, trends, merchant review, budgets, and piggy banks.
- Reuse existing data repositories and backend functions where possible.
- Add web-specific build, deployment, and smoke tests.

### External Work

- User chooses web stack and hosting provider.
- User configures web domain and hosting account.
- User configures web OAuth redirect URLs.

### Acceptance Criteria

- Web interface is deployed and usable.
- Web views match mobile financial semantics.
- Web client does not introduce any privileged secrets or bypass RLS.
