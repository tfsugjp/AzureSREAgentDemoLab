#!/usr/bin/env bash

set -euo pipefail

echo "[devcontainer] Workspace ready: /workspaces/GlobalAzureDemo2026"

if command -v docker >/dev/null 2>&1; then
  if docker version >/dev/null 2>&1; then
    echo "[devcontainer] Docker CLI is connected."
  else
    echo "[devcontainer] Docker CLI is installed, but the Docker daemon is not reachable from this container yet."
    echo "[devcontainer] Check that the host Docker engine is running and that /var/run/docker.sock is mounted."
  fi
fi

echo "[devcontainer] Tip: use VS Code tasks to start docker-compose or run individual services."
