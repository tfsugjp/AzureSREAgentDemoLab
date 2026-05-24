#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <acr_name>"
  echo "Example: $0 your-acr-name"
  exit 1
fi

ACR_NAME="$1"
NAMESPACE="global-azure-demo"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/k8s"

TMPDIR_WORK="$(mktemp -d 2>/dev/null || mktemp -d -t aks-acr-render)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

MANIFESTS=(
  "catalog-service.yaml"
  "order-service.yaml"
  "notification-service.yaml"
)

for manifest in "${MANIFESTS[@]}"; do
  sed "s|<ACR_NAME>|${ACR_NAME}|g" "$MANIFEST_DIR/$manifest" > "$TMPDIR_WORK/$manifest"
done

kubectl apply -f "$MANIFEST_DIR/namespace.yaml"

for manifest in "${MANIFESTS[@]}"; do
  kubectl apply -f "$TMPDIR_WORK/$manifest"
done

kubectl -n "$NAMESPACE" rollout status deployment/catalog-service --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/order-service --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/notification-service --timeout=300s

kubectl -n "$NAMESPACE" get deploy
kubectl -n "$NAMESPACE" get pods -o wide
