# SpendLens Milestones

Each milestone is intended to be executable in a separate thread. A new thread should read `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `INGESTION.md`, and the active milestone before making changes. Milestones with dedicated companion plans should also read the linked plan document before editing.

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

- Category rename/add/delete/merge behavior is handled by Milestones 22-25.
  Remaining future taxonomy-admin work includes reorder, moving subcategories
  between categories, category icons/colors, category audit timeline UI,
  cross-household templates, and bulk AI recategorization.

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
- Category taxonomy mutation is handled by Milestones 14 and 22-25, not by the
  transaction metadata correction RPC. Remaining future taxonomy-admin work
  includes reorder, moving subcategories between categories, category
  icons/colors, category audit timeline UI, cross-household templates, and bulk
  AI recategorization.
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

## Milestone 22: Category Manager Foundation and Usage Preview

### Status

Completed on 2026-06-11.

### Objective

Turn the Settings category card into a real management surface with grouped
taxonomy, usage summaries, recent transaction previews, and safe
non-destructive editing.

### Tasks

- Add category detail/preview UI from Settings with transaction counts, net
  spend, and recent associated transactions.
- Keep categories visually grouped with their subcategories.
- Add compact icon actions, including an edit/pencil action per category row.
- Add repository models and methods for category-management snapshots and usage
  previews.
- Add an app-facing `security invoker` RPC for renaming a category, renaming
  existing subcategories, and adding new subcategories under the same category.
- Preserve existing category and subcategory IDs for renames.
- Refresh category, dashboard, transactions, trends, and review providers after
  taxonomy edits.
- Add pgTAP and Flutter widget tests.

### External Work

- None.

### Acceptance Criteria

- Household writers can inspect category usage and recent transactions.
- Household writers can rename categories/subcategories and add subcategories.
- Renamed labels appear across Settings, transactions, dashboard, and reports
  through existing ID references.
- Viewers and non-members cannot mutate taxonomy.
- Delete and merge controls are not active yet.

### Deferred Scope

- Category deletion, subcategory deletion, category merge, reorder, moving
  subcategories between categories, icons/colors, and bulk AI recategorization.

## Milestone 23: Taxonomy Delete and Review Requeue

### Status

Completed on 2026-06-11.

### Objective

Allow category and subcategory deletion without deleting transactions by moving
affected rows back into the existing Review workflow.

### Tasks

- Add delete actions and confirmation dialogs to category detail.
- Show affected transaction counts, active mapping-rule counts, cap counts, and
  recent examples before confirmation.
- Add app-facing `security invoker` RPCs for deleting a subcategory and deleting
  a category.
- Subcategory deletion clears affected `subcategory_id` references, preserves
  category references, and opens review items for reassignment.
- Category deletion clears affected category/subcategory classification
  references and opens review items for recategorization.
- Deactivate future mapping rules that referenced deleted taxonomy.
- Clear merchant and review suggestion references that pointed at deleted
  taxonomy.
- Remove monthly caps for deleted categories.
- Add pgTAP and Flutter widget tests.

### External Work

- None.

### Acceptance Criteria

- Household writers can delete unused and used subcategories.
- Household writers can delete used categories without deleting transactions.
- Affected transactions appear in Review for manual reclassification.
- Future mapping rules no longer point at deleted taxonomy.
- Viewers and non-members cannot delete taxonomy.

### Deferred Scope

- Category merge, reorder, category archival instead of hard delete, and bulk AI
  recategorization.

## Milestone 24: Category Merge with Explicit Subcategory Mapping

### Status

Completed on 2026-06-11.

### Objective

Merge categories into a surviving category while explicitly mapping every source
subcategory to a destination subcategory.

### Tasks

- Add a merge flow to category management.
- Let the user choose one destination category and one or more source
  categories.
- Require every source subcategory to map to an existing destination
  subcategory or a newly named destination subcategory.
- Allow editing the surviving category name before saving.
- Show affected transaction counts, net spend, caps, mapping rules, and recent
  examples before merge.
- Add one atomic app-facing `security invoker` merge RPC.
- Repoint transactions, merchants, mapping rules, review suggestions, and caps
  to surviving taxonomy.
- Sum same-month source category caps into destination category caps.
- Delete merged-away taxonomy rows after references are moved.
- Add pgTAP and Flutter widget tests.

### External Work

- None.

### Acceptance Criteria

- Household writers can merge categories only after all source subcategories are
  mapped.
- Transactions, merchants, mapping rules, review suggestions, and caps point to
  the surviving category/subcategory IDs after merge.
- Category caps for matching months are summed.
- Successful merges do not create review items.
- Viewers and non-members cannot merge taxonomy.

### Deferred Scope

- Undo history, category archival, reorder, icons/colors, and AI-assisted merge
  suggestions.

## Milestone 25: Category Management Regression, Docs, and Cleanup

### Status

Completed on 2026-06-11.

### Objective

Harden the full category management workflow, document final behavior, and
verify cross-feature consistency after rename, add, delete, and merge.

### Tasks

- Review and polish category management empty, loading, error, confirmation, and
  success states.
- Add "View transactions" navigation from category detail to Transactions with
  the category filter applied.
- Verify category management consistency across dashboard, monthly caps,
  transactions, trends, merchant review, metadata editor selectors, workbook
  import validation, and Gmail future mapping behavior.
- Update durable docs with final category management behavior.
- Remove stale TODOs, duplicated helpers, and dead models from M22-M24.
- Run full local Supabase, importer, Flutter analyze/test/build verification.

### External Work

- None.

### Acceptance Criteria

- Category management has usable mobile states for loading, empty, error,
  confirmation, saving, and success.
- Core finance and review surfaces behave correctly after rename, add, delete,
  and merge.
- No active mapping rule points at deleted taxonomy after regression tests.
- Final docs and handoff reflect the implemented behavior and any deferred
  category work.

### Deferred Scope

- Reorder, cross-household taxonomy templates, category icons/colors,
  category-level audit timeline UI, and bulk AI recategorization.

## Milestone 26: Labels Data Model and Repository Foundation

### Status

Completed on 2026-06-12.

### Objective

Add the database, RLS, RPC, repository, and test foundation for
household-shared transaction labels.

### Tasks

- Add household-scoped `labels` and `transaction_labels` tables.
- Add constraints, indexes, RLS policies, and authenticated grants.
- Add app-facing `security invoker` RPCs for replacing one transaction's labels,
  renaming a label, and deleting a label with detach semantics.
- Add a household-scoped label usage read path for Settings.
- Extend Flutter repository models with label options, manager snapshots,
  transaction label lists, and `TransactionQuery.labelId`.
- Update transaction fetching so paged transactions include label lists without
  duplicating rows.
- Add pgTAP tests for label create/reuse, assignment replacement, rename,
  delete/detach, RLS isolation, viewer rejection, non-member rejection, and
  cross-household rejection.

### External Work

- None.

### Acceptance Criteria

- Household writers can create/reuse labels and replace labels for exactly one
  selected transaction through an RLS-safe RPC.
- Household writers can rename and delete labels; deletion detaches assignments
  and preserves all transactions.
- Household members can read household labels; viewers and non-members cannot
  mutate labels or assignments.
- Flutter repository contracts can fetch transactions with labels and perform
  label mutations.

### Deferred Scope

- Transaction label UI, Settings label manager UI, bulk labeling, label colors,
  label icons, AI label suggestions, label reports, and automatic workbook/Gmail
  labeling.

## Milestone 27: Transaction Labeling UX

### Status

Completed on 2026-06-12. See
[Transaction Labels](TRANSACTION_LABELS.md#m27---transaction-labeling-ux).

### Objective

Let users see, create, attach, remove, and filter labels from transaction
surfaces one transaction at a time.

### Tasks

- Show compact label chips in transaction list rows and full label context in
  transaction detail.
- Add a transaction label editor from transaction detail.
- Support existing-label selection, inline new-label creation, removal, disabled
  save state, and user-visible save errors.
- Save through the repository method backed by `set_transaction_labels`.
- Add a single-label Transactions filter backed by `TransactionQuery.labelId`
  and route query param `labelId`.
- Refresh transaction and label providers after label saves.
- Add Flutter widget tests for display, edit, create, remove, route parsing,
  filter application, overflow display, and clear-filter behavior.

### External Work

- None.

### Acceptance Criteria

- A household writer can attach existing labels to a selected transaction.
- A household writer can create a new label inline and attach it to the selected
  transaction.
- A household writer can remove labels from the selected transaction.
- Labels appear in transaction list/detail after save.
- Filtering Transactions by one label returns only transactions attached to that
  label.
- Label edits do not update other transactions from the same merchant or create
  merchant mapping rules.

### Deferred Scope

- Bulk multi-select labeling, Settings label management, label reports,
  dashboard summaries by label, and AI label suggestions.

## Milestone 28: Settings Label Manager and Regression

### Status

Completed on 2026-06-12. See
[Transaction Labels](TRANSACTION_LABELS.md#m28---settings-label-manager-and-regression).

### Objective

Add household label vocabulary management in Settings and harden the full label
workflow.

### Tasks

- Add a Settings Labels manager with create, rename, delete, and usage counts.
- Show attached transaction count before deleting a used label.
- Delete used labels by detaching them from all transactions, without deleting or
  reclassifying transactions.
- Refresh Settings and transaction providers after create, rename, and delete.
- Cover active-filter behavior when a selected label is deleted.
- Verify long labels and narrow viewports do not overflow.
- Update durable docs and handoff with final label behavior.
- Add focused Flutter regression tests and run the local Supabase verification
  path.

### External Work

- None.

### Acceptance Criteria

- Settings exposes household label management with create, rename, delete, and
  usage counts.
- Used-label deletion detaches the label from all transactions after
  confirmation and leaves transaction classification untouched.
- Transaction label display, editing, and filtering still work after rename and
  delete.
- Viewers and non-members cannot mutate labels.
- Final docs and handoff reflect implemented behavior and deferred label work.

### Deferred Scope

- Label colors/icons, label sharing outside the household, per-user private
  labels, bulk labeling, AI label suggestions, label reports, and automatic
  workbook/Gmail labeling.

## Milestone 29: Monthly Cap Data Model and Repository Foundation

### Status

Completed on 2026-06-12. See
[Monthly Caps](MONTHLY_CAPS.md#m29---monthly-cap-data-model-and-repository-foundation).

### Objective

Replace the category-only cap contract with required-name monthly caps that can
target categories and labels.

### Tasks

- Add household-scoped `monthly_caps`, `monthly_cap_categories`, and
  `monthly_cap_labels` tables.
- Backfill existing `category_caps` into named monthly caps with one category
  target each.
- Add RLS policies, authenticated grants, and app-facing `security invoker`
  RPCs for cap upsert and delete.
- Add `v_monthly_cap_progress` with OR matching across category and label
  targets, one-count-per-transaction semantics within each cap, and overlap
  support across separate caps.
- Update category delete, category merge, and label delete behavior for cap
  targets.
- Update Flutter repository contracts and fake repository support for the new
  cap models.
- Add focused pgTAP and Flutter repository tests.

### External Work

- None.

### Acceptance Criteria

- Existing category caps migrate into named monthly caps.
- Household writers can create, update, and delete caps through RLS-safe RPCs.
- Cap progress works for category-only, label-only, and mixed target caps.
- Transactions are counted once within one cap and can count in overlapping
  caps.
- Viewers and non-members cannot mutate caps.

### Deferred Scope

- Dashboard multi-target cap UI, cap-row drilldown, cap notifications,
  subcategory caps, and non-category/label targets.

## Milestone 30: Dashboard Multi-Target Cap UX

### Status

Completed on 2026-06-12. See
[Monthly Caps](MONTHLY_CAPS.md#m30---dashboard-multi-target-cap-ux).

### Objective

Expose named category/label caps from the Dashboard.

### Tasks

- Replace category-only cap creation chips with an `Add cap` action.
- Add a cap form with required name, INR monthly amount, multi-select
  categories, and multi-select labels.
- Validate nonblank name, valid nonnegative amount, and at least one target.
- Show cap progress rows with name, amount, spent, remaining/over amount,
  matched transaction count, and category/label target chips.
- Support edit and delete flows for existing caps.
- Refresh Dashboard providers after cap mutations.
- Add focused Dashboard widget tests.

### External Work

- None.

### Acceptance Criteria

- Users can create category-only, label-only, and mixed caps from Dashboard.
- Users can edit cap name, amount, and targets.
- Users can delete caps without changing transactions, categories, labels,
  merchant rules, or review rows.
- Long names and target chips behave correctly on narrow screens.

### Deferred Scope

- Cap-row transaction drilldown, cap reports, cap notifications, and automatic
  label assignment.

## Milestone 31: Monthly Caps Regression, Docs, and Cleanup

### Status

Completed on 2026-06-12. See
[Monthly Caps](MONTHLY_CAPS.md#m31---monthly-caps-regression-docs-and-cleanup).

### Objective

Harden multi-target caps, remove stale category-only assumptions, and document
the final behavior.

### Tasks

- Run cross-feature regression for cap progress after category delete, category
  merge, label delete, label rename, and transaction label assignment changes.
- Remove or retire active `category_caps`, `v_budget_progress`,
  `BudgetProgress`, and `saveCategoryCap` references after the new model is
  fully wired.
- Update durable docs and handoff with final monthly cap behavior.
- Add pgTAP and Flutter regression coverage for target cleanup, dedupe, no
  double-counting, and allowed overlap.
- Run full local Supabase, Flutter analyze/test, and debug Android build
  verification.

### External Work

- None.

### Acceptance Criteria

- No active app code reads or writes category-only cap contracts.
- Multi-target caps behave correctly across category and label lifecycle
  changes.
- Final docs reflect required names, category/label targets, OR matching,
  one-count-per-cap semantics, and allowed overlap.
- Milestones 18-21 remain deferred unless explicitly resumed.

### Deferred Scope

- Subcategory caps, merchant/source-account targets, cap notifications,
  rollover budgets, shared templates, AI cap suggestions, and cap drilldown.

## Milestone 32: Recurring Cap Series Foundation

### Status

Completed on 2026-06-13. See
[Monthly Caps](MONTHLY_CAPS.md#m32---recurring-cap-series-foundation).

### Objective

Introduce stable recurring cap identity and current/future cap versioning before
adding carry-forward calculations or Dashboard carry-forward copy.

### Tasks

- Add a Supabase CLI-created migration for recurring cap series,
  month-effective cap versions, and versioned category/label targets.
- Backfill existing named monthly caps into recurring series with one initial
  version and carry-forward disabled.
- Update app-facing cap upsert/delete behavior so creates make recurring cap
  series, edits create a selected-month-forward version, and deletes stop a
  series from the selected month forward.
- Add an exact-month cap progress read path that can include recurring caps in
  months without transactions.
- Update Flutter repository models, fake repository support, and month
  availability to carry stable series/version identity while preserving current
  Dashboard behavior with carry-forward off.
- Preserve category/label lifecycle cleanup for versioned targets.

### External Work

- None.

### Acceptance Criteria

- Existing caps migrate into recurring series without losing target data.
- Creating a cap from Dashboard creates a recurring cap series.
- Edits and deletes from a selected month affect that month and future months
  only.
- Prior months remain readable after edit/delete.
- Recurring cap months can appear in Dashboard month selection before
  transactions exist.
- Existing multi-target matching, overlap, RLS, and lifecycle cleanup behavior
  still passes with carry-forward disabled.

### Deferred Scope

- Carry-forward calculations, carry-forward Dashboard copy, cap drilldown,
  notifications, AI suggestions, and hosted rollout.

## Milestone 33: Carry-Forward Progress Semantics

### Status

Completed on 2026-06-13. See
[Monthly Caps](MONTHLY_CAPS.md#m33---carry-forward-progress-semantics).

### Objective

Add positive and negative carry-forward calculations to recurring cap progress.

### Tasks

- Extend cap progress responses with base cap amount, carry-forward enabled
  state, carry-forward amount, effective cap amount, remaining amount,
  percent used, and over-budget state.
- Calculate carry-forward in Postgres from the same recurring cap series:
  previous month's effective cap minus previous month's spend.
- Support positive carry-forward, negative carry-forward, chained
  carry-forward, first active month behavior, disabled carry-forward behavior,
  amount edits, target edits, and stopped caps.
- Keep matching semantics unchanged: `net_expense`, category OR label target,
  one-count-per-cap, and allowed overlap.
- Update Dart model parsing and fake repository behavior for the new progress
  fields.
- Add focused pgTAP and Flutter model/repository tests.

### External Work

- None.

### Acceptance Criteria

- Positive prior-month remainder increases the next month's effective cap.
- Negative prior-month remainder reduces the next month's effective cap.
- Carry-forward chains across active months and stops when disabled or inactive.
- Effective cap, remaining amount, percent used, and over-budget state are
  derived from the carry-forward-aware cap.
- Flutter models expose the values required by Dashboard UX.

### Deferred Scope

- Dashboard carry-forward toggle/copy, cap drilldown, notifications, AI
  suggestions, and hosted rollout.

## Milestone 34: Dashboard Carry-Forward UX

### Status

Completed on 2026-06-13. See
[Monthly Caps](MONTHLY_CAPS.md#m34---dashboard-carry-forward-ux).

### Objective

Expose carry-forward creation/editing and effective cap explanation in the
Dashboard.

### Tasks

- Add a `Carry forward remainder` toggle to the Dashboard cap create/edit sheet,
  defaulting off for new caps.
- Save the toggle through the updated monthly cap upsert request.
- Update edit/delete copy to make selected-month-forward recurring behavior
  clear.
- Render base monthly cap, carried amount, effective available cap, spent,
  remaining/over, percent, matched count, and target chips.
- Show positive carry-forward as extra available cap and negative carry-forward
  as already-exhausted cap space.
- Keep existing add/edit/delete target workflows, provider refresh, and top
  category/merchant drilldowns intact.
- Add narrow-viewport and focused Dashboard widget coverage.

### External Work

- None.

### Acceptance Criteria

- Users can enable or disable carry-forward while creating or editing a cap.
- Positive and negative carry-forward states are understandable in cap rows.
- Over-budget states use effective cap, not base cap alone.
- Recurring cap months remain selectable before transactions exist.
- Existing Dashboard cap workflows and drilldowns still work.

### Deferred Scope

- Cap drilldown, cap reports, push notifications, AI suggestions, shared
  templates, and hosted rollout.

## Milestone 35: Recurring Caps Regression, Docs, and Cleanup

### Status

Completed on 2026-06-13. See
[Monthly Caps](MONTHLY_CAPS.md#m35---recurring-caps-regression-docs-and-cleanup).

### Objective

Harden recurring cap and carry-forward behavior, then document the final state.

### Tasks

- Run cross-feature regression for recurring creation, current/future edit,
  current/future delete, positive carry-forward, negative carry-forward,
  chained carry-forward, disabled carry-forward, category lifecycle changes,
  label lifecycle changes, no double-counting, overlap, and RLS.
- Remove or update stale one-month-only cap assumptions in Dashboard copy,
  repository models, tests, and docs.
- Update durable docs and handoff with final recurring/carry-forward behavior.
- Add or tighten pgTAP and Flutter regression coverage for the final contract.
- Run full local Supabase, Flutter analyze/test, and debug Android build
  verification.

### External Work

- None.

### Acceptance Criteria

- Recurring cap and carry-forward behavior is covered by database and Flutter
  regression tests.
- No active Dashboard copy assumes caps are one-month-only records.
- Final docs reflect recurring cap identity, selected-month-forward edits and
  deletes, optional carry-forward, positive/negative carry-forward, effective
  caps, category/label OR matching, one-count-per-cap semantics, and allowed
  overlap.
- Milestones 18-21 remain deferred unless explicitly resumed.

### Deferred Scope

- Subcategory caps, merchant/source-account targets, cap notifications,
  cap drilldown, shared templates, annual budget planning, AI cap suggestions,
  and hosted rollout.

## Milestone 36: UI Redesign Planning and Reference Readiness

### Status

Completed on 2026-06-13. See
[UI Redesign](UI_REDESIGN.md#m36---ui-redesign-planning-and-reference-readiness).

### Objective

Create the durable UI redesign implementation plan and make the Stitch
references discoverable for future fresh-context execution.

### Tasks

- Verify the cleaned branch has no unresolved conflict markers.
- Confirm the Stitch reference bundle exists under
  `docs/design-references/stitch/themed-dashboard-ui-redesign`.
- Add `docs/implementation-plan/UI_REDESIGN.md` as the companion plan for the
  UI redesign sequence.
- Update README, milestones, and handoff so future sessions start with M37.
- Do not implement Flutter UI changes in this milestone.

### External Work

- None.

### Acceptance Criteria

- The UI redesign plan is self-contained and references DESIGN.md plus the
  stored Stitch mocks.
- Milestones 37-51 are planned for fresh-thread implementation.
- The next recommended milestone is M37.

### Deferred Scope

- Flutter UI implementation begins in M37.

## Milestone 37: UI Design Tokens, Themes, and Theme Preference

### Status

Completed on 2026-06-13. See
[UI Redesign](UI_REDESIGN.md#m37---design-tokens-themes-and-theme-preference).

### Objective

Replace the current one-off light theme with a DESIGN.md-based light/dark theme
system and local theme-mode persistence.

### Tasks

- Add token-driven light and dark themes.
- Add system/light/dark theme mode state with system as default.
- Persist the selected theme mode locally on device.
- Wire `MaterialApp.router` to `theme`, `darkTheme`, and `themeMode`.
- Add focused theme tests.

### External Work

- None.

### Acceptance Criteria

- The app defaults to system theme mode.
- Light and dark themes are available globally.
- Theme mode changes persist locally and do not require Supabase.

### Deferred Scope

- Individual screen redesign starts in later milestones.

## Milestone 38: Shared Responsive UI Primitives

### Status

Completed on 2026-06-13. See
[UI Redesign](UI_REDESIGN.md#m38---shared-responsive-ui-primitives).

### Objective

Create shared responsive widgets and primitives used by all redesigned screens.

### Tasks

- Expand or replace `AppPage`, `MetricCard`, `EmptyState`, and related shared
  widgets.
- Add responsive page, card, chip, button, section, amount, modal, loading, and
  error primitives.
- Encode mobile/tablet/desktop breakpoints from DESIGN.md.
- Use constraint-based responsive layout rules.
- Add focused primitive tests.

### External Work

- None.

### Acceptance Criteria

- Shared widgets match the DESIGN.md visual language.
- Shared widgets render in light and dark themes.
- Existing feature tests still pass.

### Deferred Scope

- App navigation and screen-specific redesign are later milestones.

## Milestone 39: App Shell, Navigation IA, and Routes

### Status

Completed on 2026-06-13. See
[UI Redesign](UI_REDESIGN.md#m39---app-shell-navigation-ia-and-routes).

### Objective

Move the app to the redesigned information architecture before screen-specific
work.

### Tasks

- Add the primary Activity destination.
- Replace the primary navigation with Dashboard, Activity, Review, and Vaults.
- Remove Settings from primary navigation.
- Add a global shell settings action.
- Remove active `/transactions` and `/trends` routes.
- Update internal navigation and tests to use Activity.

### External Work

- None.

### Acceptance Criteria

- Bottom navigation has exactly four primary items.
- Settings is reachable but not a bottom-tab destination.
- Old Transactions and Trends routes are removed from the app.

### Deferred Scope

- Activity list/charts content migration is split across M41-M42.

### Completion Notes

- Added `/activity` as the primary Activity destination and removed active
  `/transactions` and `/trends` app routes.
- Primary navigation is Dashboard, Activity, Review, and Vaults; Settings opens
  from a global shell settings action and remains an authenticated route.
- Dashboard and Settings drilldowns now target Activity while preserving
  existing query semantics.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_route.dart lib/src/features/activity/activity_screen.dart lib/src/app/router.dart lib/src/app/app_shell.dart lib/src/features/dashboard/dashboard_screen.dart lib/src/features/settings/settings_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart test/widget_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The visible Vaults destination can continue to use the existing
    `/piggy-banks` route until later Vaults-specific work.
  - Existing transaction-list implementation remains the temporary Activity list
    implementation; full list/charts migration remains deferred to M41-M42.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 40: Dashboard Redesign

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m40---dashboard-screen).

### Objective

Rebuild Dashboard using the Stitch dashboard hierarchy while preserving finance
behavior.

### Tasks

- Restyle Dashboard heading, month selector, spending cards, review card,
  monthly caps, and top category/merchant sections.
- Preserve recurring monthly-cap add/edit/delete, carry-forward, and drilldown
  behavior.
- Route category and merchant drilldowns to Activity list mode.
- Add or update Dashboard widget coverage for the redesigned layout.

### External Work

- None.

### Acceptance Criteria

- Dashboard follows the Stitch visual hierarchy.
- Existing cap workflows still pass.
- Dashboard has no narrow-viewport overflow.

### Deferred Scope

- Cap form/dialog polish is handled in M50 unless required for Dashboard tests.

### Completion Notes

- Rebuilt Dashboard around the Stitch hierarchy with the month pill, Spending
  net/month-change cards, Review queue card, compact Monthly caps rows, Top
  categories cards, and Top merchants cards.
- Preserved selected month, net spend, month-over-month values, review queue
  count, recurring cap add/edit/delete, carry-forward display, and Activity
  drilldowns.
- Added 390px Dashboard hierarchy widget coverage.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The existing M39 shell settings affordance is the Dashboard settings
    affordance for M40.
  - Cap form/modal polish remains deferred to M50.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/dashboard-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/dashboard-unified-navigation.html`

