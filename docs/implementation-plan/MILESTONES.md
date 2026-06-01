# PocketMoney Milestones

Each milestone is intended to be executable in a separate thread. A new thread should read `README.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `INGESTION.md`, and the active milestone before making changes.

## Milestone 1: Project Foundation

### Objective

Create the initial Flutter and Supabase project structure with local development conventions, environment handling, testing scaffolds, and documentation references.

### Tasks

- Create Flutter app scaffold for web, Android, and iOS.
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
- Flutter web can run locally and show a placeholder authenticated-app shell.
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
- Add Google sign-in for web and mobile.
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
- User configures OAuth redirect URLs for local web and mobile development.

### Acceptance Criteria

- User can sign in and sign out.
- App creates/loads profile and household.
- Navigation works on desktop web and mobile viewport.
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
- Charts remain legible on web and mobile.

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
- Deploy Flutter web to Cloudflare Pages or chosen static host.
- Configure Android and iOS builds.
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
- User configures Cloudflare Pages or preferred hosting.
- User configures Google Cloud production OAuth details.
- User creates Apple Developer and Google Play Console accounts if mobile distribution is required.

### Acceptance Criteria

- Web app is deployed and usable.
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
  - `merchant_research_suggestions`
- Add AI budget configuration:
  - Monthly household AI spend cap.
  - Per-feature enable/disable flags.
- Add backend-only LLM provider integration.
- Add expense Q&A function:
  - Validate household membership.
  - Retrieve scoped data through safe SQL views.
  - Call LLM.
  - Store token usage and answer metadata.
- Add merchant research function:
  - Normalize merchant name.
  - Check cache first.
  - Use web search/LLM only for unknown or low-confidence merchants.
  - Store suggestions for user approval.
- Add UI:
  - Ask expenses screen or command panel.
  - Merchant research suggestions in review queue.
  - AI usage/budget status in settings.
- Add tests:
  - AI cannot access another household.
  - AI usage is logged.
  - Cached merchant research prevents repeated calls.
  - Budget cap prevents additional AI calls.
- If Edge Function limits become a problem, add a dedicated worker that consumes `ai_jobs`.

### External Work

- User creates LLM provider account.
- User configures API key in Supabase secrets.
- User sets initial monthly AI budget cap.
- User approves whether web search is enabled for merchant research.

### Acceptance Criteria

- LLM calls happen only from backend functions or workers.
- Every AI call is logged with token/cost metadata.
- User can ask scoped expense questions.
- Merchant research suggestions require approval before changing mappings.
- AI feature respects configured budget caps.

## Cross-Milestone Consistency Rules

- Keep all finance rows scoped to `household_id`.
- Use RLS for app-accessible tables.
- Do not store raw email bodies by default.
- Use `net_expense` for summaries and budgets.
- Exclude card bill payments from spend.
- Treat refunds as reducing net expense.
- Ensure imports and sync jobs are idempotent.
- Prefer deterministic rules before AI.
- Keep client code free of service credentials.
- Update these docs when architecture decisions change.

