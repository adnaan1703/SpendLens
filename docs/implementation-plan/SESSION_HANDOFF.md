# Session Handoff

Use this file to coordinate work across multiple implementation sessions. Update it whenever a milestone starts, completes, or materially changes.

## Current Status

- Current milestone: Not started.
- Last completed milestone: Documentation planning only.
- Current implementation state: No app/backend code exists yet. Repository contains the source workbook and implementation plan docs.
- Next recommended milestone: Milestone 1, Project Foundation.

## Required Reading for New Threads

At the start of a new implementation thread, read:

1. `docs/implementation-plan/README.md`
2. `docs/implementation-plan/ARCHITECTURE.md`
3. `docs/implementation-plan/DATA_MODEL.md`
4. `docs/implementation-plan/INGESTION.md`
5. The target milestone section in `docs/implementation-plan/MILESTONES.md`
6. This handoff file

## Current Assumptions

- Flutter will be used for web, Android, and iOS.
- Supabase is the v1 backend platform.
- Architecture is serverless-first, not backend-less.
- Gmail ingestion starts with Gmail API watch plus Pub/Sub.
- Monthly category caps are the first budget model.
- Piggy banks are manual ledgers.
- Merchant corrections apply to past and future matching transactions.
- Raw email bodies are not retained by default.
- LLM features are future milestones and must be backend-mediated.

## External Setup Timeline

Do not ask the user to perform all setup at once. Ask only when the relevant milestone begins.

- Milestone 2: Supabase development project.
- Milestone 4: Supabase Google Auth configuration.
- Milestone 9: Google Cloud project, Gmail API, Pub/Sub, OAuth consent, OAuth clients.
- Milestone 10: Anonymized UPI email samples.
- Milestone 11: Production Supabase project, web hosting, mobile store accounts if release is needed.
- Milestone 12: LLM provider account, API key, and monthly AI budget cap.

## Milestone Status

- Milestone 1, Project Foundation: pending.
- Milestone 2, Supabase Schema, RLS, and Local Backend: pending.
- Milestone 3, Workbook Import and Historical Seed Data: pending.
- Milestone 4, App Shell, Authentication, and Household Context: pending.
- Milestone 5, Expense Dashboard, Transactions, and Monthly Caps: pending.
- Milestone 6, Merchant Mapping and Review Workflow: pending.
- Milestone 7, Piggy Banks: pending.
- Milestone 8, Trends and Reports: pending.
- Milestone 9, Gmail Connector and Credit-Card Email Ingestion: pending.
- Milestone 10, UPI Ingestion and Parser Expansion: pending.
- Milestone 11, Deployment, Security, and Production Readiness: pending.
- Milestone 12, AI-Ready Layer and LLM Features: pending.

## Update Rules

When a milestone starts:

- Set `Current milestone`.
- Note any external setup requested from the user.
- Link to relevant implementation files once they exist.

When a milestone completes:

- Update `Last completed milestone`.
- Mark the milestone status as completed.
- Note tests/checks run.
- Note any known gaps or deferred items.

When an architecture decision changes:

- Update `ARCHITECTURE.md` or `DATA_MODEL.md`.
- Add a short note here explaining why the change was made.

