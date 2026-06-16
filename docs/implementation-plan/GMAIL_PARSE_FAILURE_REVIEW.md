# Gmail Parse Failure Review Plan

Completed-only reference after Milestone 73.

Last updated: 2026-06-16

This document is the completed implementation reference for making Gmail parse
failures fully reviewable from the app. Milestones 70-73 were executed as
standalone milestones, with no automatic continuation into later work.

## Target Behavior

Every email inside the watched Gmail label should have an observable ingestion
outcome. Supported emails create transactions or transaction review items.
Unsupported or unparseable watched-label emails create sanitized Gmail parse
failure rows that are visible in Review until ignored.

- Review can page through all unignored Gmail parse failures, not only the
  first default page.
- Tapping a parse-failure row, or using a visible view-email action, opens a
  dialog with the plain-text email body fetched from Gmail on demand.
- Images, attachments, and HTML-only rendering are omitted. The dialog shows the
  text part that parser code can inspect.
- The email body is not stored in Postgres, returned from list RPCs, included in
  logs, or cached as durable app data.
- Body fetch is authenticated, household-scoped, and row-scoped to a visible
  Gmail parse failure. The Flutter app must not call service-key helpers.
- `Ignore for now` remains available and continues to hide exactly one failure
  row household-wide while preserving service-only diagnostics.
- Historical messages that were skipped before this contract require an
  explicit Gmail backfill or resync over the relevant date range before they can
  appear in Review.

## Existing Foundation

- Milestones 65-69 completed readonly watched-label ingestion for
  `Banking/HDFC Transactions`, body-first parser routing, `Netbanking :: IMPS`,
  sanitized `other` parse failures, and Review `Ignore for now`.
- `gmail_parse_attempts` stores service-only diagnostics for parsed,
  parse-failed, and outside-date-range Gmail candidates. It intentionally does
  not store raw bodies or snippets.
- `list_gmail_parse_failures(...)` exposes sanitized unignored parse failures to
  the app, but currently uses a small default result limit.
- `ignore_gmail_parse_failure(...)` is the app-facing authenticated RPC for
  hiding one visible failure row.
- Review currently renders a Gmail parse failures card from the repository
  provider and supports ignoring rows.
- `gmail-message-body` is a service-key/admin helper that can fetch a Gmail
  message body by mailbox and `source_message_id`, but it is not safe for direct
  Flutter calls.
- `gmail-sync` records unmatched watched-label mail as candidate type `other`
  with parser `unsupported_labeled_gmail_message` and reason
  `no_supported_body_template_matched`.

## Global Rules For M70-M73

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Keep Gmail OAuth readonly. Do not request `gmail.modify`, mutate Gmail labels,
  mark messages read, archive mail, or alter the user's mailbox.
- Do not store raw email bodies, body snippets, OAuth tokens, service keys, or
  full Gmail message payloads in app-visible tables.
- Use `supabase migration new <name>` for every schema migration. Do not invent
  migration filenames by hand.
- Keep `gmail_parse_attempts` service-only. Expose app behavior only through
  sanitized, household-scoped RPCs and authenticated Edge Functions.
- The app-facing body fetch may return the current plain-text Gmail body only
  after authorizing the signed-in user against the visible parse-failure row.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M70 - Gmail Parse Failure Review Planning and Reference Readiness

Status: Completed on 2026-06-16.

Purpose: Create this companion plan and wire M71-M73 into durable planning docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `DATA_MODEL.md`, `INGESTION.md`, `GMAIL_CONNECTOR.md`,
  `PRODUCTION_READINESS.md`, `MILESTONES.md`, and `SESSION_HANDOFF.md` so a
  fresh session can start M71 from docs alone.
- Preserve M18-M21 push-notification deferral.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, or web implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `GMAIL_PARSE_FAILURE_REVIEW.md` describes M70-M73 as serial standalone
  milestones.
- M71 is the next recommended non-deferred implementation milestone.
- The docs state that implementation remains planned only.

Verification:

