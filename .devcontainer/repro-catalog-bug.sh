#!/usr/bin/env bash

set -euo pipefail

BUG_MODE="${1:-}"
TARGET_MODE="${2:-local}"

if [[ -z "$BUG_MODE" ]]; then
  echo "Usage: bash .devcontainer/repro-catalog-bug.sh <premium-slow|long-query-500> [local|compose]"
  exit 1
fi

case "$TARGET_MODE" in
  local)
    BASE_HOST="localhost"
    ;;
  compose)
    BASE_HOST="host.docker.internal"
    ;;
  *)
    echo "Unknown target mode: $TARGET_MODE"
    echo "Supported values: local, compose"
    exit 1
    ;;
esac

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

case "$BUG_MODE" in
  premium-slow)
    URL="http://${BASE_HOST}:5001/api/products/search?q=premium"
    echo "[repro] Triggering premium slow path: ${URL}"

    CURL_RESULT="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code} %{time_total}' "$URL")"
    HTTP_CODE="${CURL_RESULT%% *}"
    DURATION_SECONDS="${CURL_RESULT##* }"

    if [[ "$HTTP_CODE" != "200" ]]; then
      echo "[repro] Expected HTTP 200 but got ${HTTP_CODE}."
      cat "$RESPONSE_FILE"
      exit 1
    fi

    python3 - "$RESPONSE_FILE" "$DURATION_SECONDS" <<'PY'
import json
import sys

path = sys.argv[1]
duration = float(sys.argv[2])

with open(path, encoding="utf-8") as f:
    payload = json.load(f)

if payload.get("success") is not True:
    raise SystemExit("[repro] premium-slow response was not successful")

items = payload.get("data") or []
print(f"[repro] premium-slow returned {len(items)} item(s) in {duration:.2f}s")

if duration < 1.5:
    print("[repro] Note: response was faster than the expected slow-path symptom threshold.")
PY
    ;;
  long-query-500)
    LONG_QUERY="$(python3 - <<'PY'
print('a' * 150)
PY
)"
    URL="http://${BASE_HOST}:5001/api/products/search?q=${LONG_QUERY}"
    echo "[repro] Triggering long-query 500 path"

    HTTP_CODE="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' "$URL")"

    if [[ "$HTTP_CODE" != "500" ]]; then
      echo "[repro] Expected HTTP 500 but got ${HTTP_CODE}."
      cat "$RESPONSE_FILE"
      exit 1
    fi

    echo "[repro] long-query-500 reproduced successfully (HTTP 500)."
    ;;
  *)
    echo "Unknown bug mode: $BUG_MODE"
    echo "Supported values: premium-slow, long-query-500"
    exit 1
    ;;
esac
