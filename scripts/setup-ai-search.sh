#!/bin/bash
# GlobalAzureDemo2026 - AI Search インデックス作成 & ナレッジデータ投入スクリプト
# azd の postprovision フックから呼び出される

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INDEX_NAME="sre-knowledge"
SCHEMA_FILE="$REPO_ROOT/data/ai-search/index-schema.json"
DATA_FILE="$REPO_ROOT/data/ai-search/knowledge-data.json"

# azd が設定する環境変数から AI Search の情報を取得
SEARCH_NAME="${AI_SEARCH_NAME:?AI_SEARCH_NAME environment variable is required}"
SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"

echo "=========================================="
echo " AI Search ナレッジデータ投入"
echo "=========================================="
echo ""
echo "Search Service: $SEARCH_NAME"
echo "Endpoint:       $SEARCH_ENDPOINT"
echo "Index:          $INDEX_NAME"
echo ""

# 管理キーを Azure CLI で取得
echo "[1/3] AI Search 管理キーを取得中..."
ADMIN_KEY=$(az search admin-key show \
  --service-name "$SEARCH_NAME" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "primaryKey" -o tsv)

if [ -z "$ADMIN_KEY" ]; then
  echo "  ✗ 管理キーの取得に失敗しました"
  exit 1
fi
echo "  ✓ 管理キー取得完了"
echo ""

# インデックスを作成 (既存の場合は削除して再作成)
echo "[2/3] インデックスを作成中..."

# 既存インデックスの削除 (存在する場合)
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X DELETE \
  "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
  -H "api-key: $ADMIN_KEY" \
  -H "Content-Type: application/json")

if [ "$HTTP_STATUS" = "204" ] || [ "$HTTP_STATUS" = "404" ]; then
  echo "  ✓ 既存インデックスをクリーンアップ"
fi

# インデックス作成
HTTP_STATUS=$(curl -s -o /tmp/aisearch-index-response.json -w "%{http_code}" \
  -X PUT \
  "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
  -H "api-key: $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d @"$SCHEMA_FILE")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
  echo "  ✓ インデックス '$INDEX_NAME' を作成しました"
else
  echo "  ✗ インデックス作成に失敗しました (HTTP $HTTP_STATUS)"
  cat /tmp/aisearch-index-response.json
  exit 1
fi
echo ""

# ドキュメントをアップロード
echo "[3/3] ナレッジデータを投入中..."

HTTP_STATUS=$(curl -s -o /tmp/aisearch-upload-response.json -w "%{http_code}" \
  -X POST \
  "$SEARCH_ENDPOINT/indexes/$INDEX_NAME/docs/index?api-version=2024-07-01" \
  -H "api-key: $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d @"$DATA_FILE")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✓ ナレッジデータの投入が完了しました"
else
  echo "  ✗ データ投入に失敗しました (HTTP $HTTP_STATUS)"
  cat /tmp/aisearch-upload-response.json
  exit 1
fi

echo ""
echo "=========================================="
echo " 完了"
echo "=========================================="
echo ""
echo "AI Search エンドポイント: $SEARCH_ENDPOINT"
echo "インデックス名:          $INDEX_NAME"
echo ""
echo "検索テスト例:"
echo "  curl '$SEARCH_ENDPOINT/indexes/$INDEX_NAME/docs/search?api-version=2024-07-01' \\"
echo "    -H 'api-key: <QUERY_KEY>' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"search\": \"premium 検索 遅延\"}'"