```bash
rg -n "GMAIL_PARSE_FAILURE_REVIEW|Milestone 7[0-3]|gmail-parse-failure-body|Load more|plain_text_body" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Gmail parse failure review companion plan and routed future
  implementation through M71-M73.
- Confirmed the target behavior: all watched-label emails should have an
  observable ingestion outcome, unparseable or unsupported messages should
  appear in Review, and users should be able to open the plain-text email body
  on demand from a parse-failure row.
- Confirmed body fetch must not store raw email body data and must not expose
  service-key helpers to Flutter.
- Implementation remains planned only; M71 was not started.
- Assumptions made:
  - The user wants the Review backlog to support paginated access to all
    unignored parse failures.
  - The user wants email body text fetched on demand, not stored.
  - Unsupported watched-label mail should remain categorized as `other` for
    parse-failure review.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M71 - Parse Failure Pagination and Body Fetch Contract

Status: Completed on 2026-06-16.

Purpose: Add the backend and repository contract needed to page all visible
parse failures and fetch one failure's plain-text Gmail body on demand.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `INGESTION.md`, `GMAIL_CONNECTOR.md`, `PRODUCTION_READINESS.md`,
  `MILESTONES.md`, `SESSION_HANDOFF.md`, `gmail-message-body`,
  Gmail shared helpers, Gmail Edge Function tests, `gmail_parse_attempts`,
  `list_gmail_parse_failures`, `ignore_gmail_parse_failure`,
  `finance_repository.dart`, `merchant_review_screen.dart`, and Review widget
  tests.
- Use the Supabase skill. Check relevant Supabase CLI help before migrations
  and use `supabase migration new gmail_parse_failure_review_contract`.
- Extend `list_gmail_parse_failures(...)` with explicit `p_limit` and
  `p_offset` support. Preserve the existing default limit for compatibility,
  but allow Review to request later pages deterministically.
- Return a stable ordering by `source_received_at desc` and a deterministic
  tiebreaker so pagination cannot skip or duplicate rows during normal reads.
- Add an app-facing authorization helper or RPC that validates one failure id is
  visible to the signed-in user's active household and returns the mailbox id,
  `source_message_id`, and safe metadata needed by the Edge Function.
- Add a new authenticated Edge Function named `gmail-parse-failure-body` that:
  - Requires the signed-in user JWT.
  - Authorizes through the row-scoped helper/RPC.
  - Uses service-side mailbox credentials to fetch exactly that Gmail message.
  - Returns metadata plus `plain_text_body`.
  - Does not return body-part diagnostics, raw MIME, HTML, attachments, images,
    OAuth token data, or service-only diagnostics.
  - Does not write the body to Postgres or logs.
- Keep `gmail-message-body` as service-key/admin tooling only; do not weaken its
  authorization or call it directly from Flutter.
- Add Flutter repository models and methods for paginated parse-failure reads
  and one body fetch.
- Do not change the Review UI beyond repository contract plumbing in this
  milestone.
- Do not add new parsers, Gmail mutation, hosted rollout, iOS, web, or push
  notifications in this milestone.

Expected code shape:

- List pagination remains an authenticated RPC contract over sanitized
  `gmail_parse_attempts` data.
- Body fetch is a separate authenticated Edge Function because it must use
  service-side Gmail credentials after row-level app authorization.
- The repository exposes page state and body fetch results without persisting
  body text.

Acceptance criteria:

- Review data access can request all unignored parse failures page by page.
- A signed-in household member can fetch the plain-text body for one visible,
  unignored parse failure row.
- Users cannot fetch another household's body, an ignored row's body, a parsed
  row's body, or an arbitrary Gmail message id.
- Raw body text is returned only in the body-fetch response and is not stored or
  logged.
- Existing ignore behavior remains unchanged.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase test db --local supabase/tests/rls_isolation.sql
supabase db lint --local --schema app_private,public --fail-on error
deno test --allow-env --allow-net supabase/functions/tests/gmail_parse_failure_body.test.ts
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review"
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added `20260616145328_gmail_parse_failure_review_contract.sql` with
  deterministic `list_gmail_parse_failures(p_household_id, p_limit, p_offset)`
  pagination and `authorize_gmail_parse_failure_body(p_failure_id)` for
  row-scoped, household-scoped body-fetch authorization.
- Added authenticated `gmail-parse-failure-body`, configured with
  `verify_jwt = true`, to authorize a visible parse-failure row, fetch the
  current Gmail message body through service-side mailbox credentials, and
  return only safe metadata plus `plain_text_body`.
- Kept `gmail-message-body` service-key/admin-only and did not expose body-part
  diagnostics, raw MIME, snippets, HTML, attachments, images, OAuth token data,
  or service-only diagnostics to Flutter.
- Added Flutter repository page/body models and methods while preserving the
  existing Review list provider; visible Review pagination controls and the body
  dialog remain planned for M72 and were not started.
- Milestones 18-21 remained deferred and were not started.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/rls_isolation.sql`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_parse_failure_body.test.ts`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review"`
  - `cd apps/mobile && flutter analyze`
  - `git diff --check`
