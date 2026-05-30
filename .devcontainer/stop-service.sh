#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="${1:-}"
RUN_STATE_DIR="/workspaces/AzureSREAgentDemoLab/.devcontainer/.run"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Usage: bash .devcontainer/stop-service.sh <catalog|order|notification|all>"
  exit 1
fi

stop_one() {
  local service_name="$1"
  local pid_file="${RUN_STATE_DIR}/${service_name}.pid"

  if [[ ! -f "$pid_file" ]]; then
    echo "[devcontainer] ${service_name} is not running (no PID file)."
    return 0
  fi

  local pid
  pid="$(cat "$pid_file")"

  if [[ -z "$pid" ]]; then
    rm -f "$pid_file"
    echo "[devcontainer] ${service_name} PID file was empty; cleaned up."
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "[devcontainer] Stopping ${service_name} (PID ${pid})..."
    kill "$pid"
  else
    echo "[devcontainer] ${service_name} PID ${pid} is not running; cleaning up stale PID file."
  fi

  rm -f "$pid_file"
}

mkdir -p "$RUN_STATE_DIR"

case "$SERVICE_NAME" in
  catalog|order|notification)
    stop_one "$SERVICE_NAME"
    ;;
  all)
    stop_one catalog
    stop_one order
    stop_one notification
    ;;
  *)
    echo "Unknown service: $SERVICE_NAME"
    echo "Supported values: catalog, order, notification, all"
    exit 1
    ;;
esac
