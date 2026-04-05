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
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:?AZURE_RESOURCE_GROUP environment variable is required}"
SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"

# 一時ファイルを mktemp で作成し、終了時に自動削除
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT
RESPONSE_FILE="$TMPDIR_WORK/response.json"

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
  --resource-group "$RESOURCE_GROUP" \
  --query "primaryKey" -o tsv)

if [ -z "$ADMIN_KEY" ]; then
  echo "  ✗ 管理キーの取得に失敗しました"
  exit 1
fi
echo "  ✓ 管理キー取得完了"
echo ""

# インデックスを作成 (既存インデックスは保持し、RESET_AI_SEARCH=true の場合のみ削除して再作成)
echo "[2/3] インデックスを確認中..."

RESET_AI_SEARCH="${RESET_AI_SEARCH:-false}"
HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X GET \
  "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
  -H "api-key: $ADMIN_KEY" \
  -H "Content-Type: application/json")

if [ "$HTTP_STATUS" = "200" ]; then
  if [ "$RESET_AI_SEARCH" = "true" ]; then
    echo "  ! RESET_AI_SEARCH=true のため既存インデックスを削除して再作成します"
    HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" \
      -X DELETE \
      "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
      -H "api-key: $ADMIN_KEY" \
      -H "Content-Type: application/json")

    if [ "$HTTP_STATUS" = "204" ]; then
      echo "  ✓ 既存インデックスをクリーンアップ"
    else
      echo "  ✗ 既存インデックスの削除に失敗しました (HTTP $HTTP_STATUS)"
      exit 1
    fi
  else
    echo "  ✓ インデックス '$INDEX_NAME' は既に存在するため、削除/再作成をスキップします"
    echo "    再作成する場合は RESET_AI_SEARCH=true を指定してください"
  fi
elif [ "$HTTP_STATUS" = "404" ]; then
  echo "  ✓ インデックス '$INDEX_NAME' は未作成のため新規作成します"
else
  echo "  ✗ インデックス存在確認に失敗しました (HTTP $HTTP_STATUS)"
  exit 1
fi

if [ "$HTTP_STATUS" = "404" ] || [ "$RESET_AI_SEARCH" = "true" ]; then
  echo "[2/3] インデックスを作成中..."
  HTTP_STATUS=$(curl -sS -o "$RESPONSE_FILE" -w "%{http_code}" \
    -X PUT \
    "$SEARCH_ENDPOINT/indexes/$INDEX_NAME?api-version=2024-07-01" \
    -H "api-key: $ADMIN_KEY" \
    -H "Content-Type: application/json" \
    -d @"$SCHEMA_FILE")

  if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
    echo "  ✓ インデックス '$INDEX_NAME' を作成しました"
  else
    echo "  ✗ インデックス作成に失敗しました (HTTP $HTTP_STATUS)"
    cat "$RESPONSE_FILE"
    exit 1
  fi
fi
echo ""

# ドキュメントをアップロード
echo "[3/3] ナレッジデータを投入中..."

HTTP_STATUS=$(curl -sS -o "$RESPONSE_FILE" -w "%{http_code}" \
  -X POST \
  "$SEARCH_ENDPOINT/indexes/$INDEX_NAME/docs/index?api-version=2024-07-01" \
  -H "api-key: $ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d @"$DATA_FILE")

if [ "$HTTP_STATUS" = "200" ]; then
  # 個別ドキュメントの失敗チェック
  FAILED_COUNT=$(jq '[.value[] | select(.status == false)] | length' "$RESPONSE_FILE" 2>/dev/null || echo "0")
  if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "  ✗ $FAILED_COUNT 件のドキュメント投入に失敗しました"
    jq '.value[] | select(.status == false)' "$RESPONSE_FILE"
    exit 1
  fi
  echo "  ✓ ナレッジデータの投入が完了しました"
else
  echo "  ✗ データ投入に失敗しました (HTTP $HTTP_STATUS)"
  cat "$RESPONSE_FILE"
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
