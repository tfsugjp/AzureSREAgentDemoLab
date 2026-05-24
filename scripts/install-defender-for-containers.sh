#!/usr/bin/env bash
# Installs or upgrades the Microsoft Defender for Containers sensor on an AKS cluster via Helm.
#
# Usage:
#   ./install-defender-for-containers.sh <subscription_id> <resource_group> <cluster_name> <location> [--upgrade] [--version <ver>]
#
# Options:
#   --upgrade          Upgrade an existing installation (helm upgrade) instead of fresh install
#   --version <ver>    Chart version to install (default: 0.11.2)
#
# Example:
#   ./install-defender-for-containers.sh \
#     "00000000-0000-0000-0000-000000000000" \
#     "rg-global-azure-demo" \
#     "aks-dev-abc123" \
#     "japaneast"

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <subscription_id> <resource_group> <cluster_name> <location> [--upgrade] [--version <ver>]"
  exit 1
fi

SUBSCRIPTION_ID="$1"
RESOURCE_GROUP="$2"
CLUSTER_NAME="$3"
LOCATION="$4"
shift 4

VERSION="0.11.2"
UPGRADE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upgrade)
      UPGRADE=true
      shift
      ;;
    --version)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Error: --version requires a value." >&2
        exit 1
      fi
      VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

OCI_REGISTRY="oci://mcr.microsoft.com/azuredefender-preview/microsoft-defender-for-containers"
CHART_REF="${OCI_REGISTRY}"
RELEASE_NAME="defender-k8s"
NAMESPACE="mdc"

echo "=== Microsoft Defender for Containers Helm Deployment ==="
echo "Cluster   : ${CLUSTER_NAME}"
echo "Namespace : ${NAMESPACE}"
echo "Version   : ${VERSION}"
echo "Mode      : $([ "$UPGRADE" = true ] && echo 'upgrade' || echo 'install')"
echo ""

echo "Configuring Azure subscription and AKS credentials..."
az account set --subscription "${SUBSCRIPTION_ID}"
az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing

COMMON_ARGS=(
  "--namespace" "${NAMESPACE}"
  "--version" "${VERSION}"
  "--set" "global.cloudIdentifiers.Azure.subscriptionId=${SUBSCRIPTION_ID}"
  "--set" "global.cloudIdentifiers.Azure.resourceGroupName=${RESOURCE_GROUP}"
  "--set" "global.cloudIdentifiers.Azure.clusterName=${CLUSTER_NAME}"
  "--set" "global.cloudIdentifiers.Azure.region=${LOCATION}"
)

if [ "$UPGRADE" = true ]; then
  helm upgrade "${RELEASE_NAME}" "${CHART_REF}" "${COMMON_ARGS[@]}" --reuse-values --server-side=true --force-conflicts
else
  helm install "${RELEASE_NAME}" "${CHART_REF}" --create-namespace "${COMMON_ARGS[@]}"
fi

echo ""
echo "Verifying deployment..."
helm list --namespace "${NAMESPACE}"
kubectl get pods --namespace "${NAMESPACE}"
