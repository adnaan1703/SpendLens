# SpendLens

SpendLens is an Android-first Flutter app for personal and household expense intelligence. The implementation plan lives in `docs/implementation-plan` and should be read before starting a new milestone.

## Current App

- Flutter app: `apps/mobile`
- Android package: `com.olympus.spendlens`
- Display name: `SpendLens`
- Backend plan: Supabase Auth, Postgres, RLS, and Edge Functions
- CI: deferred for now

## Current UI

- The UI redesign through Milestone 51 is complete for the Flutter Android app.
- Primary authenticated navigation is Dashboard, Activity, Review, and Vaults.
- Activity consolidates the former Transactions and Trends surfaces into List and
  Charts modes while preserving existing filters, detail panels, metadata edits,
  label edits, reports, and CSV copy behavior.
- Piggy-bank behavior is still backed by the existing repository/model names, but
  the visible destination and user-facing copy now say Vaults.
- Settings is a focused non-tab page opened from the global settings action; it
  hides primary navigation while active.
- Theme mode supports System default, Light, and Dark, defaults to System, and
  persists locally on device.
- Deferred scope remains separate: Milestones 18-21 push notifications, iOS,
  web, hosted rollout, and later/future milestones are not part of the completed
  UI redesign closeout.

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

For the full command catalog, including Supabase CLI testing/deployment,
workbook importer checks, local smoke gates, and Android build sequences, see
`docs/COMMANDS.md`.

Production readiness checks and deployment runbooks live in:

- `docs/implementation-plan/PRODUCTION_READINESS.md`
- `tools/production-readiness/local-smoke.sh`

## Planning References

- `docs/implementation-plan/README.md`
- `docs/implementation-plan/MILESTONES.md`
- `docs/implementation-plan/SESSION_HANDOFF.md`