## Milestone 41: Activity List Mode

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m41---activity-list-mode).

### Objective

Move transaction list behavior into Activity's List mode.

### Tasks

- Add Activity List mode with search, filters, pagination, transaction cards,
  labels, and metadata entry points.
- Preserve transaction query semantics and filter behavior.
- Update transaction tests to use `/activity`.
- Remove remaining app navigation to `/transactions`.

### External Work

- None.

### Acceptance Criteria

- Activity List covers current Transactions behavior.
- Existing transaction filter, label, and metadata tests pass.
- Transaction cards are responsive and dark-theme safe.

### Deferred Scope

- Activity Charts mode is M42.

### Completion Notes

- Added Activity's List/Charts segmented control with List as the default and
  kept Charts as a placeholder for Milestone 42 only.
- Moved transaction search/filter/pagination behavior into Activity List while
  preserving `/activity` query semantics for Dashboard and Settings drilldowns.
- Restyled filters as pill-like responsive controls and transaction rows as
  large rounded cards with icon chips, merchant/group names, metadata, amounts,
  label chips/overflow, and detail tap targets.
- Preserved transaction label edit and metadata edit entry points through the
  detail sheet.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/shared/widgets/period_filter_dropdown.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Activity Charts remains a placeholder in M41 because chart/report migration
    is Milestone 42.
  - Transaction detail/editor visual redesign remains deferred to M43-M44.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/activity-scandi-fintech-refinement.html`

## Milestone 42: Activity Charts Mode

### Status

Completed on 2026-06-14. See [UI Redesign](UI_REDESIGN.md#m42---activity-charts-mode).

### Objective

Move Trends behavior into Activity's Charts mode.

### Tasks

- Add Activity Charts mode with gross/refunds/net cards, monthly chart, monthly
  table, and category trend card.
- Preserve trend filtering and CSV copy behavior where still visible.
- Update trend tests to use Activity Charts.
- Remove remaining app navigation to `/trends`.

### External Work

- None.

### Acceptance Criteria

- Activity Charts covers current Trends behavior.
- Existing trend report tests pass.
- Charts and tables are readable in light and dark modes.

### Deferred Scope

- New analytics beyond current Trends behavior.

### Completion Notes

- Moved existing Trends report behavior into Activity's Charts mode.
- Preserved trend report model/provider contracts, category/source
  filtering, period filtering, and filtered transaction CSV copy.
- Rendered the M42 Stitch hierarchy with gross/refunds/net cards, Monthly Net
  Spend chart, Gross/Refunds/Net monthly table, and Category Trend card.
- Kept chart and table content horizontally scrollable where needed on narrow
  Android widths.
- Updated trend tests to open Activity Charts mode.
- Verified no app/test code still navigates to `/trends`.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/features/trends/trends_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The existing Trend report model/provider contracts remain the correct data
    source for Activity Charts.
  - The standalone `/trends` app route had already been removed by M39.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/activity-unified-navigation.html`

