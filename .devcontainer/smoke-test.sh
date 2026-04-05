#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-compose}"

case "$MODE" in
  compose)
    BASE_HOST="host.docker.internal"
    ;;
  local)
    BASE_HOST="localhost"
    ;;
  *)
    echo "Usage: bash .devcontainer/smoke-test.sh [compose|local]"
    exit 1
    ;;
esac

check_url() {
  local name="$1"
  local url="$2"
  local attempt

  for attempt in $(seq 1 30); do
    echo "[smoke-test] Checking ${name}: ${url} (attempt ${attempt}/30)"
    if curl -fsSk "$url" >/dev/null 2>&1; then
      return 0
    fi

    sleep 2
  done

  echo "[smoke-test] ${name} did not become ready in time."
  return 1
}

check_api_collection() {
  local name="$1"
  local url="$2"
  local attempt

  for attempt in $(seq 1 30); do
    echo "[smoke-test] Validating ${name}: ${url} (attempt ${attempt}/30)"
    if curl -fsS "$url" | jq -e '
      .success == true and
      (.data | type) == "array" and
      (.data | length) > 0
    ' >/dev/null 2>&1; then
      return 0
    fi

    sleep 2
  done

  echo "[smoke-test] ${name} did not return seeded data in time."
  return 1
}

check_url "Cosmos DB Emulator" "https://${BASE_HOST}:8081/_explorer/emulator.pem"
check_url "CatalogService liveness" "http://${BASE_HOST}:5001/health"
check_url "CatalogService readiness" "http://${BASE_HOST}:5001/health/ready"
check_url "OrderService liveness" "http://${BASE_HOST}:5002/health"
check_url "OrderService readiness" "http://${BASE_HOST}:5002/health/ready"
check_url "NotificationService liveness" "http://${BASE_HOST}:5003/health"
check_url "NotificationService readiness" "http://${BASE_HOST}:5003/health/ready"
check_api_collection "CatalogService products" "http://${BASE_HOST}:5001/api/products"
check_api_collection "OrderService orders" "http://${BASE_HOST}:5002/api/orders"
check_api_collection "NotificationService notifications" "http://${BASE_HOST}:5003/api/notifications"

echo "[smoke-test] All checks passed."
