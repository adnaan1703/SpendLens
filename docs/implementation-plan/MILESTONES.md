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

Planned. See
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

## Milestone 48: Sign-In and Household Gate Redesign

### Status

Planned. See [UI Redesign](UI_REDESIGN.md#m48---sign-in-and-household-gate-states).

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

## Milestone 49: Ask / AI Redesign

### Status

Planned. See [UI Redesign](UI_REDESIGN.md#m49---ask--ai-screen).

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

## Milestone 50: Dialogs, Forms, Empty States, and Motion Pass

### Status

Planned. See
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

## Milestone 51: UI Redesign Final Regression, Responsive QA, and Docs Closeout

### Status

Planned. See
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
- Keep push delivery asynchronous so FCM failures do not block ingestion.
- Keep category management app-facing and RLS-safe; never delete transactions
  during taxonomy deletion or merge.
- Requeue transactions to Review for category deletion, and require explicit
  subcategory mapping for category merge.
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