## Milestone 43: Transaction Details Redesign

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m43---transaction-details-surface).

### Objective

Restyle transaction details as the focused Stitch detail surface.

### Tasks

- Rebuild the detail surface with centered merchant/date/amount/status and
  divider rows.
- Preserve metadata and label editor entry points.
- Constrain sheet/modal width across mobile and large layouts.

### External Work

- None.

### Acceptance Criteria

- Details open from Activity List.
- Metadata and label editor entry tests pass.
- Detail layout has no narrow-viewport overflow.

### Deferred Scope

- Metadata editor restyle is M44.

### Completion Notes

- Rebuilt transaction details as the focused Stitch detail surface using the
  M38 shared modal/card primitive with close affordance, centered
  merchant/date/large amount, transaction type/status pill, divider rows, and
  primary Edit action.
- Included detail rows for statement, gross spend, refunds, net expense, source
  amount, category, subcategory, confidence, and applicable cardholder, notes,
  and labels.
- Preserved metadata editing and label editing entry behavior without restyling
  the Transaction Metadata Editor.
- Added focused Activity List narrow-viewport coverage for the detail surface.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/transactions/transactions_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - The Activity List transaction card remains the entry point for details.
  - Metadata editor restyle remains deferred to M44.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-details-refined-shapes.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/transactions-details-refined-shapes.html`

## Milestone 44: Transaction Metadata Editor Redesign

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m44---transaction-metadata-editor).

### Objective

Restyle metadata editing while preserving transaction and review correction
behavior.

### Tasks

- Rebuild the metadata editor as the Stitch modal form.
- Preserve merchant group, category, subcategory, confidence, notes, category
  creation, AI Suggest, and save behavior.
- Keep Review and Activity callers working.

### External Work

- None.

### Acceptance Criteria

- Metadata editor tests pass from Activity and Review.
- Suggest failure keeps form values.
- The form is keyboard-safe and theme-safe.

### Deferred Scope

- New metadata fields or AI behavior.

### Completion Notes

- Rebuilt the metadata editor as a constrained modal card with the Stitch form
  hierarchy: `Edit metadata` title, outlined merchant group field,
  category/subcategory selectors, Create category affordance, confidence
  selector, notes field, explanatory copy, and Suggest/Cancel/Save actions.
- Preserved transaction and Review correction behavior, category creation, AI
  Suggest success/failure handling, save request shape, and provider
  invalidation from existing callers.
- Added focused regression coverage for Activity and Review metadata editor
  access, Suggest failure retaining manual values, and a 390px dark-theme
  narrow viewport render check.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/transaction_metadata/transaction_metadata_editor.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Activity and Review continue sharing one metadata editor implementation.
  - The existing create-category dialog is not restyled until a later
    dialog/form polish milestone.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-edit-metadata.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/transactions-edit-metadata.html`

## Milestone 45: Review Redesign

### Status

