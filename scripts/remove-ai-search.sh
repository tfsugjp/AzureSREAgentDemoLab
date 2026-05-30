#!/usr/bin/env bash
# Decommissions any Azure AI Search service in a resource group.
#
# The SRE Agent no longer uses Azure AI Search. This script removes previously
# deployed Microsoft.Search/searchServices resources. It is idempotent: when no
# search service exists, it exits successfully without making changes.
#
# Usage:
#   ./remove-ai-search.sh <resource_group> [--subscription <subscription_id>] [--yes]
#
# Options:
#   --subscription <id>   Target subscription. Defaults to the current az context.
#   --yes                 Delete without interactive confirmation.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <resource_group> [--subscription <subscription_id>] [--yes]" >&2
  exit 1
fi

RESOURCE_GROUP="$1"
shift

SUBSCRIPTION_ID=""
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Error: --subscription requires a value." >&2
        exit 1
      fi
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --yes|-y)
      ASSUME_YES=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v az >/dev/null 2>&1; then
  echo "Error: Azure CLI (az) not found. Install: https://learn.microsoft.com/cli/azure/install-azure-cli" >&2
  exit 1
fi

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi

echo "=== Azure AI Search decommission ==="
echo "Resource group : $RESOURCE_GROUP"
echo ""

if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "Resource group '$RESOURCE_GROUP' not found. Nothing to do."
  exit 0
fi

SEARCH_SERVICES=()
while IFS= read -r line; do
  [[ -n "$line" ]] && SEARCH_SERVICES+=("$line")
done < <(az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --resource-type "Microsoft.Search/searchServices" \
  --query "[].name" -o tsv)

if [[ ${#SEARCH_SERVICES[@]} -eq 0 ]]; then
  echo "No Azure AI Search service found in '$RESOURCE_GROUP'. Nothing to do."
  exit 0
fi

echo "Found ${#SEARCH_SERVICES[@]} AI Search service(s):"
for name in "${SEARCH_SERVICES[@]}"; do
  echo "  - $name"
done
echo ""

if [[ "$ASSUME_YES" != true ]]; then
  read -r -p "Delete the listed AI Search service(s)? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted. No resources were deleted."
    exit 0
  fi
fi

for name in "${SEARCH_SERVICES[@]}"; do
  echo "Deleting '$name'..."
  az resource delete \
    --resource-group "$RESOURCE_GROUP" \
    --resource-type "Microsoft.Search/searchServices" \
    --name "$name"
  echo "  Deleted '$name'."
done

echo ""
echo "AI Search decommission complete."
