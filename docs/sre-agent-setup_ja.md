# Azure SRE Agent デモ セットアップガイド

このガイドでは、GlobalAzureDemo2026 アプリケーションに Azure SRE Agent を統合し、Azure Monitor をインシデント ソースとして、Azure DevOps、GitHub、またはその両方へインシデントを連携する構成を設定します。

## 前提条件

- Azure サブスクリプション (所有者または共同作成者ロール)
- Azure CLI (`az`) インストール済み
- GitHub アカウント (GlobalAzureDemo2026 リポジトリへのアクセス)
- Azure DevOps 組織とプロジェクト (Azure DevOps 連携時)
- GitHub リポジトリの管理権限またはメンテナー権限 (GitHub Issue 連携時)
- PowerShell 7+ または Bash

### 必要な Azure サービス

- Azure Container Apps (マネージド環境)
- Azure Container Registry
- Azure Cosmos DB
- Azure Application Insights
- Azure Log Analytics Workspace
- Azure Monitor (アラート、アクショングループ)
- Logic Apps または Azure Functions (チケット作成用の Azure ネイティブ中継)
- Azure DevOps (任意、作業項目管理)

## サポートする連携パターン

| パターン | 連携先 | 向いているケース |
|---|---|---|
| Azure DevOps のみ | Azure DevOps 作業項目 | 運用チームが Boards 中心で対応する場合 |
| GitHub のみ | GitHub Issues | 開発チームが GitHub 中心で運用する場合 |
| Azure DevOps + GitHub | 作業項目 + GitHub Issue | 運用は Azure DevOps、開発は GitHub で追跡する場合 |

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
export GITHUB_OWNER="<your-github-owner>"
export GITHUB_REPO="GlobalAzureDemo2026"
```

**PowerShell 7:**
```powershell
$env:RESOURCE_GROUP = "rg-globalazdemo-sre"
$env:ENVIRONMENT_NAME = "sre-demo"
$env:LOCATION = "westus3"
$env:AZURE_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/<your-org>"
$env:AZURE_DEVOPS_PROJECT = "SRE-Demo"
$env:GITHUB_OWNER = "<your-github-owner>"
$env:GITHUB_REPO = "GlobalAzureDemo2026"
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

### 2.1 SRE オーバーレイ用の入力値を集める

SRE デモ用オーバーレイを適用する前に、以下を準備します。

- ベース デプロイで使った `environmentName`、`entraTenantId`、`entraClientId`、`entraAudience`
- **Logic App の resource ID** など中継先の Azure リソース ID
- HTTP トリガーの **callback URL**
- レイテンシしきい値と失敗リクエスト数しきい値

### 2.2 インフラをデプロイ

```bash
az deployment group create \
  --name globalazdemo-sre \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters \
    environmentName=$ENVIRONMENT_NAME \
    entraTenantId=<your-tenant-id> \
    entraClientId=<your-client-id> \
    entraAudience=<your-audience> \
    enableSreDemo=true \
    incidentRelayResourceId=<logic-app-resource-id> \
    incidentRelayCallbackUrl=<logic-app-callback-url> \
    responseTimeThresholdMs=500 \
    failedRequestCountThreshold=5
```

すでに `azd up` でベース環境を作成している場合は、同じリソース グループに対してこのオーバーレイ デプロイを後から実行できます。

---

## ステップ 3: GitHub コネクタを設定

SRE Agent は GitHub コネクタを使ってリポジトリ コンテキストを読み取り、GitHub ルートを選ぶ場合は Issue の作成や更新にも利用します。

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
Permissions: リポジトリ読み取り、Issue 作成/更新、履歴参照
```

---

## ステップ 4: Azure DevOps 統合を設定

Azure DevOps 作業項目を使う場合は、この手順も設定します。

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

### 4.4 Azure DevOps コネクタを SRE Agent に登録

Azure DevOps の作業項目を SRE Agent が読む、コメントする、履歴を見る場合は Azure DevOps コネクタも登録します。

```text
Connector Type: Azure DevOps
Organization: https://dev.azure.com/<your-org>
Project: SRE-Demo
Permissions: 作業項目の参照/更新、パイプライン履歴の参照
```

---

## ステップ 5: インシデントのルーティングを設定

Azure Monitor をインシデント ソースとして維持しつつ、Azure DevOps や GitHub にチケットを作成するには、Action Group の先に **Logic Apps** または **Azure Functions** を置く構成を推奨します。これにより、インシデント起点は Azure のままにしながら、GitHub 連携も実現できます。

### 5.1 Azure ネイティブ中継を使う理由

- Azure Monitor Action Group の共通アラート スキーマをそのまま受け取れる
- Azure DevOps と GitHub への認証を中継側で安全に扱える
- 1 つのアラートから Azure DevOps、GitHub、両方へ同じ内容を配信できる
- Portal リンクや KQL リンクを追加してチケットを強化できる

### 5.2 ルート A: Azure DevOps のみ

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> Azure DevOps Work Item
  -> SRE Agent
```

