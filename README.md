# SpendLens

SpendLens is an Android-first Flutter app for personal and household expense intelligence. The implementation plan lives in `docs/implementation-plan` and should be read before starting a new milestone.

## Current App

- Flutter app: `apps/mobile`
- Android package: `com.olympus.spendlens`
- Display name: `SpendLens`
- Backend plan: Supabase Auth, Postgres, RLS, and Edge Functions
- CI: deferred for now

## Local Development

Run the mobile app from `apps/mobile`:

```sh
flutter pub get
flutter run
```

The app can start without Supabase credentials during Milestone 1. Real Supabase values are introduced in Milestone 2 and should be passed through `--dart-define` or local env files that are not committed.

Useful checks:

```sh
flutter analyze
flutter test
```

Production readiness checks and deployment runbooks live in:

- `docs/implementation-plan/PRODUCTION_READINESS.md`
- `tools/production-readiness/local-smoke.sh`

## Planning References

- `docs/implementation-plan/README.md`
- `docs/implementation-plan/MILESTONES.md`
- `docs/implementation-plan/SESSION_HANDOFF.md`
