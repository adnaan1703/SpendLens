# SpendLens Supabase

This folder is reserved for the Supabase backend foundation.

## Planned Structure

- `migrations`: schema, RLS, views, indexes, and seed migrations
- `functions`: Edge Functions for privileged operations
- `seeds`: local seed data and import fixtures
- `tests`: database tests for RLS and financial summary views

The Supabase CLI is not required for Milestone 1. A development project and local configuration are requested in Milestone 2.

## Production Readiness

Milestone 11 production deployment, secrets, monitoring, and smoke-test steps are
documented in `docs/implementation-plan/PRODUCTION_READINESS.md`.

Run the local readiness gate from the repository root after `supabase db reset --local`:

```sh
tools/production-readiness/local-smoke.sh
```
