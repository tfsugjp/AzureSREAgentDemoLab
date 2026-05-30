#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="/workspaces/AzureSREAgentDemoLab"
COSMOS_URL="https://host.docker.internal:8081/_explorer/emulator.pem"

echo "[devcontainer] Checking Cosmos DB Emulator availability..."

if curl -fsk "$COSMOS_URL" >/dev/null 2>&1; then
  echo "[devcontainer] Cosmos DB Emulator is already reachable."
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[devcontainer] Docker CLI is not available; cannot start Cosmos DB Emulator automatically."
  exit 1
fi

cd "$REPO_ROOT"
echo "[devcontainer] Starting Cosmos DB Emulator with docker compose..."
docker compose up -d cosmosdb

for attempt in $(seq 1 45); do
  if curl -fsk "$COSMOS_URL" >/dev/null 2>&1; then
    echo "[devcontainer] Cosmos DB Emulator is ready."
    exit 0
  fi

  echo "[devcontainer] Waiting for Cosmos DB Emulator... ($attempt/45)"
  sleep 2
done

echo "[devcontainer] Cosmos DB Emulator did not become ready in time."
exit 1
