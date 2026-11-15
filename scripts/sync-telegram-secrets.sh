#!/usr/bin/env bash
# Copy TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from the local gitignored
# file into Edge Function secrets for the TIFFANI project.
# Does not print secret values and does not touch ORDER_NOTIFY_WORKER_SECRET.
set -euo pipefail

PROJECT_REF="mnjxcoyvomgbdtwdhejq"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/supabase/.env.telegram.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing supabase/.env.telegram.local" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be nonempty" >&2
  exit 1
fi

if [[ ! "$TELEGRAM_BOT_TOKEN" =~ ^[0-9]{6,12}:[A-Za-z0-9_-]{30,}$ ]]; then
  echo "TELEGRAM_BOT_TOKEN has an unexpected format" >&2
  exit 1
fi

if [[ ! "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]{1,20}$ ]]; then
  echo "TELEGRAM_CHAT_ID has an unexpected format" >&2
  exit 1
fi

umask 077
tmp="$(mktemp)"
cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT
printf 'TELEGRAM_BOT_TOKEN=%s\nTELEGRAM_CHAT_ID=%s\n' \
  "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_CHAT_ID" >"$tmp"

set +e
cli_out="$(supabase secrets set --env-file "$tmp" --project-ref "$PROJECT_REF" --yes 2>&1)"
cli_status=$?
set -e

cli_out="${cli_out//$TELEGRAM_BOT_TOKEN/[REDACTED]}"
cli_out="${cli_out//$TELEGRAM_CHAT_ID/[REDACTED]}"

if [[ "$cli_status" -ne 0 ]]; then
  echo "supabase secrets set failed" >&2
  printf '%s\n' "$cli_out" >&2
  exit "$cli_status"
fi

echo "synchronized TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID project=${PROJECT_REF}"
