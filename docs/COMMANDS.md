# SpendLens Command Reference

This document lists the day-to-day commands for testing, deploying, building,
and running SpendLens. Run commands from the repository root unless a section
says otherwise.

Do not put real Supabase secret keys, Google OAuth secrets, Gemini keys,
keystore files, or database URLs into committed files. Use ignored local env
files or your shell environment.

## Tooling Checks

Use these when setting up a machine or diagnosing command failures.

```sh
flutter --version
dart --version
supabase --version
supabase --help
pnpm --version
deno --version
node --version
```

- `flutter --version` and `dart --version` confirm the mobile SDK toolchain.
- `supabase --version` confirms the installed Supabase CLI.
- `supabase --help` shows the current CLI command groups.
- `pnpm --version` confirms the package manager used by the workbook importer.
- `deno --version` confirms the Edge Function test/runtime tooling.
- `node --version` confirms the Node runtime used by parser and importer tests.

For Supabase CLI details, prefer local help before changing a command:

```sh
supabase db --help
supabase db push --help
supabase functions --help
supabase functions deploy --help
supabase secrets set --help
```

## Local Supabase

```sh
supabase start
```

Starts the local Supabase stack with Postgres, Auth, REST, Studio, Storage, Edge
Runtime, and companion services.

```sh
supabase status
supabase status -o env
```

Shows local service URLs and keys. The `-o env` form is useful when translating
local values into Flutter `--dart-define` values.

```sh
supabase db start
```

Starts only the local database service when the full stack is not needed.

```sh
supabase db reset --local
```

Recreates the local database from `supabase/migrations`. This is the cleanest
local migration verification path. If this exits non-zero after migrations
finish because a non-database local service is unhealthy, verify with the test,
lint, and advisor commands below before assuming the schema failed.

```sh
supabase migration new <descriptive_name>
```

Creates a correctly timestamped migration file. Use this instead of inventing a
filename manually.

```sh
supabase migration list --local
```

Lists local migration state.

```sh
supabase test db --local supabase/tests
supabase test db --local supabase/tests/<test_file>.sql
```

Runs all pgTAP database tests, or one focused test file.

```sh
supabase db lint --local --schema app_private,public --fail-on error
```

Runs database schema linting for the app schemas and fails on lint errors.

```sh
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
```

Runs Supabase security and performance advisors locally. These report warnings
without failing the command.

```sh
supabase db query --local "select now();"
```

Runs an ad hoc SQL query against the local database. Use this for small checks,
not as a substitute for migrations.

```sh
supabase stop
supabase stop --no-backup
```

Stops the local stack. `--no-backup` removes local data volumes, so use it only
when you intentionally want a clean local state.

## Edge Functions

```sh
supabase functions serve --env-file supabase/functions/env/staging.env
```

Serves all Edge Functions locally with values from an ignored env file. Use an
env file copied from `supabase/functions/env/*.env.example`.

```sh
supabase secrets set --project-ref "$SUPABASE_PROJECT_REF" NAME=value
supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  --env-file supabase/functions/env/staging.env
```

Sets hosted Edge Function secrets. Prefer `--env-file` with ignored local env
files when more than one secret is needed.

```sh
deno fmt --check supabase/functions
deno lint supabase/functions
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
deno test supabase/functions/tests/*.ts
node --test supabase/functions/tests/gmail_parsers.test.mjs
```

- `deno fmt --check` verifies formatting for Deno/TypeScript function code.
- `deno lint` runs Deno lints.
- `deno check` type-checks shared modules and function entrypoints.
- `deno test` runs TypeScript function tests.
- `node --test` runs the Gmail parser tests that use Node ESM fixtures.

```sh
SUPABASE_PROJECT_REF=<project-ref> tools/production-readiness/deploy-edge-functions.sh
```

Deploys the current hosted Edge Function set. The script deploys authenticated
functions, deploys webhook/service functions with `--no-verify-jwt`, and deletes
the retired `merchant-research` function if it still exists remotely.

```sh
supabase functions deploy \
  --project-ref "$SUPABASE_PROJECT_REF" \
  transaction-metadata-suggest

supabase functions deploy \
  --project-ref "$SUPABASE_PROJECT_REF" \
  --no-verify-jwt \
  gmail-sync
```

Deploys individual functions when a focused function-only change does not need
the full deployment script. Use `--no-verify-jwt` only for the service/webhook
functions that are intentionally protected by their own secret checks.

## Flutter App

Run these from `apps/mobile`.

```sh
flutter pub get
```

Fetches Dart and Flutter dependencies from `pubspec.yaml`.

```sh
flutter devices
flutter emulators
flutter emulators --launch <emulator-id>
```

Lists available devices, lists configured emulators, and launches one emulator.

```sh
flutter clean
```

Removes generated build outputs. Use this when stale generated files or plugin
registrants interfere with a build.

```sh
dart format --set-exit-if-changed lib test integration_test
```

Checks Dart formatting for app, widget test, and integration test code.

```sh
flutter analyze
```

Runs Flutter and Dart static analysis using `analysis_options.yaml`.

```sh
flutter test
flutter test test/finance_features_test.dart
flutter test test/finance_features_test.dart --name "merchant|metadata|Activity|review|narrow"
```

Runs all Flutter tests, one focused test file, or a focused name-pattern subset.

```sh
flutter test integration_test
```

Runs Flutter integration tests. Requires an emulator or device when the test
needs one.

