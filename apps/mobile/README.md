# SpendLens Mobile

Android-first Flutter app for SpendLens.

## Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Runtime Defines

`lib/src/core/config/app_config.dart` reads:

- `APP_ENV`: `local`, `staging`, or `production`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

`SUPABASE_ANON_KEY` is also accepted as a compatibility alias.

Example:

```sh
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=replace-me
```

Do not commit real Supabase keys. The anon key is safe for a Flutter client only after RLS policies are in place.
