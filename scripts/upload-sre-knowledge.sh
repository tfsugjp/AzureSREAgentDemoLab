#!/usr/bin/env bash
# Uploads the Markdown SRE knowledge base to an Azure SRE Agent.
#
# The SRE Agent stores operational knowledge in its agent memory. This script
# uploads the Markdown runbooks under data/sre-knowledge/ to the agent's memory
# via the data plane API (POST /api/v1/agentmemory/upload).
#
# Docs: https://learn.microsoft.com/en-us/azure/sre-agent/api-reference
#       https://learn.microsoft.com/en-us/azure/sre-agent/upload-knowledge-document
#
# Usage:
#   ./upload-sre-knowledge.sh -g <resource_group> -n <agent_name> \
#       [--subscription <id>] [--language en|ja|all]
#
# Options:
#   -g, --resource-group <name>   Resource group containing the SRE Agent (required)
#   -n, --agent-name <name>       SRE Agent resource name (required)
#       --subscription <id>       Subscription ID. Defaults to current az context.
#       --language <en|ja|all>    Which knowledge files to upload (default: en)
#                                   en  -> kb-*.md  (English, excludes *_ja.md)
#                                   ja  -> kb-*_ja.md (Japanese)
#                                   all -> both

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KNOWLEDGE_DIR="$REPO_ROOT/data/sre-knowledge"
API_VERSION="2025-05-01-preview"
DATA_PLANE_AUDIENCE="https://azuresre.dev"

RESOURCE_GROUP=""
AGENT_NAME=""
SUBSCRIPTION_ID=""
LANGUAGE="en"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="${2:?}"; shift 2 ;;
    -n|--agent-name) AGENT_NAME="${2:?}"; shift 2 ;;
    --subscription) SUBSCRIPTION_ID="${2:?}"; shift 2 ;;
    --language) LANGUAGE="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$AGENT_NAME" ]]; then
  echo "Error: --resource-group and --agent-name are required." >&2
  echo "Run: $0 --help" >&2
  exit 1
fi

case "$LANGUAGE" in en|ja|all) ;; *) echo "Error: --language must be en, ja, or all." >&2; exit 1 ;; esac

command -v az >/dev/null 2>&1 || { echo "Error: Azure CLI (az) not found." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl not found." >&2; exit 1; }

[[ -n "$SUBSCRIPTION_ID" ]] && az account set --subscription "$SUBSCRIPTION_ID"

# Collect files according to the requested language.
shopt -s nullglob
FILES=()
case "$LANGUAGE" in
  en)  for f in "$KNOWLEDGE_DIR"/kb-*.md; do [[ "$f" == *_ja.md ]] || FILES+=("$f"); done ;;
  ja)  for f in "$KNOWLEDGE_DIR"/kb-*_ja.md; do FILES+=("$f"); done ;;
  all) for f in "$KNOWLEDGE_DIR"/kb-*.md; do FILES+=("$f"); done ;;
esac
shopt -u nullglob

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Error: no knowledge files found in $KNOWLEDGE_DIR (language=$LANGUAGE)." >&2
  exit 1
fi

echo "=========================================="
echo " SRE Agent knowledge upload"
echo "=========================================="
echo "Resource group : $RESOURCE_GROUP"
echo "Agent          : $AGENT_NAME"
echo "Language       : $LANGUAGE"
echo "Files          : ${#FILES[@]}"
echo ""

SUB="${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
ARM_URL="https://management.azure.com/subscriptions/${SUB}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.App/agents/${AGENT_NAME}?api-version=${API_VERSION}"

echo "[1/3] Resolving agent data plane endpoint..."
ENDPOINT=$(az rest -m GET --url "$ARM_URL" --query properties.agentEndpoint -o tsv)
if [[ -z "$ENDPOINT" || "$ENDPOINT" == "null" ]]; then
  echo "  Failed to resolve agentEndpoint for '$AGENT_NAME'." >&2
  exit 1
fi
echo "  Endpoint: $ENDPOINT"

echo "[2/3] Acquiring data plane token..."
TOKEN=$(az account get-access-token --resource "$DATA_PLANE_AUDIENCE" --query accessToken -o tsv)
[[ -n "$TOKEN" ]] || { echo "  Failed to acquire data plane token." >&2; exit 1; }

echo "[3/3] Uploading ${#FILES[@]} document(s)..."
FAILED=0
for f in "${FILES[@]}"; do
  name=$(basename "$f")
  http_status=$(curl -sS -o /dev/null -w "%{http_code}" \
    -X POST "${ENDPOINT}/api/v1/agentmemory/upload" \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${f};type=text/markdown")
  if [[ "$http_status" == "200" || "$http_status" == "201" || "$http_status" == "202" ]]; then
    echo "  ✓ $name (HTTP $http_status)"
  else
    echo "  ✗ $name (HTTP $http_status)"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
if [[ "$FAILED" -gt 0 ]]; then
  echo "Completed with $FAILED failure(s)." >&2
  exit 1
fi

echo "Upload complete. Check indexing status with:"
echo "  curl -H \"Authorization: Bearer \$TOKEN\" ${ENDPOINT}/api/v1/agentmemory/indexer-status"