推奨フィールド:

- Title: `[SRE] High latency detected in Order Service`
- Type: Bug または Issue
- Tags: `sre-agent-demo`, `incident`, `azure-monitor`

### 5.3 ルート B: GitHub のみ

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> GitHub Issue
  -> SRE Agent
```

推奨フィールド:

- Title: `[SRE] High latency detected in Order Service`
- Labels: `sre-agent-demo`, `incident`, `azure-monitor`
- Body: アラート要約、影響サービス、しきい値、Portal リンク、KQL リンク

GitHub 認証:

- GitHub App (推奨)
- `repo` スコープ付き PAT (デモ向け)

### 5.4 ルート C: Azure DevOps + GitHub

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> Azure DevOps Work Item
  -> GitHub Issue
  -> SRE Agent
```

役割分担の例:

- **Azure DevOps**: インシデント記録、重大度、対応タイムライン
- **GitHub**: コード修正、PR、開発ディスカッション

### 5.5 フィールド マッピング

| アラート項目 | Azure DevOps | GitHub |
|---|---|---|
| `essentials.alertRule` | タイトル接頭辞、説明 | Issue タイトル、本文 |
| `essentials.severity` | 優先度、重大度 | `sev2` などのラベル |
| `essentials.firedDateTime` | 作成時刻メモ | 本文のタイムライン |
| `alertContext.condition` | 説明欄 | 本文の詳細欄 |
| Resource ID | タグ、カスタム項目 | Markdown 詳細ブロック |

---

## ステップ 6: SRE Agent メモリを設定

SRE Agent のメモリにランブックを追加します。

### 6.1 ランブック テンプレート

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

## ステップ 7: セットアップを検証

### 7.1 リソースを確認

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

### 7.2 接続を検証

1. **GitHub コネクタ**: テストコミットや既存 Issue を SRE Agent から参照できることを確認
2. **Azure DevOps コネクタ**: テスト作業項目を SRE Agent から参照できることを確認
3. **GitHub Issue 連携**: テストアラートから GitHub Issue が作成されることを確認
4. **アラート**: 合成トラフィックで Azure Monitor アラートが発火し、想定した連携先にチケットが作成されることを確認

---

## ステップ 8: 20 分デモシナリオを実行

詳細は [sre-scenario-20min_ja.md](./sre-scenario-20min_ja.md) を参照してください。

---

## トラブルシューティング

### アラート ルールが発火しない

- メトリクス名を確認
- `az monitor metrics list` で利用可能なメトリクスを確認
- マイクロサービスが OpenTelemetry でメトリクスを出力しているか確認

### Azure DevOps 作業項目が作成されない

- サービス プリンシパルの権限を確認
- Logic App または Azure Function の認証を確認
- 中継エンドポイントへサンプル ペイロードを再送して確認

### GitHub Issue が作成されない

- GitHub App または PAT の権限を確認
- リポジトリ所有者名とリポジトリ名を確認
- Logic App または Azure Function のマッピングを確認

---

## 次のステップ

1. 20 分デモシナリオを実行
2. しきい値をカスタマイズ
3. Azure DevOps のみ運用なら GitHub ルートも追加
4. Slack/Teams 統合を追加
5. 自動修復を有効化

---

## 参考資料

- [Azure SRE Agent ドキュメント](https://sre.azure.com)
- [Azure SRE Agent - GitHub コネクタ](https://sre.azure.com/docs/concepts/connectors)
- [Azure SRE Agent - メモリと知識ベース](https://learn.microsoft.com/ja-jp/azure/sre-agent/memory)
- [Azure SRE Agent - エージェント推論](https://learn.microsoft.com/ja-jp/azure/sre-agent/agent-reasoning)
- [Azure Monitor アラート](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/alerts-overview)
