# Repository Guidelines

## Project Structure & Module Organization

SpendLens is an Android-first Flutter app backed by Supabase. The mobile app lives in `apps/mobile`; Dart source is under `apps/mobile/lib/src`, grouped by `app`, `core`, `data`, `features`, and `shared/widgets`. Tests live in `apps/mobile/test` and `apps/mobile/integration_test`.

Supabase configuration, migrations, and database tests live in `supabase/`; keep schema changes in `supabase/migrations` and SQL tests in `supabase/tests`. Planning notes are in `docs/implementation-plan`. The workbook importer is a Node tool in `tools/workbook-import`, with source in `src` and tests in `test`.

## Build, Test, and Development Commands

From `apps/mobile`:

```sh
flutter pub get  # install Dart dependencies
flutter analyze  # run Flutter/Dart lints
flutter test     # run widget and unit tests
flutter run      # launch locally
```

From the repository root:

```sh
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
```

Workbook importer and Node tooling should use `pnpm`, not `npm`:

```sh
pnpm --dir tools/workbook-import install --frozen-lockfile
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
```

## Coding Style & Naming Conventions

Dart uses `flutter_lints` via `apps/mobile/analysis_options.yaml`. Format Dart with `dart format`. Use `snake_case.dart` filenames, `PascalCase` widgets/classes, and `camelCase` members and providers. Keep feature UI in `lib/src/features/<feature>` and reusable widgets in `lib/src/shared/widgets`.

SQL should use descriptive migration names, lowercase identifiers, and explicit RLS policies. JavaScript importer files use ESM `.mjs`, two-space indentation, and Node's built-in `node:test`. Prefer `pnpm` for all JavaScript dependency and script commands.

## Testing Guidelines

Add or update Flutter tests beside affected app behavior in `apps/mobile/test`; use `_test.dart` filenames. Put end-to-end coverage in `apps/mobile/integration_test`. For database changes, add SQL tests under `supabase/tests`. For importer changes, add `.test.mjs` files under `tools/workbook-import/test`.

There is no formal coverage threshold yet; include the smallest meaningful regression test for behavioral changes.

## Commit & Pull Request Guidelines

Recent history uses short conventional subjects such as `feat: add workbook import tooling` and `chore: scaffold mobile app foundation`. Prefer `feat:`, `fix:`, `chore:`, or `docs:` with an imperative summary.

Pull requests should include a description, commands run, linked issues or milestone references, and screenshots for visible mobile UI changes. Call out Supabase migrations, RLS changes, and required local configuration.

## Security & Configuration Tips

Do not commit real Supabase URLs, publishable keys, database URLs, or service-role credentials. Use `--dart-define` or local env files based on `apps/mobile/env/*.example`. Privileged database URLs are only for local/admin tooling, not Flutter client code.