Completed on 2026-06-14. See [UI Redesign](UI_REDESIGN.md#m45---review-screen).

### Objective

Rebuild Review around the Stitch queue-card design.

### Tasks

- Restyle Review title, metric cards, queue cards, classification chips,
  confidence chips, Resolve action, and caught-up state.
- Preserve Gmail parse failure rendering and correction flow.
- Preserve metadata editor integration and provider invalidation.

### External Work

- None.

### Acceptance Criteria

- Review queue and correction tests pass.
- Empty, loading, and error states use the redesigned system.
- Review cards fit mobile width.

### Deferred Scope

- New review workflow behavior.

### Completion Notes

- Rebuilt Review around the Stitch queue-card hierarchy with redesigned title
  copy, Open Reviews and Correction Data metrics, warning-rail queue cards,
  merchant/source/date line, amount treatment, needs-attention status,
  classification chips, confidence chip, Resolve action, and caught-up state.
- Preserved Gmail parse failure diagnostics, Review loading/error states,
  correction flow through the shared metadata editor, Review save behavior, and
  provider invalidation after save.
- Switched the queue to lazy sliver rendering so Review cards fit 390px mobile
  width and wider layouts without nested unbounded scrollables.
- Added focused widget coverage for Review loading/error states, Gmail parse
  failures, correction behavior, and 390px queue-card rendering.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/merchant_review/merchant_review_screen.dart lib/src/shared/widgets/chips.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Review items do not expose a source-account label, so the redesigned
    merchant/source/date line uses existing source amount and transaction date
    fields without changing repository contracts.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/review-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/review-unified-navigation.html`

## Milestone 46: Vaults Redesign

### Status

Completed on 2026-06-14. See [UI Redesign](UI_REDESIGN.md#m46---vaults-screen).

### Objective

Restyle Piggy Banks as the visible Vaults destination.

### Tasks

- Change visible destination and screen copy to Vaults.
- Preserve existing piggy-bank data/repository naming unless a small UI rename
  is necessary.
- Restyle summary cards, selected vault card, deposit/withdraw actions,
  progress cards, and empty entry state.
- Update tests for visible copy changes.

### External Work

- None.

### Acceptance Criteria

- Bottom nav label is Vaults.
- Existing piggy-bank behavior tests pass.
- Vault detail and actions are responsive.

### Deferred Scope

- Database or RPC renaming from piggy-bank wording to vault wording.

### Completion Notes

- Restyled the existing Piggy Banks route as the visible Vaults destination
  with a Vaults display title, New Vault action, Active ledgers and Total
  balance summary cards, selected-vault hero card, compact Deposit, Withdraw,
  and Adjust actions, Current balance, Target progress, Remaining, and
  redesigned empty/timeline entry states.
- Preserved create/edit vault behavior, selected ledger behavior, deposit,
  withdrawal, adjustment entries, no-overdraft validation, and ledger-derived
  balance/progress reads while keeping piggy-bank database/RPC/repository/model
  naming intact.
- Added adaptive stacked mobile cards and responsive constrained grids for
  wider layouts, plus 390px focused coverage for the full
  create/deposit/withdraw/progress flow.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/piggy_banks/piggy_banks_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - `/piggy-banks` and `PiggyBank*` names remain implementation details for
    M46; visible navigation and screen copy say Vaults.
  - Adjustment remains available as a compact third action beside Deposit and
    Withdraw to preserve existing ledger behavior.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/vaults-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/vaults-scandi-fintech-refinement.html`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/metadata/vaults-scandi-fintech-refinement.screen.json`

## Milestone 47: Settings Focused Screen and Theme Selector

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m47---settings-focused-screen-and-theme-selector).

### Objective

Rebuild Settings as a focused non-tab page and expose the theme selector.

### Tasks

- Restyle Settings with a back affordance, focused cards, and DESIGN.md
  surfaces.
- Add a theme selector for System default, Light, and Dark.
- Preserve sign-out, category, label, Gmail connector, AI, and environment
  behavior.
- Route Settings drilldowns to Activity.

### External Work

- None.

### Acceptance Criteria

- Settings is not in primary navigation.
- Theme selector updates the app immediately and persists locally.
- Existing Settings tests pass after route/copy updates.

### Deferred Scope

- Backend-synced theme preference.

### Completion Notes

- Rebuilt Settings as a focused no-primary-navigation route with Back,
  Account & Runtime, Theme, Categories, Labels, Gmail Importer, AI Core, and
  System Environment sections using the M38 primitives and DESIGN.md surfaces.
- Added System default, Light, and Dark theme selection through the existing
  M37 local theme-mode controller/persistence path.
- Preserved Settings sign-out, category, label, Gmail, AI budget/status,
  runtime/config display, and Activity drilldown behavior.
- No Supabase/backend/schema/RPC/Edge Function/hosted work, push-notification
  work, M48, or later-milestone work was started.
- Verification:
  - `cd apps/mobile && dart format lib/src/app/app_shell.dart lib/src/features/settings/settings_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Settings should hide primary shell navigation while active to match the
    focused no-nav Stitch reference.
  - Theme mode remains local device state and is not synced to Supabase.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/settings-focused-view-no-nav.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/html/settings-focused-view-no-nav.html`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/metadata/settings-focused-view-no-nav.screen.json`

## Milestone 48: Sign-In and Household Gate Redesign

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m48---sign-in-and-household-gate-states).

### Objective

Bring sign-in, household loading, and household error states into the new visual
system.

### Tasks

- Restyle sign-in as a DESIGN.md auth card.
- Restyle household loading and error states.
- Preserve auth, route guard, retry, and sign-out behavior.

### External Work

- None.

### Acceptance Criteria

- Auth smoke tests pass.
- Entry and gate states render correctly in light, dark, and system modes.

### Deferred Scope

- Auth provider or OAuth behavior changes.

### Completion Notes

- Restyled the sign-in entry as a responsive DESIGN.md auth surface on the
  sage canvas with a rounded auth card, branded wallet mark, environment badge,
  preserved Supabase readiness notices, and preserved Google sign-in action.
- Restyled household loading and household error gates as width-constrained
  redesigned entry states using M38 primitives, with retry and sign-out actions
  still wired to the existing providers.
- Added focused auth/gate widget coverage for light, dark, and system theme
  rendering plus sign-in, retry, and sign-out behavior.
- No auth repository/OAuth behavior changes, Supabase/backend/schema/RPC/Edge
  Function/hosted work, push-notification work, M49, or later-milestone work was
  started.
- Verification:
  - `cd apps/mobile && dart format lib/src/app/router.dart lib/src/features/auth/sign_in_screen.dart lib/src/shared/widgets/app_gate_scaffold.dart lib/src/shared/widgets/app_primitives.dart test/widget_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/widget_test.dart`
  - `cd apps/mobile && flutter test integration_test/app_test.dart` (blocked:
    no supported Android device connected; macOS/web are not generated for this
    project)
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - M48 has no dedicated Stitch auth/gate reference, so the implementation uses
    DESIGN.md plus existing M38 primitives as the visual authority.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 49: Ask / AI Redesign

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m49---ask--ai-screen).

### Objective

Redesign the non-primary Ask route consistently with the new UI system.

### Tasks

- Restyle Ask input, status, loading, error, and result states.
- Preserve backend-mediated expense Q&A and AI budget semantics.
- Keep Ask outside the four primary tabs.

### External Work

- None.

### Acceptance Criteria

- Existing AI tests pass.
- Ask is responsive and theme-safe.

### Deferred Scope

- New AI capabilities or Edge Function changes.

### Completion Notes

- Restyled the non-primary Ask route using the redesigned app primitives:
  prompt composer, primary Ask action, AI budget/status card, status chips,
  loading card, inline error state, and result card now follow the DESIGN.md
  card/input/action system.
- Preserved the existing `/ask` route, prompt input behavior,
  backend-mediated expense Q&A call, AI budget status provider, provider
  invalidation after successful calls, and the four-primary-tab IA boundary.
- Added focused Ask widget coverage for light and dark rendering plus inline
  error-state rendering while keeping the existing submit-and-answer test.
- No Edge Function, backend, Supabase schema/RPC, hosted configuration, AI
  semantic changes, push-notification work, M50, or later-milestone work was
  started.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/ai/ai_screen.dart test/finance_features_test.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - M49 has no dedicated Ask/AI Stitch reference asset in the committed
    themed-dashboard export, so DESIGN.md plus existing redesigned primitives
    are the visual authority.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 50: Dialogs, Forms, Empty States, and Motion Pass

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m50---dialogs-forms-empty-states-and-motion-pass).

### Objective

Normalize remaining shared surfaces and low-cost motion after the main screen
redesigns.

### Tasks

- Restyle remaining dialogs, sheets, category forms, label forms, cap forms,
  piggy-bank dialogs, delete/merge confirmations, snackbars, and empty states.
- Add purposeful low-cost motion while respecting accessible navigation.
- Add or update semantic labels and tooltips for icon-only actions.
- Fix any remaining layout constraint issues.

### External Work

- None.

### Acceptance Criteria

- Core dialogs and forms match the redesigned system.
- No known overflow/unbounded-layout issues remain in redesigned flows.
- Important icon-only actions are accessible.

### Deferred Scope

- New product behavior.

### Completion Notes

- Added shared reduced-motion-aware modal, entrance, and press-scale primitives
  and used them to normalize category creation, monthly cap, label, taxonomy,
  category merge/delete, transaction-label, and vault dialog/sheet/form chrome.
- Themed app snackbars as floating rounded toast surfaces, replaced remaining
  Settings empty/detail legacy chrome with shared empty/card primitives, and
  kept long modal action rows visible under constrained viewport heights.
- Added low-cost motion for shared filter pills, Activity mode selection,
  modal/empty/loading entrance, action button press feedback, and vault entry
  type transitions while respecting accessible navigation.
- Preserved existing repository calls, navigation, validation, AI/auth/backend
  semantics, and test keys; no Supabase, schema, RPC, Edge Function, hosted,
  product-behavior, push-notification, M51, or later-milestone work was
  started.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/activity/activity_screen.dart lib/src/shared/widgets/empty_state.dart lib/src/shared/widgets/app_card.dart lib/src/shared/widgets/action_pill.dart lib/src/shared/widgets/chips.dart lib/src/core/theme/app_theme.dart lib/src/features/categories/category_creation_dialog.dart lib/src/features/dashboard/dashboard_screen.dart lib/src/features/transactions/transactions_screen.dart lib/src/features/settings/settings_screen.dart lib/src/features/piggy_banks/piggy_banks_screen.dart`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --plain-name "settings merges categories after explicit subcategory mapping"`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - M50 uses the committed Stitch transaction/details/settings/vault references
    plus `DESIGN.md`; there is no separate dedicated dialog-state Stitch asset
    beyond those screen exports.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 51: UI Redesign Final Regression, Responsive QA, and Docs Closeout

### Status

