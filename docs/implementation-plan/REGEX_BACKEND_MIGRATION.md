# Regex Backend Migration Plan

Last updated: 2026-06-19

This document is the implementation plan for moving merchant mapping rule
matching, including regex rules, to the backend as the source of truth. Each
milestone below is a standalone milestone intended to be executed in a separate
Codex thread. Stop after completing and documenting the current milestone; do
not automatically continue to the next milestone.

## Target Behavior

Merchant mapping rules should be evaluated consistently for every ingestion
path. Postgres owns the matching semantics for exact, contains, prefix, suffix,
and regex rules. Gmail ingestion, app metadata corrections, merchant review
corrections, and workbook import should all receive the same winning rule for a
given household and statement merchant.

- Invalid regex rules must not abort ingestion or metadata workflows; they
  should fail to match and remain inspectable as data.
- Exact, prefix, suffix, and contains rules should compare normalized statement
  merchant text against normalized non-regex patterns.
- Regex rules should evaluate the stored regex pattern against normalized
  statement merchant text without normalizing away regex syntax.
- Rule ranking stays deterministic: exact, prefix, suffix, contains, regex,
  then priority, then newest rule.
- The workbook importer should stop implementing its own rule-matching engine
  in JavaScript and should call the backend classification contract instead.
- No user-facing rule editor, regex authoring UI, Gmail parser expansion, AI
  suggestion change, or hosted rollout is included in this sequence.

## Existing Foundation

- `public.merchant_mapping_rules` already supports `match_type` values
  `exact`, `contains`, `prefix`, `suffix`, and `regex`.
- `public.normalize_merchant_name(...)`, `public.merchant_rule_matches(...)`,
  and `public.match_merchant_mapping_rule(...)` provide the current backend
  matching path used by Gmail ingestion and future-import rules.
- `public.apply_merchant_review_correction(...)` and
  `public.apply_transaction_metadata_correction(...)` create exact manual rules
  for the selected normalized statement merchant.
- Gmail transaction insertion paths already call
  `public.match_merchant_mapping_rule(...)` before creating review items.
- `tools/workbook-import/src/workbook-importer.mjs` currently fetches active
  `merchant_mapping_rules`, sorts them, evaluates exact/contains/prefix/suffix
  and regex matching in Node, and annotates transactions before upsert.
- Existing pgTAP coverage for merchant review corrections, transaction metadata
  editing, taxonomy lifecycle, merchant group management, Gmail ingestion, and
  workbook import protects the surrounding rule lifecycle.

## Global Rules For M74-M77

- When a user asks to execute a specific milestone, implement only that
  milestone.
- After the requested milestone is complete, verified, cleaned up, and
  documented, stop and report the result.
- Do not start the next milestone, prepare unrelated code for the next
  milestone, or jump ahead to a later milestone automatically.
- Continue to another milestone only when the user explicitly asks to proceed.
- Keep Milestones 18-21 push notifications deferred unless the user explicitly
  resumes them.
- Use the Supabase skill before Supabase schema/RPC work. Check relevant
  Supabase CLI help before migrations and use
  `supabase migration new <descriptive_name>` for schema changes.
- Keep app-accessible tables household-scoped with RLS. Do not add
  service-role credentials, database URLs, or privileged keys to Flutter.
- Keep raw Gmail bodies, OAuth tokens, parser diagnostics, and source payloads
  out of regex rule contracts.
- Preserve existing transaction deletion tombstone suppression, monthly cap
  semantics, category/label lifecycle behavior, merchant group rename/merge
  behavior, and review correction behavior unless a milestone explicitly calls
  out a narrow adjustment.
- Every milestone completion summary must include:
  - Assumptions made
  - Mocks created
  - Mocks used

## M74 - Regex Backend Migration Planning and Reference Readiness

Status: Completed on 2026-06-19.

Purpose: Create this companion plan and wire M75-M77 into durable planning
docs.

Instructions:

- Create this plan with target behavior, existing foundation, global rules,
  implementation milestones, acceptance criteria, and verification
  expectations.
