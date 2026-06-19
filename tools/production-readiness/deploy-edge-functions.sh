#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"

if [[ -z "$PROJECT_REF" ]]; then
  echo "SUPABASE_PROJECT_REF is required." >&2
  exit 2
fi

supabase functions deploy \
  --project-ref "$PROJECT_REF" \
  gmail-oauth-start \
  gmail-connector-status \
  gmail-disconnect \
  gmail-parse-failure-body \
  expense-qa \
  transaction-metadata-suggest

if supabase functions list --project-ref "$PROJECT_REF" | grep -Eq '[[:space:]]merchant-research[[:space:]]'; then
  supabase functions delete \
    --project-ref "$PROJECT_REF" \
    merchant-research
fi

supabase functions deploy \
  --project-ref "$PROJECT_REF" \
  --no-verify-jwt \
  gmail-oauth-callback \
  gmail-pubsub-webhook \
  gmail-sync \
  gmail-watch-renewal \
  gmail-backfill-check \
  gmail-backfill-range
