#!/usr/bin/env bash
# Uninstalls the Microsoft Defender for Containers sensor from an AKS cluster.
#
# This removes a previously installed Defender sensor Helm release and its
# namespace. It is idempotent: when the release or namespace is absent it
# completes without error.
#
# Usage:
#   ./uninstall-defender-for-containers.sh <subscription_id> <resource_group> <cluster_name>
#
# Example:
#   ./uninstall-defender-for-containers.sh \
#     "00000000-0000-0000-0000-000000000000" \
#     "rg-azure-sre-agent-demo-lab" \
#     "aks-dev-abc123"

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <subscription_id> <resource_group> <cluster_name>" >&2
  exit 1
fi

SUBSCRIPTION_ID="$1"
RESOURCE_GROUP="$2"
CLUSTER_NAME="$3"

RELEASE_NAME="defender-k8s"
NAMESPACE="mdc"

command -v az >/dev/null 2>&1 || { echo "Error: Azure CLI (az) not found." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Error: helm not found." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found." >&2; exit 1; }

echo "=== Microsoft Defender for Containers uninstall ==="
echo "Cluster   : ${CLUSTER_NAME}"
echo "Namespace : ${NAMESPACE}"
echo ""

echo "Configuring Azure subscription and AKS credentials..."
az account set --subscription "${SUBSCRIPTION_ID}"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing

if helm status "${RELEASE_NAME}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Uninstalling Helm release '${RELEASE_NAME}'..."
  helm uninstall "${RELEASE_NAME}" --namespace "${NAMESPACE}"
else
  echo "Helm release '${RELEASE_NAME}' not found in namespace '${NAMESPACE}'. Skipping."
fi

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Deleting namespace '${NAMESPACE}'..."
  kubectl delete namespace "${NAMESPACE}" --wait=false
else
  echo "Namespace '${NAMESPACE}' not found. Skipping."
fi

echo ""
echo "Defender for Containers uninstall complete."