Completed on 2026-06-14. See
[UI Redesign](UI_REDESIGN.md#m51---final-regression-responsive-qa-and-docs-closeout).

### Objective

Verify the full redesign and fold final UI behavior into durable docs.

### Tasks

- Run full Flutter verification.
- Perform responsive QA at mobile, tablet, and desktop widths.
- Verify system, light, and dark theme behavior across primary flows.
- Update README, milestones, session handoff, and UI redesign docs with final
  behavior and known gaps.
- Confirm deferred push notification, iOS, web, and hosted rollout scope.

### External Work

- None.

### Acceptance Criteria

- `flutter analyze` and `flutter test` pass.
- New navigation, Activity consolidation, Vaults naming, Settings focus mode,
  and theme behavior are documented.
- Milestones 18-21 remain deferred unless explicitly resumed.

### Deferred Scope

- Push notifications, iOS, web, hosted rollout, and new finance semantics.

### Completion Notes

- Added final UI regression coverage for the redesigned shell and core
  authenticated surfaces at 390px mobile, 768px tablet, and 1024px large-window
  widths while cycling light, dark, and system theme modes.
- Extended sign-in and household gate theme coverage to the same representative
  width set.
- Fixed a Dashboard desktop-width layout regression where the wide spending-card
  row could receive unbounded scroll height; the row now preserves equal card
  height through finite intrinsic layout.
- Documented the final UI behavior in the root README, implementation-plan
  README, this milestone tracker, `SESSION_HANDOFF.md`, and `UI_REDESIGN.md`.
- Confirmed deferred scope remains unchanged: Milestones 18-21 push
  notifications, iOS, web, hosted rollout, and later/future milestones were not
  started.
- Verification:
  - `cd apps/mobile && dart format lib/src/features/dashboard/dashboard_screen.dart test/finance_features_test.dart test/widget_test.dart`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "app shell exposes settings outside primary navigation|redesigned core surfaces render at M51 widths and theme modes"`
  - `cd apps/mobile && flutter test test/widget_test.dart --plain-name "auth entry and household gate states render in app themes"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
  - Conflict-marker scan over changed files.
- Assumptions made:
  - The stored 390px Stitch screenshots remain the visual reference for mobile
    hierarchy; tablet and desktop QA is verified through Flutter responsive
    breakpoints and widget coverage.
- Mocks created:
  - None.
- Mocks used:
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/dashboard-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/activity-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/review-unified-navigation.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/vaults-scandi-fintech-refinement.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/settings-focused-view-no-nav.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-details-refined-shapes.jpg`
  - `docs/design-references/stitch/themed-dashboard-ui-redesign/screens/transactions-edit-metadata.jpg`

## Milestone 52: Transaction Delete Database Contract

### Status

Completed on 2026-06-14. See
[Transaction Deletion](TRANSACTION_DELETION.md#m52---transaction-delete-database-contract).

### Objective

Create the owner-only database deletion contract, source tombstones, and
regression coverage that make hard transaction deletion safe.

### Tasks

- Add a source tombstone table for deleted transaction fingerprints.
- Add RLS policies, explicit grants, and service-role read access needed for
  ingestion suppression.
- Add a tombstone trigger so any owner-authorized transaction delete records the
  source fingerprint before child rows cascade.
- Tighten authenticated transaction deletion to owner-only.
- Add an app-facing `security invoker` `delete_transaction` RPC that returns
  deletion impact counts.
- Add pgTAP coverage for owner-only access, cascade/unlink behavior, tombstone
  creation, and summary/monthly-cap spend impact.

### External Work

- None.

### Acceptance Criteria

- Owners can hard-delete their household's transactions through the database
  contract.
- Admins, members, viewers, non-members, and other-household owners cannot
  delete through the app-facing contract.
- Deleted transactions no longer contribute to spend summaries or monthly cap
  progress.
- Source tombstones are recorded without storing full transaction or email
  payload data.

### Deferred Scope

- Workbook importer suppression, Gmail sync suppression, Activity UI, restore,
  undo, bulk delete, push notifications, hosted rollout, iOS, and web.

### Completion Notes

- Added `public.deleted_transaction_sources` as a minimal household-scoped
  tombstone table with owner select/insert RLS, no authenticated delete grant,
  service-role read access, source lookup indexes, and explicit privacy-focused
  constraints/comments.
- Added an `app_private` delete trigger that records tombstones before
  transaction child rows cascade, copying only source identity from the
  transaction and current `transaction_sources` rows.
- Tightened direct authenticated transaction deletes from admin-or-owner to
  owner-only while preserving service-role maintenance behavior.
- Added `public.delete_transaction(...)` as the app-facing `security invoker`
  RPC. It validates signed-in owner access, rejects cross-household and missing
  transactions, deletes the transaction row, and returns source identity plus
  deleted/unlinked association counts.
- Added focused pgTAP coverage in `supabase/tests/transaction_deletion.sql`
  and added the tombstone table to the existing RLS isolation audit.
- Confirmed deferred scope remains unchanged: workbook importer suppression,
  Gmail sync suppression, Activity UI, restore/undo/bulk delete, push
  notifications, hosted rollout, iOS, web, M53, and later milestones were not
  started.
- Verification:
  - `supabase --version`
  - `supabase migration --help`
  - `supabase db --help`
  - Supabase changelog/docs scan for relevant schema, RLS, grants, and
    security guidance.
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/transaction_deletion.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Assumptions made:
  - `gmail_parse_attempts` remains service-only; the app-facing RPC uses a
    private owner-scoped count helper instead of granting authenticated table
    read access.
  - Optional deletion reasons are user-entered metadata and must not contain raw
    transaction payloads or email body content.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 53: Import Resurrection Guard

### Status

Completed on 2026-06-14. See
[Transaction Deletion](TRANSACTION_DELETION.md#m53---import-resurrection-guard).

### Objective

Make workbook and Gmail ingestion skip tombstoned source fingerprints so deleted
transactions cannot be recreated by reruns, retries, sync jobs, or backfills.

### Tasks

- Update workbook import fingerprint handling to skip tombstoned rows.
- Adjust workbook validation totals and import reporting for intentionally
  suppressed rows.
- Update Gmail ingestion SQL to return a suppressed result for tombstoned
  fingerprints without inserting transactions, transaction sources, or review
  items.
- Update Gmail sync handling and sanitized diagnostics so suppression is treated
  as handled work, not a retryable failure.
- Add importer, pgTAP, and Edge Function tests for tombstone suppression while
  preserving existing idempotent upsert behavior for non-deleted sources.

### External Work

- None.

### Acceptance Criteria

- Re-importing a deleted workbook row does not recreate its transaction.
- Reprocessing a deleted Gmail transaction email does not recreate its
  transaction.
- Existing non-deleted source idempotency remains unchanged.
- Suppression diagnostics do not expose raw email bodies or full transaction
  payloads.

### Deferred Scope

- Flutter Activity delete UI, restore, undo, bulk delete, push notifications,
  hosted rollout, iOS, and web.

### Completion Notes

- Added `20260614122706_import_resurrection_guard.sql`, replacing
  `public.ingest_gmail_transaction(...)` with an equivalent ingestion contract
  that first checks `public.deleted_transaction_sources` for matching Gmail
  fingerprints. Tombstoned fingerprints return `suppressed = true` with
  sanitized reason `deleted_transaction_source` and create no transaction,
  transaction source metadata, review item, or source account side effect.
- Updated `gmail-sync` to treat suppressed Gmail parses as handled work, add a
  `suppressed` count, preserve parse-attempt diagnostics without raw body or
  full transaction payload data, and emit a sanitized structured suppression
  log.
- Updated the workbook importer to fetch tombstoned workbook fingerprints before
  transaction writes, skip transaction/source/review upserts for those rows,
  report `suppressedCount`, and validate imported database totals against the
  tombstone-adjusted source set.
- Added focused workbook fixture, Gmail ingestion pgTAP, and Gmail sync unit
  coverage while preserving existing non-deleted idempotent import behavior.
- Confirmed deferred scope remains unchanged: Flutter Activity delete UI,
  restore/undo/bulk delete, push notifications, hosted rollout, iOS, web, M54,
  and M55 were not started.
- Verification:
  - `supabase --version`
  - `supabase functions --help`
  - Supabase changelog/docs scan for relevant Edge Function, CLI, RLS, and
    breaking-change guidance.
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/transaction_deletion.sql`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `deno test --allow-env --allow-read supabase/functions/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Assumptions made:
  - A tombstoned Gmail parse should remain a `parsed` parse attempt with a null
    transaction id and sanitized suppression diagnostics, rather than adding a
    new parse status.
  - Workbook category, source-account, merchant, and alias reference seeding can
    remain based on the source workbook; only transaction-bearing rows are
    suppressed.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 54: Activity Transaction Delete UX

### Status

Completed on 2026-06-14. See
[Transaction Deletion](TRANSACTION_DELETION.md#m54---activity-transaction-delete-ux).

### Objective

Expose owner-only transaction deletion from the Activity transaction detail
surface using the database and ingestion contracts from M52-M53.

### Tasks

- Extend Flutter finance repository contracts with transaction delete request
  and result models.
- Implement the Supabase RPC call plus disabled and fake repository support.
- Add an owner-only destructive action to the transaction detail surface.
- Add confirmation copy that explains spend impact, monthly cap impact,
  preserved/unlinked Vault diagnostics, and source re-import suppression.
- Refresh affected Activity, Dashboard, Trend, Review, Label, month, and Vault
  providers after successful deletion.
- Add focused widget tests for owner visibility, non-owner hiding, cancel,
  confirm, error handling, list removal, and narrow layout behavior.

### External Work

- None.

### Acceptance Criteria

- Household owners can delete a transaction from Activity after confirmation.
- Non-owner roles cannot see or trigger the delete action.
- Deleted transactions disappear from Activity and affected reads refresh.
- Existing metadata and label edit flows still work.

### Deferred Scope

- New Supabase schema, Gmail/workbook ingestion changes, restore, undo, bulk
  delete, push notifications, hosted rollout, iOS, and web.

### Completion Notes

- Added Flutter delete request/result models and
  `FinanceRepository.deleteTransaction(...)`, wired to the existing
  `public.delete_transaction(...)` Supabase RPC with disabled and fake
  repository support.
- Added owner-only destructive delete from Activity transaction details with
  confirmation copy for spend/trend/label/review/monthly-cap impact, preserved
  but unlinked Vault diagnostics, and workbook/Gmail source suppression.
- Successful deletion closes detail, shows a snackbar, refreshes affected
  Activity/Dashboard/Trend/Review/Label/month/Vault providers, and moves back a
  page when the current Activity page becomes empty.
- Added focused tests for owner/non-owner visibility, cancel/confirm/error
  flows, list removal, provider-refetch observability, and narrow layout
  behavior.
- No schema, ingestion, restore, undo, bulk delete, push notification, hosted
  rollout, iOS, web, or Milestone 55 work was started.

## Milestone 55: Transaction Deletion Regression, Docs, and Cleanup

### Status

Completed on 2026-06-14. See
[Transaction Deletion](TRANSACTION_DELETION.md#m55---transaction-deletion-regression-docs-and-cleanup).

### Objective

Verify the full transaction deletion flow across database, ingestion, importer,
and Flutter surfaces, then fold final behavior into durable docs.

### Tasks

- Run the full local Supabase, importer, Edge Function, and Flutter verification
  path.
- Fill any focused regression gaps found during verification.
- Update durable docs with the final transaction deletion, tombstone, and import
  suppression behavior.
- Update this tracker and `SESSION_HANDOFF.md` with completion notes for
  M52-M55.
- Decide whether `TRANSACTION_DELETION.md` should remain as an active companion
  plan or be marked completed-only for later cleanup.

### External Work

- None.

### Acceptance Criteria

- Owner-only hard deletion is verified end to end.
- Deleted transactions cannot be recreated by workbook or Gmail reprocessing.
- Spend summaries, merchant summaries, Activity Charts, labels, review, and
  monthly caps reflect the deletion.
- Final docs and handoff are self-contained for future fresh-context sessions.

### Deferred Scope

- Restore, undo, bulk delete, push notifications, hosted rollout, iOS, web, and
  any production data migration outside local verification.

### Completion Notes

- Completed the final local regression pass for the M52-M55 transaction
  deletion flow. Existing focused coverage already verified owner-only database
  deletion, summary/monthly-cap recalculation, cascade/unlink behavior,
  tombstone privacy shape, workbook suppression, Gmail suppression, Edge
  Function handled-work semantics, and Activity owner-only UI behavior.
- No additional product or schema fixes were required during M55.
- Updated durable planning docs so the final transaction deletion behavior no
  longer depends on the companion plan as active routing context.
- Marked `TRANSACTION_DELETION.md` completed-only in handoff for later cleanup
  under the repository's completed-plan convention.
- Confirmed deferred scope remains unchanged: restore, undo, bulk delete,
  push notifications, hosted rollout, iOS, web, and production data migration
  work were not started.
- Verification:
  - `supabase --version`
  - Supabase changelog scan for relevant breaking changes.
  - `supabase db --help`
  - `supabase test --help`
  - `supabase db reset --help`
  - `supabase db lint --help`
  - `supabase db advisors --help`
  - `supabase test db --help`
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase db advisors --local --fail-on none`
  - `pnpm --dir tools/workbook-import test`
  - `pnpm --dir tools/workbook-import run validate`
  - `deno test --allow-env --allow-read supabase/functions/tests`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug`

## Milestone 56: Merchant Autocomplete Planning and Reference Readiness

### Status

Completed on 2026-06-15.

### Objective

Create the companion plan for merchant autocomplete and duplicate prevention,
then wire the new M57-M60 implementation sequence into durable planning docs.

### Tasks

- Create [Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md) with target
  behavior, existing foundation, global rules, implementation milestones,
  acceptance criteria, and verification expectations.
- Update this milestone tracker, [README](README.md), and
  [Session Handoff](SESSION_HANDOFF.md) so a fresh session can start M57 from
  docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.

### Acceptance Criteria

- `MERCHANT_AUTOCOMPLETE.md` describes M56-M60 as serial, standalone
  milestones.
- M57 is the next recommended implementation milestone.
- No Flutter, Supabase, importer, Edge Function, hosted rollout, iOS, or web
  implementation work is started.

### Completion Summary

- Assumptions made:
  - Merchant autocomplete should be a new non-deferred sequence after M55 while
    M18-M21 remain deferred by user request.
  - The feature can start without a Supabase migration because the app already
    has household merchant lookup reads and backend exact duplicate protection.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 57: Merchant Repository and Activity Filter Foundation

### Status

Completed on 2026-06-15. See
[Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md#m57---merchant-repository-and-activity-filter-foundation).

### Objective

Add canonical merchant filtering to Activity while preserving current free-text
statement merchant search.

### Acceptance Criteria

- Activity supports both arbitrary merchant text search and selecting an
  existing merchant suggestion.
- Selecting a suggestion filters by `merchant_id`; typing afterward returns to
  free-text search.
- Clearing filters resets both typed merchant text and selected merchant id.

### Completion Summary

- Added nullable `merchantId` to `TransactionQuery`, nullable taxonomy ids to
  `MerchantOption`, and repository filtering that prefers canonical
  `merchant_id` when present while preserving statement merchant text search.
- Replaced Activity's visible merchant search field with a Material
  autocomplete-backed control that uses existing merchant options, clears
  canonical selection on free typing, and resets both text and merchant id on
  clear filters.
- Added focused Activity regression coverage for free typing, suggestion
  selection, typing after selection, and route/clear semantics.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Activity"`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "transaction query supports label filter equality and copyWith"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing `public.merchants` category/subcategory fields and RLS-backed reads
    are sufficient; no Supabase migration was needed for M57.
  - Existing `merchant` route query parameters remain statement merchant text
    filters; canonical merchant id selection is local Activity filter state.
  - Milestones 18-21 remain deferred, and Milestones 58-60 were not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with merchant
    category/subcategory fields and selected merchant id filtering.

## Milestone 58: Shared Merchant Autocomplete in Metadata Editor

### Status

Completed on 2026-06-15. See
[Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md#m58---shared-merchant-autocomplete-in-metadata-editor).

### Objective

Reuse existing merchant groups while editing transaction metadata from Activity
or Review.

### Acceptance Criteria

- The shared metadata editor shows merchant suggestions while typing.
- Selecting an existing merchant fills the canonical name and compatible
  category/subcategory values.
- Freeform merchant names remain valid.
- Activity edit and Review resolve flows continue to share the same editor.

### Completion Summary

- Replaced the shared metadata editor's Merchant group text field with a
  local Material autocomplete field backed by
  `merchantOptionsProvider(initialValue.householdId)`.
- Selecting an existing merchant fills the canonical display name and updates
  category/subcategory only when both merchant taxonomy ids are available in
  the editor option lists.
- Preserved freeform merchant names, Suggest updates, Create category,
  confidence, notes, validation, loading, save, cancel, and error behavior.
- Added focused widget coverage for both Activity detail editing and Review
  resolution through the shared editor.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "metadata|merchant review"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing household merchant options are sufficient for metadata-editor
    autocomplete; no Supabase migration was needed for M58.
  - The autocomplete helper should remain local to the shared metadata editor
    until later milestone work proves it needs broader reuse.
  - Milestones 18-21 remain deferred, and Milestones 59-60 were not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options and repository fakes.

## Milestone 59: Close-Match Merchant Save Confirmation

### Status

Completed on 2026-06-15. See
[Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md#m59---close-match-merchant-save-confirmation).

### Objective

Warn before saving a new merchant group that strongly resembles one existing
merchant group.

### Acceptance Criteria

- Strong typo-level matches prompt the user to use the existing merchant or
  keep the typed name.
- Exact case-insensitive existing names skip the popup and save the canonical
  display name.
- Non-match examples do not interrupt saves.

### Completion Summary

- Added a deterministic merchant-name matcher with normalization,
  Levenshtein/token-prefix scoring, and the planned close-match constants.
- Updated the shared transaction metadata editor save flow to canonicalize exact
  matches, prompt for clear close matches, support Use existing, Keep new name,
  and cancel behavior, and avoid re-prompting kept names during the editor
  session.
- Added focused helper/widget coverage for the documented typo, non-match,
  exact, use-existing, keep-new retry, and cancel paths.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant"`
  - `cd apps/mobile && flutter analyze`
- Assumptions made:
  - Existing household merchant options are sufficient for client-side
    close-match comparison; no Supabase migration was needed.
  - The planned `0.82` threshold and `0.05` lead margin passed the documented
    matrix without tuning changes.
  - Milestones 18-21 remain deferred, and Milestone 60 was not started.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository`, extended with an `Uber` merchant option
    and a one-save failure hook for the keep-new retry test.

## Milestone 60: Merchant Autocomplete Regression, Docs, and Cleanup

### Status

Completed on 2026-06-15. See
[Merchant Autocomplete](MERCHANT_AUTOCOMPLETE.md#m60---merchant-autocomplete-regression-docs-and-cleanup).

### Objective

Verify the full merchant autocomplete behavior and fold the final behavior into
durable docs.

### Acceptance Criteria

- Activity, Review, and transaction detail metadata edits all share the final
  merchant autocomplete behavior.
- Full Flutter verification passes locally.
- README, MILESTONES, SESSION_HANDOFF, and the companion plan reflect the final
  behavior.

### Completion Summary

- Verified Activity free-text merchant search, canonical merchant selection,
  Review resolution, transaction detail metadata edits, close-match
  confirmation, existing transaction search behavior, and narrow metadata editor
  layout through focused and full Flutter checks.
- No merchant-autocomplete regressions were found during M60, so no app code,
  Supabase schema, RPC, importer, Edge Function, hosted rollout, iOS, or web
  changes were required.
- Folded final merchant autocomplete behavior into durable docs and marked the
  companion plan completed-only.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|review|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - Existing household merchant option reads and backend exact duplicate
    protection remain sufficient for the final merchant autocomplete behavior;
    no schema or RPC migration was needed.
  - Close-match comparison remains limited to canonical merchant display names.
  - Milestones 18-21 remain deferred by user request.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant options, query capture, and
    metadata correction test hooks.

## Milestone 61: Merchant Group Management Planning and Reference Readiness

### Status

Completed on 2026-06-15.

### Objective

Create the companion plan for Settings merchant group management and wire the
new M62-M64 implementation sequence into durable planning docs.

### Tasks

- Create [Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md) with target
  behavior, existing foundation, global rules, implementation milestones,
  acceptance criteria, and verification expectations.
- Update this milestone tracker, [README](README.md), [Data Model](DATA_MODEL.md),
  and [Session Handoff](SESSION_HANDOFF.md) so a fresh session can start M62
  from docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.

### Acceptance Criteria

- `MERCHANT_GROUP_MANAGEMENT.md` describes M61-M64 as serial, standalone
  milestones.
- M62 is the next recommended implementation milestone.
- No Flutter, Supabase, importer, Edge Function, hosted rollout, iOS, or web
  implementation work is started.

### Completion Summary

- Assumptions made:
  - A "merchant group" is the existing canonical `public.merchants` row.
  - Rename is a global canonical display-name update that preserves merchant
    ids.
  - Merge supports user-selected category strategy, with Preserve categories as
    the default and Destination category available when the destination merchant
    has category/subcategory values.
  - Statement-merchant-level reassignment, alias editing, deletion, hosted
    rollout, iOS, web, and push notifications are out of scope.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 62: Merchant Group Data and Repository Contract

### Status

Completed on 2026-06-15. See
[Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md#m62---merchant-group-data-and-repository-contract).

### Objective

Add the RLS-safe Supabase and Flutter repository contract needed for merchant
group rename and merge before building the Settings UI.

### Acceptance Criteria

- Database tests prove merchant rename and merge are household-scoped,
  duplicate-safe, role-safe, and preserve or apply taxonomy according to the
  selected strategy.
- Repository tests prove Flutter can fetch merchant group usage, call rename,
  call merge, parse counts, and group dashboard top merchants canonically.
- Existing merchant autocomplete and transaction metadata correction behavior
  still works.

### Completion Summary

- Added the RLS-safe merchant group data/repository contract: usage view,
  rename RPC, merge RPC, pgTAP tests, Flutter repository models/providers, fake
  repository hooks, and canonical Dashboard top-merchant grouping.
- Verified merchant rename/merge preserve/destination semantics, role and
  household isolation, adjacent merchant metadata/review behavior, full pgTAP,
  schema lint, focused Flutter tests, Flutter analysis, full Flutter tests, and
  diff cleanliness.
- Milestones 18-21 remain deferred by user request, and Milestone 63 Settings
  UI work was not started.
- Assumptions made:
  - Destination-strategy merge requires destination category and subcategory
    values before applying taxonomy to moved source references.
  - Direct merchant deletion remains out of scope; source merchant rows are
    deleted only inside the merge RPC after references move.
  - Hosted Supabase migration push remains separate from this local milestone.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` data, extended for merchant group
    snapshot, rename, merge, alias counts, and canonical Dashboard grouping.

## Milestone 63: Settings Merchant Group Manager UX

### Status

Completed on 2026-06-15. See
[Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md#m63---settings-merchant-group-manager-ux).

### Objective

Add the visible Settings management section for renaming and merging merchant
groups using the M62 repository contract.

### Acceptance Criteria

- Settings exposes a Merchant groups section beside Categories and Labels.
- A household writer can rename a merchant group from Settings.
- A household writer can merge multiple source merchant groups into one
  destination with an explicit category strategy.
- Empty, loading, error, narrow, and long-name states remain usable.
- Dashboard, Activity, Review, chart/report, and autocomplete data refresh
  after saves.

### Completion Summary

- Added the Settings Merchant groups card using the M62 repository/provider
  contract, including compact rows with canonical merchant name, taxonomy
  context, transaction/net-spend usage, aliases, active rules, and open Review
  impact.
- Added rename and merge dialogs for merchant groups. Merge requires an explicit
  Preserve categories or Destination category strategy, defaults to Preserve
  categories, disables Destination category when the destination lacks taxonomy,
  and saves through `mergeMerchantGroups`.
- Rename and merge completion invalidates merchant group manager, merchant
  options, transactions, trend reports, Dashboard snapshots, and Review queue
  providers.
- Added focused widget coverage for rendering, rename, merge validation,
  preserve submission, destination-strategy disabling, provider refresh effects,
  and narrow/long-name layout behavior.
- Milestones 18-21 remain deferred by user request, and Milestone 64 regression
  and docs cleanup was not started.
- Assumptions made:
  - The M62 repository/RPC contract is sufficient for M63; no Supabase migration,
    RPC, or repository API addition was needed.
  - Destination category strategy requires both destination category and
    subcategory values.
  - Alias editing, statement-merchant reassignment, merchant deletion, hosted
    rollout, iOS, web, and push notifications remain out of scope.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` data and M62 merchant-group hooks, extended
    with a merchant-options fetch counter, provider refresh probe, and long-name
    merchant fixture for M63 widget coverage.

## Milestone 64: Merchant Group Management Regression, Docs, and Cleanup

### Status

Completed on 2026-06-15. See
[Merchant Group Management](MERCHANT_GROUP_MANAGEMENT.md#m64---merchant-group-management-regression-docs-and-cleanup).

### Objective

Verify the full merchant group workflow and fold final behavior into durable
docs.

### Acceptance Criteria

- Full Supabase and Flutter verification passes locally or any environment
  limitation is documented.
- Durable docs explain merchant group rename/merge behavior, category strategy,
  provider refresh expectations, and deferred items.
- The companion plan is marked completed-only after M64 is complete.
- M18-M21 remain deferred unless explicitly resumed.

### Completion Summary

- Verified the full merchant group workflow with local Supabase reset, focused
  merchant-group pgTAP, full pgTAP, schema lint, focused Flutter coverage for
  merchant, metadata, Activity, Review, Settings, Dashboard, and narrow-layout
  paths, Flutter analysis, and the full Flutter test suite.
- Confirmed Settings merchant group rename and merge use
  `rename_household_merchant(...)` and `merge_household_merchants(...)`; no
  stale direct client writes bypass the Settings manager RPC contract.
- Folded final merchant group rename/merge behavior, explicit merge category
  strategy, provider refresh expectations, deferred scope, and verification
  results into durable docs. `MERCHANT_GROUP_MANAGEMENT.md` is now a
  completed-only reference.
- No app code, Supabase migration, RPC, importer, Edge Function, hosted rollout,
  iOS, web, or push notification changes were required during M64.
- Milestones 18-21 remain deferred by user request; no later milestone work was
  started.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/merchant_group_management.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|Review|Settings|dashboard|narrow"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `rg -n "\\.from\\('merchants'\\)|\\.from\\(\\\"merchants\\\"\\)|rename_household_merchant|merge_household_merchants|rpc\\('rename_household_merchant'\\)|rpc\\('merge_household_merchants'\\)|update\\(|delete\\(" apps/mobile/lib/src apps/mobile/test supabase/functions tools/workbook-import/src`
  - `git diff --check`
- Assumptions made:
  - M62-M63 already implemented the intended merchant group product behavior;
    M64 did not need additional runtime changes after regression passed.
  - Direct `merchants` reads for autocomplete and metadata suggestion context
    remain valid; Settings rename/merge writes stay RPC-backed.
  - Hosted Supabase migration push, alias editing, statement-merchant
    reassignment, merchant deletion outside merge, iOS, web, and push
    notifications remain out of scope.
- Mocks created:
  - None.
- Mocks used:
  - Existing `_FakeFinanceRepository` merchant group, merchant option,
    metadata correction, Activity query, Dashboard summary, Review queue, and
    provider refresh test hooks.

## Milestone 65: Gmail Label Ingestion Planning and Reference Readiness

### Status

Completed on 2026-06-16.

### Objective

Create the companion plan for label-based HDFC Gmail ingestion and wire the new
M66-M69 implementation sequence into durable planning docs.

### Tasks

- Create [Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md) with target
  behavior, existing foundation, global rules, implementation milestones,
  acceptance criteria, and verification expectations.
- Update this milestone tracker, [README](README.md), [Data Model](DATA_MODEL.md),
  [Ingestion Design](INGESTION.md), [Gmail Connector](GMAIL_CONNECTOR.md), and
  [Session Handoff](SESSION_HANDOFF.md) so a fresh session can start M66 from
  docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.

### Acceptance Criteria

- `GMAIL_LABEL_INGESTION.md` describes M65-M69 as serial, standalone
  milestones.
- M66 is the next recommended implementation milestone.
- No Flutter, Supabase, importer, Edge Function, hosted rollout, iOS, or web
  implementation work is started.

### Completion Summary

- Created the Gmail label ingestion companion plan and routed future
  implementation through M66-M69.
- Confirmed the target mailbox selection is the Gmail label
  `Banking/HDFC Transactions`, including archived/non-Inbox messages carrying
  that label.
- Confirmed Gmail OAuth remains readonly, parser routing moves to body regex
  templates, unmatched watched-label mail should surface as sanitized Review
  parse failures, and `Netbanking :: IMPS` is a source/candidate type rather
  than category taxonomy.
- M66 was not started.
- Assumptions made:
  - Gmail API reports the nested label name as `Banking/HDFC Transactions`.
  - Existing connected mailboxes can be migrated to label-based watch renewal
    without reconnecting because the Gmail scope stays readonly.
  - The provided IMPS sample represents a debit-spend transaction.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 66: Gmail Label Watch and Backfill Contract

### Status

Completed on 2026-06-16. See
[Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md#m66---gmail-label-watch-and-backfill-contract).

### Objective

Replace Inbox/sender-based Gmail candidate discovery with readonly watch,
history, and backfill selection for the `Banking/HDFC Transactions` label.

### Acceptance Criteria

- OAuth callback and watch renewal store the watched label id/name and configure
  Gmail watch for `Banking/HDFC Transactions`.
- Archived/non-Inbox messages carrying that label can be found by backfill.
- History sync can enqueue and process candidates from watched-label message
  and label-added history.
- Missing label produces an operator-visible connector error.
- Existing Inbox-only behavior is no longer the default for active Gmail sync.

### Completion Summary

- Added watched Gmail label id/name/resolution storage on `linked_mailboxes`,
  connector-status exposure, and the updated service-role
  `upsert_gmail_mailbox(...)` contract for OAuth setup.
- Updated shared Gmail helpers, OAuth callback, watch renewal, and sync/backfill
  processing to resolve and use the exact `Banking/HDFC Transactions` Gmail label
  for watch, history, backfill, and thread-message filtering.
- Existing connected mailboxes can resolve and store the watched label during sync
  without a new Gmail scope; renewal configures future watches with the same
  label id.
- Added focused pgTAP and Edge Function unit coverage for label persistence,
  label-filtered watch/history/backfill, and skipping thread messages that lack
  the watched label.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `supabase test db --local supabase/tests`
  - `deno test --allow-env --allow-net supabase/functions/tests/google.test.ts`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `supabase db advisors --local --fail-on none`
  - `git diff --check`
- Known gaps:
  - Supabase advisors still report pre-existing merchant RLS performance warnings
    unrelated to M66.
- Assumptions made:
  - Gmail API returns the nested label name exactly as
    `Banking/HDFC Transactions`.
  - Missing watched label is a connector/operator error, not a reason to fall
    back to Inbox/sender discovery.
  - Milestones 18-21 remain deferred, and Milestones 67-69 were not started.
- Mocks created:
  - None.
- Mocks used:
  - Stubbed Gmail API responses in Edge Function unit tests.

## Milestone 67: Body-First Parser Registry and Netbanking IMPS Parser

### Status

Completed on 2026-06-16. See
[Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md#m67---body-first-parser-registry-and-netbanking-imps-parser).

### Objective

Route watched-label Gmail candidates by deterministic body regex templates and
add the HDFC `Netbanking :: IMPS` debit template.

### Acceptance Criteria

- `netbanking_imps` is available as a Gmail/source candidate type without
  changing ledger `transaction_type` semantics.
- Credit-card, UPI, and Netbanking IMPS parsing are selected by body templates,
  not sender/subject routing.
- The provided IMPS sample parses to amount `33500.00`, transaction date
  `2026-06-16`, ledger `debit_spend`, statement merchant
  `IMPS to ending 4428`, and source reference `616734130236`.
- Unmatched watched-label messages create sanitized parse failures instead of
  silent drops.

### Completion Summary

- Added `netbanking_imps` as a source/candidate type and allowed
  `netbanking_imps` plus `other` Gmail parse-attempt diagnostics.
- Moved Gmail parser routing to first successful body parser match, preserving
  existing credit-card and UPI fixtures without sender/subject gating.
- Added the HDFC Netbanking IMPS debit parser and fixture for amount
  `33500.00`, date `2026-06-16`, merchant `IMPS to ending 4428`, reference
  `616734130236`, and account ending `0932`.
- Updated Gmail sync fingerprinting, SQL ingestion tests, parse-failure health
  tests, Flutter labels, and source-type dropdown labels for
  `Netbanking :: IMPS`.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures"`
  - `cd apps/mobile && flutter analyze`
  - `git diff --check`
- Deferred scope was not started: Review ignore UI/RPC, hosted rollout, iOS,
  web, push notifications, M68, or M69.
- Assumptions made:
  - The IMPS sample is a debit-spend template for HDFC account ending `0932`.
  - IMPS duplicate suppression should key on source reference plus source
    account identity.
  - Candidate type `other` is only for sanitized watched-label parse failures.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake Flutter finance repository hooks for parse-failure label
    coverage.

## Milestone 68: Watched-Label Parse Failures and Review Ignore

### Status

Completed on 2026-06-16. See
[Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md#m68---watched-label-parse-failures-and-review-ignore).

### Objective

Surface watched-label parse failures in Review with enough safe metadata for
the household to understand what failed, plus a persistent `Ignore for now`
action.

### Acceptance Criteria

- Review shows sender, subject, received time, reason, parser/status context,
  message id, and thread id for visible parse failures without exposing raw body
  content.
- `Ignore for now` hides one failure household-wide while preserving
  service-only diagnostics.
- Parsed rows, outside-date rows, ignored rows, and other households' rows are
  excluded from the visible Review failure list.
- Existing transaction review behavior remains unchanged.

### Completion Summary

- Added persistent Gmail parse-failure ignore state on `gmail_parse_attempts`
  with `ignored_at`, `ignored_by`, sanitized list filtering, and the
  authenticated household-scoped `ignore_gmail_parse_failure(...)` RPC.
- Confirmed unmatched watched-label messages already record sanitized
  `other`/`unsupported_labeled_gmail_message` failures through the M67 sync path;
  M68 did not need Edge Function changes.
- Added Flutter repository support and a row-level Review `Ignore for now`
  action that hides one visible failure and removes the card when all visible
  failures are ignored.
- Added pgTAP and widget coverage for RPC privileges, household isolation,
  ignored-row filtering, and single/all-row ignore behavior.
- Milestones 18-21 remain deferred by user request, and Milestone 69 was not
  started.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/rls_isolation.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Ignore for now|Netbanking"`
  - `git diff --check`
- Assumptions made:
  - Active household membership is sufficient for hiding a visible parse failure.
  - Re-recording the same parser failure should preserve that row's ignore state.
  - Existing M67 unsupported watched-label parse-attempt recording satisfies the
    M68 parse-failure creation contract.
- Mocks created:
  - None.
- Mocks used:
  - Existing fake Flutter finance repository hooks, extended with Gmail
    parse-failure ignore tracking and in-memory row removal.

## Milestone 69: Gmail Label Ingestion Regression, Docs, and Cleanup

### Status

Completed on 2026-06-16. See
[Gmail Label Ingestion](GMAIL_LABEL_INGESTION.md#m69---gmail-label-ingestion-regression-docs-and-cleanup).

### Objective

Run the final local regression pass for the label-based Gmail ingestion flow
and fold completed behavior back into durable docs.

### Acceptance Criteria

- Supabase, Edge Function, and Flutter verification for the label-based Gmail
  ingestion sequence passes locally or documents an environment limitation.
- Durable docs describe final label watch/backfill behavior, body-first parser
  routing, Netbanking IMPS parsing, sanitized parse failures, Review ignore
  behavior, privacy boundaries, and operational runbook changes.
- `GMAIL_LABEL_INGESTION.md` is marked completed-only after M69 completes.
- M18-M21 remain deferred unless explicitly resumed.

### Completion Summary

- Verified the complete label-based Gmail ingestion flow locally across
  migrations, focused Gmail pgTAP, full pgTAP, schema lint, parser tests, Gmail
  Edge Function tests, Flutter analysis, focused Review/Settings/Activity
  coverage, and the full Flutter test suite.
- Confirmed durable docs describe readonly `Banking/HDFC Transactions` label
  watch/backfill, body-first parser routing, `Netbanking :: IMPS`, sanitized
  watched-label parse failures, Review `Ignore for now`, privacy boundaries,
  and production runbook expectations.
- Marked `GMAIL_LABEL_INGESTION.md` completed-only. No runtime code, Supabase
  migration, SQL test, importer, Edge Function, hosted rollout, iOS, web, or
  push notification changes were required during M69.
- Milestones 18-21 remain deferred by user request; no later milestone work was
  started.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `node --test supabase/functions/tests/gmail_parsers.test.mjs`
  - `deno test --allow-env --allow-net supabase/functions/tests/google.test.ts`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Settings|Activity"`
  - `cd apps/mobile && flutter test`
  - `git diff --check`
- Assumptions made:
  - M66-M68 already implemented the intended runtime behavior; M69 only needed
    verification and documentation closeout after regression passed.
  - Hosted Supabase migration push, Edge Function deployment, iOS, web, and
    push notifications remain out of scope.
  - The watched Gmail label remains exactly `Banking/HDFC Transactions` and
    Gmail OAuth remains readonly.
- Mocks created:
  - None.
- Mocks used:
  - Existing Gmail API stubs in Edge Function tests and existing fake Flutter
    finance repository hooks for Review parse-failure coverage.

## Milestone 70: Gmail Parse Failure Review Planning and Reference Readiness

### Status

Completed on 2026-06-16.

### Objective

Create the companion plan for paginated Gmail parse-failure review and
on-demand email body viewing, then wire M71-M73 into durable planning docs.

### Tasks

- Create [Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md) with
  target behavior, existing foundation, global rules, implementation
  milestones, acceptance criteria, and verification expectations.
- Update this milestone tracker, [README](README.md), [Data Model](DATA_MODEL.md),
  [Ingestion Design](INGESTION.md), [Gmail Connector](GMAIL_CONNECTOR.md),
  [Production Readiness](PRODUCTION_READINESS.md), and
  [Session Handoff](SESSION_HANDOFF.md) so a fresh session can start M71 from
  docs alone.
- Preserve M18-M21 push-notification deferral and leave implementation planned
  only.

### Acceptance Criteria

- `GMAIL_PARSE_FAILURE_REVIEW.md` describes M70-M73 as serial, standalone
  milestones.
- M71 is the next recommended implementation milestone.
- No Flutter, Supabase, importer, Edge Function, hosted rollout, iOS, or web
  implementation work is started.

### Completion Summary

- Created the Gmail parse failure review companion plan and routed future
  implementation through M71-M73.
- Confirmed the plan covers paginated access to all unignored Gmail parse
  failures, row-scoped plain-text body viewing from Review, and unchanged
  `Ignore for now` behavior.
- Confirmed the Flutter app must not call service-key helpers; the planned body
  fetch uses a new authenticated Edge Function after household-scoped row
  authorization.
- M71 was not started.
- Assumptions made:
  - Review should page through all unignored Gmail parse failures instead of
    relying on the current default list limit.
  - Plain-text email bodies should be fetched on demand and not stored.
  - Unsupported watched-label emails should continue to appear as `other`
    parse-failure rows.
- Mocks created:
  - None.
- Mocks used:
  - None.

## Milestone 71: Parse Failure Pagination and Body Fetch Contract

### Status

Completed on 2026-06-16. See
[Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md#m71---parse-failure-pagination-and-body-fetch-contract).

### Objective

Add the backend and repository contract needed to page all visible parse
failures and fetch one failure's plain-text Gmail body on demand.

### Acceptance Criteria

- Review data access can request all unignored parse failures page by page.
- A signed-in household member can fetch the plain-text body for one visible,
  unignored parse failure row.
- Users cannot fetch another household's body, an ignored row's body, a parsed
  row's body, or an arbitrary Gmail message id.
- Raw body text is returned only in the body-fetch response and is not stored or
  logged.
- Existing ignore behavior remains unchanged.

## Milestone 72: Review UI Pagination and Email Body Dialog

### Status

Planned. See
[Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md#m72---review-ui-pagination-and-email-body-dialog).

### Objective

Make the Review screen expose all visible Gmail parse failures and show one
failure's plain-text email body in a dialog.

### Acceptance Criteria

- Review can load the first page and later pages of Gmail parse failures.
- A user can open a visible failure row and read the plain-text email body.
- Body loading, body fetch failure, retry, and close flows are visible and
  tested.
- Ignoring a row still hides only that row and does not break pagination.
- Existing merchant review and transaction correction flows remain unchanged.

## Milestone 73: Parse Failure Review Regression, Docs, and Cleanup

### Status

Planned. See
[Gmail Parse Failure Review](GMAIL_PARSE_FAILURE_REVIEW.md#m73---parse-failure-review-regression-docs-and-cleanup).

### Objective

Verify the complete parse-failure review workflow and fold final behavior back
into durable docs.

### Acceptance Criteria

- Full focused Supabase, Edge Function, and Flutter verification passes locally
  or documents an environment limitation with compensating evidence.
- Durable docs describe paginated parse-failure Review, on-demand plain-text
  body viewing, privacy boundaries, and operational backfill expectations.
- `GMAIL_PARSE_FAILURE_REVIEW.md` is marked completed-only.
- No unrelated deferred work is started.

## Cross-Milestone Consistency Rules

- Ask the user before proceeding on any undocumented decision. Codex may recommend a default, but must wait for confirmation.
- Keep all finance rows scoped to `household_id`.
- Use RLS for app-accessible tables.
- Do not store raw email bodies by default.
- Do not store FCM service account JSON or private keys in Flutter or tracked
  docs.
- Use `net_expense` for summaries and monthly caps.
- Exclude card bill payments from spend.
- Treat refunds as reducing net expense.
- Ensure imports and sync jobs are idempotent.
- Deleted transaction source fingerprints must stay suppressed from future
  workbook and Gmail ingestion once Milestones 52-55 are implemented.
- Keep push delivery asynchronous so FCM failures do not block ingestion.
- Keep category management app-facing and RLS-safe; never delete transactions
  during taxonomy deletion or merge.
- Requeue transactions to Review for category deletion, and require explicit
  subcategory mapping for category merge.
- Keep merchant group management app-facing and RLS-safe. Rename preserves
  merchant ids; merge never deletes transactions and must use an explicit
  category strategy.
- Keep transaction labels separate from categories and merchant mappings. Label
  changes must not reclassify transactions, alter future import behavior, or
  send transactions to Review.
- Multi-target monthly caps use required names, category and/or label targets,
  OR matching, one-count-per-cap transaction semantics, and allowed overlap
  between separate caps.
- Recurring monthly caps use explicit cap-series identity. Edits and deletes
  apply from the selected month forward, and optional carry-forward can be
  positive or negative.
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
