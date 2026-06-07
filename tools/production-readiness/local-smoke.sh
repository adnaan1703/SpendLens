#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'production readiness check failed: %s\n' "$1" >&2
  exit 1
}

tracked_secret_files="$(
  git ls-files |
    grep -E '(^|/)(\.env($|\.)|.*\.env$|key\.properties$|.*\.(jks|keystore|p12|pem|key)$)' |
    grep -Ev '(\.env\.example$|\.env\.template$|key\.properties\.example$)' || true
)"

if [[ -n "$tracked_secret_files" ]]; then
  printf '%s\n' "$tracked_secret_files" >&2
  fail "tracked secret-like files found"
fi

client_secret_refs="$(
  git grep -nE 'SUPABASE_(SERVICE_ROLE|SECRET)_KEY|GOOGLE_OAUTH_CLIENT_SECRET|PUBSUB_VERIFICATION_SECRET|oauth_secret_ref|refresh_token' \
    -- apps/mobile/lib apps/mobile/android || true
)"

if [[ -n "$client_secret_refs" ]]; then
  printf '%s\n' "$client_secret_refs" >&2
  fail "client code references backend secrets"
fi

supabase test db --local supabase/tests/production_readiness.sql
supabase db lint --local --schema app_private,public --fail-on error
supabase db advisors --local --type security --level warn --fail-on none
supabase db advisors --local --type performance --level warn --fail-on none

read -r -d '' SQL <<'SQL' || true
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relrowsecurity
  ) then
    raise exception 'public base table without RLS found';
  end if;

  if exists (
    select 1
    from pg_class c
    join pg_namespace n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'v'
      and c.relname like 'v_%'
      and not coalesce(c.reloptions @> array['security_invoker=true'], false)
  ) then
    raise exception 'public reporting view without security_invoker found';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in (
        'v_ingestion_operational_health',
        'v_parser_operational_health'
      )
      and grantee in ('anon', 'authenticated')
  ) then
    raise exception 'service-only operational health view is exposed to app roles';
  end if;
end
$$;
SQL

supabase db query --local "$SQL" >/dev/null

deno fmt --check supabase/functions
deno lint supabase/functions
deno check supabase/functions/_shared/*.ts supabase/functions/*/index.ts
node --test supabase/functions/tests/gmail_parsers.test.mjs

if [[ "${RUN_MOBILE:-0}" == "1" ]]; then
  (
    cd apps/mobile
    flutter analyze
    flutter test
    rm -f android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
    flutter build apk --release --no-pub \
      --dart-define=APP_ENV=production \
      --dart-define=SUPABASE_URL=https://example.supabase.co \
      --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_example
  )
fi

printf 'production readiness local smoke passed\n'