```sh
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<local-publishable-or-anon-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

Runs the app against local Supabase. Read local URL and key values from
`supabase status -o env`.

```sh
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL=https://bslsitzdvrdosubbdxpd.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<staging-publishable-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

Runs the app against a hosted staging project. Use only publishable client keys,
never service or secret keys.

```sh
flutter run -d <device-id> \
  --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<local-publishable-or-anon-key>
```

Runs the app on a specific device or emulator from `flutter devices`.

```sh
flutter build apk --debug
```

Builds a debug Android APK.

```sh
flutter install -d <device-id>
```

Installs the most recently built APK on a connected device.

```sh
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter build apk --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<production-project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production-publishable-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

Builds a release APK. The `rm` removes an ignored generated registrant that can
be left behind by integration-test runs.

```sh
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<production-project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production-publishable-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

Builds the production Android App Bundle for Play Console or internal testing.
Release signing uses `apps/mobile/android/key.properties` when present and
falls back to debug signing for local smoke builds.

## Workbook Importer

```sh
pnpm --dir tools/workbook-import install --frozen-lockfile
```

Installs importer dependencies exactly as locked.

```sh
pnpm --dir tools/workbook-import test
```

Runs importer unit and fixture tests.

```sh
pnpm --dir tools/workbook-import run validate
```

Runs the workbook importer in dry-run validation mode.

```sh
pnpm --dir tools/workbook-import run import
```

Imports the workbook into the configured database. For a non-local target, set
`SPENDLENS_DB_URL` in your shell or pass the tool's `--db-url` option. Confirm
the target project first and keep privileged database URLs out of Git.

## Readiness Scripts

```sh
supabase db reset --local
tools/production-readiness/local-smoke.sh
```

Runs the local production-readiness gate after a clean local database reset. The
script checks for tracked secret-like files, client-side secret references,
database production-readiness tests, lint, advisors, SQL security assertions,
Edge Function formatting/lint/type-check/tests, and Gmail parser tests.

```sh
supabase db reset --local
RUN_MOBILE=1 tools/production-readiness/local-smoke.sh
```

Runs the same gate plus mobile analyze, mobile tests, and a release APK build
using placeholder production Dart defines.

## Hosted Supabase Deployment

Use this sequence for staging or production. Do not run it against production
until the project ref and release window are confirmed.

```sh
export SUPABASE_PROJECT_REF=bslsitzdvrdosubbdxpd
```

Sets the target hosted project for the commands below to the confirmed shared
dev/staging Supabase project. Use a different value only when intentionally
deploying to another staging or production project.

```sh
supabase login
supabase link --project-ref "$SUPABASE_PROJECT_REF"
```

Authenticates the CLI and links this checkout to the hosted project.

```sh
supabase migration list --linked
supabase db push --linked --dry-run
```

Shows remote migration state and prints the migrations that would be applied
without changing the remote database.

```sh
supabase db push --linked
```

Applies pending migrations to the linked hosted database.

```sh
supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  --env-file supabase/functions/env/staging.env
```

Uploads Edge Function secrets from an ignored env file. Use
`production.env` for production. Do not commit real env files.

```sh
SUPABASE_PROJECT_REF="$SUPABASE_PROJECT_REF" \
  tools/production-readiness/deploy-edge-functions.sh
```

Deploys hosted Edge Functions for the target project.

```sh
supabase db advisors --linked --type security --level warn --fail-on none
supabase db advisors --linked --type performance --level warn --fail-on none
supabase db lint --linked --schema app_private,public --fail-on error
supabase functions list --project-ref "$SUPABASE_PROJECT_REF"
```

Runs hosted post-deploy checks and lists deployed functions.

## Command Execution Sequences

### Flutter-only change

```sh
cd apps/mobile
flutter pub get
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<local-publishable-or-anon-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

### Database migration change

```sh
supabase start
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
```

### Edge Function change

```sh
supabase start
supabase db reset --local
deno fmt --check supabase/functions
deno lint supabase/functions
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
deno test supabase/functions/tests/*.ts
node --test supabase/functions/tests/gmail_parsers.test.mjs
supabase functions serve --env-file supabase/functions/env/staging.env
```

### Workbook importer change

```sh
supabase start
supabase db reset --local
pnpm --dir tools/workbook-import install --frozen-lockfile
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
```

### Full local pre-deploy gate

```sh
supabase start
supabase db reset --local
supabase test db --local supabase/tests
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none
pnpm --dir tools/workbook-import install --frozen-lockfile
pnpm --dir tools/workbook-import test
pnpm --dir tools/workbook-import run validate
tools/production-readiness/local-smoke.sh
(cd apps/mobile && flutter pub get && flutter analyze && flutter test)
git diff --check
```

### Hosted staging deploy

```sh
export SUPABASE_PROJECT_REF=bslsitzdvrdosubbdxpd
supabase login
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase migration list --linked
supabase db push --linked --dry-run
supabase db push --linked
supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  --env-file supabase/functions/env/staging.env
SUPABASE_PROJECT_REF="$SUPABASE_PROJECT_REF" \
  tools/production-readiness/deploy-edge-functions.sh
supabase db advisors --linked --type security --level warn --fail-on none
supabase db advisors --linked --type performance --level warn --fail-on none
supabase db lint --linked --schema app_private,public --fail-on error
supabase functions list --project-ref "$SUPABASE_PROJECT_REF"
```

### Production Android build

```sh
cd apps/mobile
flutter pub get
flutter analyze
flutter test
rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://<production-project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<production-publishable-key> \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```