- Assumptions made:
  - Offset pagination is sufficient for the Review backlog because rows are
    ordered by `source_received_at desc`, `created_at desc`, and `id desc`.
  - Returning mailbox id/email, source ids, parser metadata, and Gmail message
    headers is safe metadata for the body dialog, while the email body remains
    transient and response-only.
  - The current Review screen should continue using the first page until M72
    adds visible pagination and body dialog state.
- Mocks created:
  - Edge Function unit-test stubs for row authorization, refresh-token lookup,
    Gmail token refresh, and Gmail message fetch.
- Mocks used:
  - Existing fake Flutter finance repository, extended with paginated parse
    failure reads and transient body-fetch fixtures.

## M72 - Review UI Pagination and Email Body Dialog

Status: Completed on 2026-06-16.

Purpose: Make the Review screen expose all visible Gmail parse failures and show
one failure's plain-text email body in a dialog.

Instructions:

- Before editing, inspect this plan, M71 completion notes, Review screen
  widgets, repository providers, fake repository hooks, shared modal/dialog
  primitives, and focused Review tests.
- Add Review state for paginated Gmail parse failures with initial load,
  refresh, `Load more`, loading-more, empty, and error/retry states.
- Keep the existing parse-failure row content and `Ignore for now` behavior.
  After ignore, refresh or remove the hidden row without losing already loaded
  visible failures.
- Add a row tap and/or explicit view-email action that fetches the body through
  the repository body-fetch method.
- Show the body in a scrollable dialog with selectable plain text, safe metadata
  context, loading state, error state, retry action, and close action.
- Preserve narrow-layout behavior and make long body text wrap without
  overflowing.
- Do not store body text in providers beyond transient UI state needed for the
  open dialog.
- Do not add parser fixes, Gmail mutation, hosted rollout, iOS, web, or push
  notifications in this milestone.

Expected code shape:

- Review remains the only app surface for Gmail parse-failure triage.
- The body dialog uses existing app modal patterns and keeps the email body
  readable without crowding the existing transaction review queue.
- Fake repository support should model pagination, ignore, and body fetch.

Acceptance criteria:

- Review can load the first page and later pages of Gmail parse failures.
- A user can open a visible failure row and read the plain-text email body.
- Body loading, body fetch failure, retry, and close flows are visible and
  tested.
- Ignoring a row still hides only that row and does not break pagination.
- Existing merchant review and transaction correction flows remain unchanged.

Verification:

```bash
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Ignore for now"
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Reworked the Review Gmail parse-failure surface to load the first page through
  the M71 repository pagination contract, retry initial failures, refresh from
  the header action, load later pages with `Load more`, show loading-more state,
  and expose a load-more error/retry state.
- Added an explicit `View email` row action that opens a scrollable app modal,
  fetches the plain-text body through `fetchGmailParseFailureBody(...)`, shows
  safe metadata plus selectable plain text, and supports loading, error, retry,
  and close flows.
- Kept existing parse-failure row details and `Ignore for now` behavior. Ignored
  rows are removed from the loaded list, and the next offset is adjusted so a
  later `Load more` request does not skip the row that shifted into view.
- Kept body text transient to the open dialog state; no provider, database,
  parser, Gmail mutation, hosted rollout, iOS, web, or push-notification work was
  added in M72.
- Added focused widget coverage for initial load retry, pagination after ignore,
  loading-more state, load-more retry, body dialog loading/success, and body
  dialog error/retry.
- Milestones 18-21 remained deferred by user request, and Milestone 73 was not
  started.
- Verification:
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Ignore for now"`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
- Assumptions made:
  - The Review UI can use the repository default page size of 20 parse failures
    per page.
  - Removing an ignored loaded row and decrementing the next offset is the least
    disruptive way to avoid skipping later rows after the backend hides that
    failure.
  - The email body may be held only in the active dialog's transient widget state
    while the dialog is open.
