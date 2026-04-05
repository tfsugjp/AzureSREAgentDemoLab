#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="${1:-}"
RUN_STATE_DIR="/workspaces/GlobalAzureDemo2026/.devcontainer/.run"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Usage: bash .devcontainer/run-service.sh <catalog|order|notification>"
  exit 1
fi

case "$SERVICE_NAME" in
  catalog)
    PROJECT_PATH="src/CatalogService/CatalogService.csproj"
    SERVICE_PORT="5001"
    ;;
  order)
    PROJECT_PATH="src/OrderService/OrderService.csproj"
    SERVICE_PORT="5002"
    ;;
  notification)
    PROJECT_PATH="src/NotificationService/NotificationService.csproj"
    SERVICE_PORT="5003"
    ;;
  *)
    echo "Unknown service: $SERVICE_NAME"
    echo "Supported values: catalog, order, notification"
    exit 1
    ;;
esac

mkdir -p "$RUN_STATE_DIR"
PID_FILE="${RUN_STATE_DIR}/${SERVICE_NAME}.pid"

if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID="$(cat "$PID_FILE")"
  if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" >/dev/null 2>&1; then
    echo "[devcontainer] ${SERVICE_NAME} is already running with PID ${EXISTING_PID}."
    exit 0
  fi

  rm -f "$PID_FILE"
fi

export ASPNETCORE_ENVIRONMENT="Development"
export ASPNETCORE_URLS="http://0.0.0.0:${SERVICE_PORT}"
export CosmosDb__ConnectionString="AccountEndpoint=https://host.docker.internal:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
export CosmosDb__DatabaseName="GlobalAzureDemo"
export CosmosDb__AllowInsecureCertificate="true"
export Authentication__DisableAuth="true"

echo "[devcontainer] Starting ${SERVICE_NAME} on port ${SERVICE_PORT}"
echo "[devcontainer] Cosmos DB endpoint: https://host.docker.internal:8081/"

cleanup() {
  rm -f "$PID_FILE"
}

trap cleanup EXIT

dotnet run --project "$PROJECT_PATH" --no-launch-profile &
CHILD_PID=$!
echo "$CHILD_PID" > "$PID_FILE"

wait "$CHILD_PID"