- Update `README.md`, `DATA_MODEL.md`, `INGESTION.md`, `WORKBOOK_IMPORT.md`,
  `MILESTONES.md`, and `SESSION_HANDOFF.md` so a fresh session can start M75
  from docs alone.
- Preserve M18-M21 push-notification deferral.
- Do not change Flutter, Supabase, importer, Edge Function, hosted rollout,
  iOS, web, or runtime implementation code.

Expected code shape:

- Documentation-only milestone.
- No migration, Dart, SQL test, importer, Edge Function, generated, or runtime
  file changes.

Acceptance criteria:

- `REGEX_BACKEND_MIGRATION.md` describes M74-M77 as serial standalone
  milestones.
- M75 is the next recommended non-deferred implementation milestone.
- The docs state that implementation remains planned only.

Verification:

```bash
rg -n "REGEX_BACKEND_MIGRATION|Milestone 7[4-7]|Regex Backend Migration|classify_statement_merchant|merchant_rule_matches" docs/implementation-plan
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Created the Regex Backend Migration companion plan and routed future
  implementation through M75-M77.
- Confirmed the current migration boundary: Gmail ingestion already uses the
  backend matcher, while workbook import still performs JavaScript-side
  merchant rule matching.
- Confirmed the first implementation milestone should harden backend regex
  matching before the workbook importer adopts the backend contract.
- Implementation remains planned only; M75 was not started.
- Assumptions made:
  - "Regex Backend Migration" means migrating merchant mapping rule evaluation,
    especially regex matching, out of workbook-import JavaScript and into
    Postgres as the shared source of truth.
  - Invalid regex patterns should fail closed by returning no match instead of
    aborting ingestion or app correction flows.
  - No user-facing regex authoring UI is required for this sequence.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M75 - Backend Regex Matcher Guardrails

Status: Completed on 2026-06-19.

Purpose: Make the backend matcher safe and explicit enough to become the
source of truth for every ingestion path.

Instructions:

- Before editing, inspect this plan, `README.md`, `DATA_MODEL.md`,
  `INGESTION.md`, `MILESTONES.md`, `SESSION_HANDOFF.md`, the existing
  `merchant_rule_matches(...)` and `match_merchant_mapping_rule(...)`
  migrations, merchant review correction pgTAP tests, transaction metadata
  editing pgTAP tests, Gmail ingestion pgTAP tests, and workbook importer rule
  tests.
- Use the Supabase skill. Check Supabase changelog/docs for relevant database
  function, regex, RLS, grant, and CLI guidance before schema work.
- Create the migration with
  `supabase migration new regex_backend_matcher_guardrails`.
- Replace or wrap `public.merchant_rule_matches(...)` so:
  - `exact`, `contains`, `prefix`, and `suffix` compare normalized statement
    merchant text with `public.normalize_merchant_name(pattern)`.
  - `regex` evaluates the stored `pattern` against normalized statement
    merchant text without normalizing the regex pattern.
  - Blank normalized inputs and blank effective patterns return `false`.
  - Invalid regex patterns return `false` instead of raising an exception.
  - Unknown `match_type` values return `false`.
- Preserve the current deterministic ranking in
  `public.match_merchant_mapping_rule(...)`: exact, prefix, suffix, contains,
  regex, priority ascending, created_at descending.
- Add a backend detail helper named
  `public.classify_statement_merchant(p_household_id uuid, p_statement_merchant text)`
  returning the winning rule's `rule_id`, `merchant_id`, `merchant_name`,
  `category_id`, `category_name`, `subcategory_id`, `subcategory_name`,
  `confidence`, `rule_notes`, and `rule_created_by`. Return no row when no rule
  matches.
- Keep the helper `stable`, `security invoker`, household-scoped through the
  same RLS-safe tables as the existing matcher, and grant execute only to
  `authenticated` and `service_role`.
- Add pgTAP coverage proving invalid regex does not abort matching, regex rules
  can match normalized statement merchants, non-regex patterns are normalized,
  exact rules outrank regex rules, priority breaks ties inside the same match
  type, and the detail helper returns the expected names and IDs.
- Do not modify the workbook importer, Flutter UI, Gmail parser templates,
  hosted Supabase, iOS, web, push notifications, or any user-facing rule editor
  in this milestone.

Expected code shape:

- Backend matching remains centralized in Postgres functions over
  `merchant_mapping_rules`.
- The new detail helper is a read-only classification contract for admin tools
  and future callers that need display names in addition to IDs.
- Existing correction RPCs continue creating exact manual rules and should not
  need UI or repository contract changes.

Acceptance criteria:

- Invalid regex patterns cannot crash `match_merchant_mapping_rule(...)`,
  Gmail transaction insertion, metadata correction tests, or the new detail
  helper.
- Backend matching semantics cover exact, contains, prefix, suffix, and regex
  with deterministic precedence.
- Existing Gmail and app correction rule behavior remains compatible.
- M76 remains planned and the workbook importer still uses its existing
  implementation until explicitly migrated.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/regex_backend_matcher_guardrails.sql
supabase test db --local supabase/tests/merchant_review_corrections.sql
supabase test db --local supabase/tests/transaction_metadata_editing.sql
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase db lint --local --schema app_private,public --fail-on error
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

Completion summary:

- Added migration `20260619074145_regex_backend_matcher_guardrails.sql` to
  harden `public.merchant_rule_matches(...)` across exact, contains, prefix,
  suffix, and regex matching.
- Invalid regex patterns, unknown match types, blank normalized inputs, and
  blank effective patterns now fail closed by returning no match.
- Added `public.classify_statement_merchant(...)` as a stable,
  `security invoker`, household-scoped read helper returning the winning rule's
  IDs, display names, confidence, notes, and creator.
- Preserved the existing winning-rule ranking in
  `public.match_merchant_mapping_rule(...)`: exact, prefix, suffix, contains,
  regex, priority ascending, created_at descending.
- Added focused pgTAP coverage in
  `supabase/tests/regex_backend_matcher_guardrails.sql` and extended Gmail
  ingestion coverage to prove an invalid regex rule does not block real Gmail
  rule matching.
- Workbook importer migration remains planned for M76 and was not started.
- Flutter UI, Gmail parser templates, hosted Supabase, iOS, web, push
  notifications, and user-facing rule editor work were not changed.
- Assumptions made:
  - Existing non-regex rule patterns may be stored normalized or unnormalized;
    the backend matcher normalizes them at comparison time.
  - Regex rule patterns are authored as PostgreSQL regular expressions and must
    be evaluated as stored against normalized statement merchant text.
  - The detail helper should expose only rule/category/merchant metadata already
    reachable through household-scoped RLS-safe tables.
- Mocks created:
  - None.
- Mocks used:
  - None.

## M76 - Workbook Import Backend Classification

Purpose: Remove JavaScript-side merchant rule matching from the workbook
importer and make workbook imports use the backend classification contract.

Instructions:

- Before editing, inspect this plan, M75 completion notes, `WORKBOOK_IMPORT.md`,
  `INGESTION.md`, workbook importer source and tests, the new
  `public.classify_statement_merchant(...)` helper, tombstone suppression logic,
  workbook validation logic, and importer package scripts.
- Update `tools/workbook-import/src/workbook-importer.mjs` so it no longer
  sorts or evaluates merchant mapping rules in JavaScript for live import
  classification.
- Keep workbook parsing, deterministic source fingerprints, category/merchant
  seeding, source-account seeding, tombstone suppression, transaction upsert,
  review-item creation, and validation totals behavior unchanged.
- After the importer has a household, seeded taxonomy, and seeded merchant data,
  classify each workbook transaction by calling
  `public.classify_statement_merchant(...)` with the transaction statement
  merchant. Use the returned IDs/names/confidence/notes to set the same
  transaction fields currently populated by JavaScript rule matching.
- Preserve behavior when no rule matches: keep workbook-provided merchant,
  category, subcategory, confidence, and null mapping-rule metadata.
- Preserve deterministic import results for the existing 475-row workbook when
  there are no extra future mapping rules.
- Update Node tests so they prove the importer calls the backend classification
  helper, consumes a returned regex-backed rule result correctly, preserves
  no-match behavior, and does not depend on a local JavaScript regex matcher.
- Keep any remaining test-only helpers narrow; they may mock database responses
  but must not reintroduce a production JS rule engine.
- Do not modify backend matcher semantics, Flutter UI, Gmail parser templates,
  hosted Supabase, iOS, web, push notifications, or user-facing rule management
  in this milestone.

Expected code shape:

- Workbook import becomes an admin ingestion client of the same backend rule
  contract used by Gmail ingestion.
- JavaScript keeps orchestration, workbook parsing, validation, and database
  upsert responsibilities, while Postgres owns merchant rule matching.
- Tests should make the backend dependency visible through mocked query calls or
  local database integration, not through duplicated regex logic.

Acceptance criteria:

- Workbook import applies backend regex, exact, prefix, suffix, and contains
  rule outcomes through `public.classify_statement_merchant(...)`.
- Invalid regex handling remains owned by the backend and cannot crash the
  importer through local regex construction.
- Existing workbook fixture validation still passes.
- Tombstoned workbook rows remain suppressed rather than recreated.
- Gmail ingestion and app correction behavior remain unchanged.

Verification:

```bash
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
supabase test db --local supabase/tests/merchant_review_corrections.sql
supabase test db --local supabase/tests/transaction_metadata_editing.sql
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used