- Mocks created:
  - Fake repository completer hooks for delayed parse-failure page and body-fetch
    responses in widget tests.
- Mocks used:
  - Existing fake Flutter finance repository, extended to model paginated
    parse-failure loads, ignore side effects, and transient body-fetch
    success/error flows.

## M73 - Parse Failure Review Regression, Docs, and Cleanup

Status: Completed on 2026-06-16.

Purpose: Verify the complete parse-failure review workflow and fold final
behavior back into durable docs.

Instructions:

- Before editing, inspect this plan, M71-M72 completion notes, `README.md`,
  `DATA_MODEL.md`, `INGESTION.md`, `GMAIL_CONNECTOR.md`,
  `PRODUCTION_READINESS.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`, Gmail Edge
  Function tests, Gmail pgTAP tests, and Review widget tests.
- Run the focused local regression path or document any environment limitation.
- Confirm unmatched watched-label mail is still recorded as visible sanitized
  parse failures, with `other` candidate type when no parser can identify a
  more specific type.
- Confirm paginated Review access, body dialog behavior, body privacy, and
  ignore behavior all work together.
- Update durable docs with final behavior and mark this companion plan
  completed-only after M73 is complete.
- Document that historical skipped emails need an explicit backfill/resync for
  the relevant window before they can appear in Review.
- Do not perform hosted Supabase migration push, Edge Function deployment,
  parser expansion, iOS, web, or push notification work unless explicitly
  requested.

Expected code shape:

- This milestone should mostly be verification, cleanup, and documentation.
  Runtime changes should be limited to fixing regressions found during
  verification.

Acceptance criteria:

- Full focused Supabase, Edge Function, and Flutter verification passes locally
  or documents an environment limitation with compensating evidence.
- Durable docs describe paginated parse-failure Review, on-demand plain-text
  body viewing, privacy boundaries, and operational backfill expectations.
- `GMAIL_PARSE_FAILURE_REVIEW.md` is marked completed-only.
- No unrelated deferred work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/gmail_parse_failures.sql
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/production_readiness.sql
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
deno test --allow-env --allow-net supabase/functions/tests/gmail_parse_failure_body.test.ts
deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Ignore for now"
cd apps/mobile && flutter test
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Ran the full local M73 regression path across Supabase pgTAP, schema lint,
  Gmail Edge Function tests, focused Review widget tests, and the full Flutter
  test suite. No runtime regressions were found, so no migration, Dart, Edge
  Function, parser, importer, or SQL test changes were required.
- Confirmed unmatched watched-label mail is still recorded as visible sanitized
  parse failures with candidate type `other` and parser
  `unsupported_labeled_gmail_message` when no supported body template matches.
- Confirmed the completed Review workflow pages through parse failures, opens
  the transient plain-text email body dialog through the authenticated
  row-scoped body-fetch contract, preserves body privacy, and keeps
  `Ignore for now` hiding exactly one row without breaking later pagination.
- Folded final behavior into durable docs and marked this companion plan
  completed-only after completed Milestones 70-73.
- Deferred scope was not started: hosted Supabase migration push, Edge Function
  deployment, parser expansion, Gmail mutation, importer work, iOS, web, push
  notifications, and Milestones 18-21.
- Verification:
  - `supabase db reset --local`
  - `supabase test db --local supabase/tests/gmail_parse_failures.sql`
  - `supabase test db --local supabase/tests/gmail_ingestion.sql`
  - `supabase test db --local supabase/tests/production_readiness.sql`
  - `supabase test db --local supabase/tests`
  - `supabase db lint --local --schema app_private,public --fail-on error`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_parse_failure_body.test.ts`
  - `deno test --allow-env --allow-net supabase/functions/tests/gmail_sync.test.ts`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test test/finance_features_test.dart --name "Gmail parse failures|Review|Ignore for now"`
  - `cd apps/mobile && flutter test`
- Assumptions made:
  - M71-M72 already implemented the intended runtime behavior; M73 only needed
    regression verification and documentation closeout after the checks passed.
  - Historical skipped Gmail messages still need an explicit sync/backfill over
    the relevant date range before they can appear in Review.
  - Hosted rollout remains a separate explicit operation.
- Mocks created:
  - None.
- Mocks used:
  - Existing Gmail API stubs in Edge Function tests and existing fake Flutter
    finance repository hooks for Review parse-failure pagination, body-fetch,
    and ignore coverage.
