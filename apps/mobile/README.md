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
- `AUTH_REDIRECT_URL`: defaults to `com.olympus.spendlens://login-callback/`

`SUPABASE_ANON_KEY` is also accepted as a compatibility alias.

Example:

```sh
flutter run \
  --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=replace-me \
  --dart-define=AUTH_REDIRECT_URL=com.olympus.spendlens://login-callback/
```

Do not commit real Supabase keys. The anon key is safe for a Flutter client only after RLS policies are in place.

## Android Google Sign-In

The Android callback URL is `com.olympus.spendlens://login-callback/`.

For local Supabase, add the Google provider credentials through environment
variables/config and keep the callback URL in `supabase/config.toml`
`auth.additional_redirect_urls`. For hosted Supabase, add the same URL in Auth
redirect settings and register the Android OAuth client ID on the Google Auth
provider.