## M77 - Regex Backend Migration Regression, Docs, and Cleanup

Purpose: Verify the complete backend-owned regex matching workflow and fold the
final behavior into durable docs.

Instructions:

- Before editing, inspect this plan, M75-M76 completion notes, `README.md`,
  `DATA_MODEL.md`, `INGESTION.md`, `WORKBOOK_IMPORT.md`, `MILESTONES.md`,
  `SESSION_HANDOFF.md`, Supabase rule-matching tests, Gmail ingestion tests,
  and workbook importer tests.
- Run the focused local regression path or document any environment limitation
  with compensating evidence.
- Confirm Postgres owns matching semantics for exact, contains, prefix, suffix,
  and regex rules across Gmail and workbook ingestion.
- Confirm invalid regex patterns fail closed without aborting ingestion,
  metadata correction, or importer validation.
- Confirm manual exact rules created from Review or transaction metadata edits
  still override broader regex rules through deterministic ranking.
- Update durable docs with final behavior and mark this companion plan
  completed-only after M77 completes.
- Do not perform hosted Supabase migration push, Edge Function deployment, iOS,
  web, push notifications, or user-facing regex rule editor work unless
  explicitly requested.

Expected code shape:

- This milestone should mostly be verification, cleanup, and documentation.
  Runtime changes should be limited to fixing regressions found during
  verification.

Acceptance criteria:

- Focused Supabase and workbook importer verification passes locally or
  documents an environment limitation with compensating evidence.
- Durable docs describe backend-owned regex and non-regex merchant mapping rule
  semantics for future ingestion work.
- `REGEX_BACKEND_MIGRATION.md` is marked completed-only.
- No unrelated deferred work is started.

Verification:

```bash
supabase db reset --local
supabase test db --local supabase/tests/merchant_review_corrections.sql
supabase test db --local supabase/tests/transaction_metadata_editing.sql
supabase test db --local supabase/tests/gmail_ingestion.sql
supabase test db --local supabase/tests/category_taxonomy_delete.sql
supabase test db --local supabase/tests/category_taxonomy_merge.sql
supabase test db --local supabase/tests/merchant_group_management.sql
supabase db lint --local --schema app_private,public --fail-on error
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
git diff --check
```

Completion summary requirements:

- Assumptions made
- Mocks created
- Mocks used
