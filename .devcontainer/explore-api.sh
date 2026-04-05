#!/usr/bin/env bash

set -euo pipefail

TARGET="${1:-all}"
MODE="${2:-local}"

case "$MODE" in
  local)
    BASE_HOST="localhost"
    ;;
  compose)
    BASE_HOST="host.docker.internal"
    ;;
  *)
    echo "Usage: bash .devcontainer/explore-api.sh <catalog|order|notification|all> [local|compose]"
    exit 1
    ;;
esac

fetch_and_summarize() {
  local label="$1"
  local url="$2"
  local response

  echo "[api-explore] ${label}: ${url}"
  response="$(curl -fsS "$url")"

  printf '%s' "$response" | jq -r '
    if .success != true then
      error("API returned success=false")
    elif (.data | type) != "array" then
      error("API returned non-array data")
    else
      "  count=" + ((.data | length) | tostring) +
      (if (.data | length) > 0 then
        " | first-id=" + ((.data[0].id // "n/a") | tostring)
      else
        " | first-id=n/a"
      end)
    end
  '
}

explore_catalog() {
  fetch_and_summarize "Catalog products" "http://${BASE_HOST}:5001/api/products"
  fetch_and_summarize "Catalog categories" "http://${BASE_HOST}:5001/api/categories"
}

explore_order() {
  fetch_and_summarize "Order list" "http://${BASE_HOST}:5002/api/orders"
}

explore_notification() {
  fetch_and_summarize "Notification list" "http://${BASE_HOST}:5003/api/notifications"
}

case "$TARGET" in
  catalog)
    explore_catalog
    ;;
  order)
    explore_order
    ;;
  notification)
    explore_notification
    ;;
  all)
    explore_catalog
    explore_order
    explore_notification
    ;;
  *)
    echo "Unknown target: $TARGET"
    echo "Supported values: catalog, order, notification, all"
    exit 1
    ;;
esac

echo "[api-explore] Done."
