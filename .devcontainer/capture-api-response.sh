#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-local}"
CAPTURE_ROOT="/workspaces/GlobalAzureDemo2026/.devcontainer/.captures"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

case "$MODE" in
  local)
    BASE_HOST="localhost"
    ;;
  compose)
    BASE_HOST="host.docker.internal"
    ;;
  *)
    echo "Usage: bash .devcontainer/capture-api-response.sh [local|compose]"
    exit 1
    ;;
esac

TARGET_DIR="${CAPTURE_ROOT}/${MODE}/${TIMESTAMP}"
mkdir -p "$TARGET_DIR"

fetch_to_file() {
  local label="$1"
  local url="$2"
  local file_name="$3"
  local target_file="${TARGET_DIR}/${file_name}"
  local raw

  echo "[capture] ${label}: ${url}"
  raw="$(curl -fsS "$url")"

  if printf '%s' "$raw" | jq . >/dev/null 2>&1; then
    printf '%s' "$raw" | jq . > "$target_file"
  else
    printf '%s\n' "$raw" > "$target_file"
  fi
}

cat > "${TARGET_DIR}/README.txt" <<EOF
Capture timestamp (UTC): ${TIMESTAMP}
Mode: ${MODE}
Base host: ${BASE_HOST}
EOF

fetch_to_file "Catalog health" "http://${BASE_HOST}:5001/health" "catalog-health.json"
fetch_to_file "Catalog readiness" "http://${BASE_HOST}:5001/health/ready" "catalog-ready.json"
fetch_to_file "Catalog products" "http://${BASE_HOST}:5001/api/products" "catalog-products.json"
fetch_to_file "Catalog categories" "http://${BASE_HOST}:5001/api/categories" "catalog-categories.json"
fetch_to_file "Order health" "http://${BASE_HOST}:5002/health" "order-health.json"
fetch_to_file "Order readiness" "http://${BASE_HOST}:5002/health/ready" "order-ready.json"
fetch_to_file "Orders" "http://${BASE_HOST}:5002/api/orders" "orders.json"
fetch_to_file "Notification health" "http://${BASE_HOST}:5003/health" "notification-health.json"
fetch_to_file "Notification readiness" "http://${BASE_HOST}:5003/health/ready" "notification-ready.json"
fetch_to_file "Notifications" "http://${BASE_HOST}:5003/api/notifications" "notifications.json"

echo "[capture] Saved API responses to ${TARGET_DIR}"
