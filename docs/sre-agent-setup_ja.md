# Azure SRE Agent デモ セットアップガイド

このガイドでは、GlobalAzureDemo2026 アプリケーションに Azure SRE Agent を統合し、インシデント検出と Azure DevOps の自動化を設定します。

## 前提条件

- Azure サブスクリプション (所有者または共同作成者ロール)
- Azure CLI (`az`) インストール済み
- GitHub アカウント (GlobalAzureDemo2026 リポジトリへのアクセス)
- Azure DevOps 組織とプロジェクト
- PowerShell 7+ または Bash

### 必要な Azure サービス

- Azure Container Apps (マネージド環境)
- Azure Container Registry
- Azure Cosmos DB
- Azure Application Insights
- Azure Log Analytics Workspace
- Azure Monitor (アラート、アクショングループ)
- Azure DevOps (作業項目管理)

---

## ステップ 1: Azure リソースの準備

### 1.1 環境変数を設定

**Bash/macOS:**
```bash
export RESOURCE_GROUP="rg-globalazdemo-sre"
export ENVIRONMENT_NAME="sre-demo"
export LOCATION="westus3"
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export AZURE_DEVOPS_ORG_URL="https://dev.azure.com/<your-org>"
export AZURE_DEVOPS_PROJECT="SRE-Demo"
```

**PowerShell 7:**
```powershell
$env:RESOURCE_GROUP = "rg-globalazdemo-sre"
$env:ENVIRONMENT_NAME = "sre-demo"
$env:LOCATION = "westus3"
$env:AZURE_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/<your-org>"
$env:AZURE_DEVOPS_PROJECT = "SRE-Demo"
```

### 1.2 リソースグループを作成

```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --subscription $AZURE_SUBSCRIPTION_ID
```

---

## ステップ 2: SRE Agent リソースでデプロイ

インフラストラクチャには SRE リソースの条件付きデプロイが含まれます。SRE パラメータを有効にしてデプロイします。

### 2.1 Bicep パラメータを更新

`infra/main.parameters.json` に以下を追加します:

```json
{
  "enableSreDemo": true,
  "azureDevOpsOrgUrl": "https://dev.azure.com/<your-org>",
  "azureDevOpsProjectName": "SRE-Demo",
  "responseTimeThresholdMs": 500,
  "errorRateThresholdPercent": 5
}
```

### 2.2 インフラをデプロイ

```bash
az login
azd up
```

---

## ステップ 3: GitHub コネクタを設定

SRE Agent はリポジトリへのアクセスと問題作成に GitHub コネクタを使用します。

### 3.1 GitHub PAT を作成

1. [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens?type=beta) に移動
2. **Generate new token** をクリック
3. スコープを設定:
   - `repo` (プライベートリポジトリへのフルアクセス)
   - `read:org` (組織データの読み取り)
4. トークンをコピーして安全に保管

### 3.2 SRE Agent でコネクタを登録

```
Connector Type: GitHub
Name: GlobalAzureDemo-Repo
Repository: tfsugjp/GlobalAzureDemo2026
Authentication: Personal Access Token
Permissions: ログ読み取り、問題作成、プロジェクト履歴読み取り
```

---

## ステップ 4: Azure DevOps 統合を設定

アクショングループがインシデント アラートを Azure DevOps にルーティングします。

### 4.1 Azure DevOps サービス プリンシパルを作成

1. Azure Portal → **Azure Active Directory → App Registrations**
2. **New registration** をクリック
3. 名前: `SRE-Agent-Demo`
4. **Register** をクリック

### 4.2 権限を付与

1. **Azure DevOps Organization → Organization Settings → Users**
2. サービス プリンシパルを **Project Collection Administrator** として追加

### 4.3 クライアント シークレットを作成

1. App Registration → **Certificates & Secrets**
2. **New client secret** をクリック
3. シークレットをコピーして安全に保管

---

## ステップ 5: SRE Agent メモリを設定

SRE Agent のメモリにランブックを追加します。

### 5.1 ランブック テンプレート

**ランブック: 応答時間が高い**
```yaml
トリガー:
  - アラート: Response Time > 500ms for 5 minutes

調査:
  - コンテナアプリの CPU/メモリ使用率を確認
  - Application Insights パフォーマンス カウンターを確認
  - Cosmos DB スループット使用率を確認

解決手順:
  1. CPU > 80% の場合、コンテナアプリをスケール
  2. Cosmos DB インデックスを確認
  3. アプリケーション ログを確認
  4. ネットワーク遅延を確認
```

---

## ステップ 6: セットアップを検証

### 6.1 リソースを確認

```bash
# Log Analytics Workspace
az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# Application Insights
az monitor app-insights component list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# アラート ルール
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# アクション グループ
az monitor action-group list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv
```

---

## ステップ 7: 20 分デモシナリオを実行

詳細は [sre-scenario-20min_ja.md](./sre-scenario-20min_ja.md) を参照してください。

---

## トラブルシューティング

### アラート ルールが発火しない

- メトリクス名を確認
- `az monitor metrics list` で利用可能なメトリクスを確認
- マイクロサービスが OpenTelemetry でメトリクスを出力しているか確認

### Azure DevOps 作業項目が作成されない

- サービス プリンシパルの権限を確認
- アクション グループの Webhook URL を確認
- `curl` または Postman で Webhook をテスト

---

## 次のステップ

1. 20 分デモシナリオを実行
2. しきい値をカスタマイズ
3. Slack/Teams 統合を追加
4. 自動修復を有効化

---

## 参考資料

- [Azure SRE Agent ドキュメント](https://sre.azure.com)
- [Azure SRE Agent - GitHub コネクタ](https://sre.azure.com/docs/concepts/connectors)
- [Azure SRE Agent - メモリと知識ベース](https://learn.microsoft.com/ja-jp/azure/sre-agent/memory)
- [Azure SRE Agent - エージェント推論](https://learn.microsoft.com/ja-jp/azure/sre-agent/agent-reasoning)
- [Azure Monitor アラート](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/alerts-overview)
