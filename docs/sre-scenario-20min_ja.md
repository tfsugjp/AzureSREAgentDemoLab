# Azure SRE Agent 20 分デモシナリオ

このガイドは、Azure SRE Agent がインシデントを検出し、Azure relay 経由で設定済みの連携先にチケットを作成し、解決を提案する **実行可能で時間制限付きのシナリオ** です。

総所要時間: 20 分

---

## シナリオの概要

**ストーリー**: Order Service で本番インシデントが検出されました。高レイテンシが Azure Monitor により検出され、設定済みの Logic App または Azure Function relay に転送されます。その relay が Azure DevOps の作業項目、GitHub Issue、またはその両方を作成します。SRE Agent がテレメトリとランブック知識を使用してインシデントを調査し、解決を提案します。

**想定フロー**:

1. インシデント トリガー (トラフィック生成) — **2 分**
2. アラート検出とチケット作成 — **3 分**
3. SRE Agent による調査 — **8 分**
4. 解決と検証 — **7 分**

---

## 連携先を選ぶ

どのチケットが作成されるかは、Action Group の先にある relay の実装に依存します。Bicep では Azure Monitor から relay までを接続し、Azure DevOps / GitHub / 両方のどれを作るかは relay 側の設定で決まります。

| ルート | フェーズ 2 で確認するもの |
| --- | --- |
| Azure DevOps のみ | Azure DevOps 作業項目 |
| GitHub のみ | GitHub Issue |
| Azure DevOps + GitHub | 両方のチケット |

---

## フェーズ 1: インシデント トリガー (2 分)

### 1.1 Order Service に合成負荷を生成

```bash
export ORDER_SERVICE_ENDPOINT="https://<your-order-service-endpoint>/api/orders"
export CONCURRENT_REQUESTS=50

bash trigger-incident-demo.sh -e $ORDER_SERVICE_ENDPOINT -c $CONCURRENT_REQUESTS -d 60
```

**期待される結果**:

- Order Service のレスポンス タイムが増加
- Application Insights にメトリクスが表示される (1-2 分以内)

### 1.2 メトリクスが記録されていることを確認

> [!IMPORTANT]
> レイテンシや失敗率などのアプリ テレメトリを確認する KQL は、**Application Insights** または **Log Analytics Workspace** の **Logs** から実行してください。
>
> 個別の **Container App** リソースの **Logs** では、`requests` ではなく、ワークスペース ベースの Application Insights テーブルである `AppRequests`、`AppExceptions`、`AppDependencies` を使います。

#### Application Insights / Log Analytics で使うクエリ

```bash
export RESOURCE_GROUP="<your-resource-group>"
export LOG_ANALYTICS_WS_ID=$(az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].customerId" \
  --output tsv)

az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS_ID \
  --analytics-query "
    AppRequests
    | where TimeGenerated > ago(5m)
    | summarize AvgDurationMs = avg(DurationMs), Count = sum(ItemCount) by Name
    | top 10 by Count desc
  " \
  --resource-group $RESOURCE_GROUP
```

**PowerShell 7:**

```powershell
$resourceGroup = "<your-resource-group>"
$logAnalyticsWsId = az monitor log-analytics workspace list `
  --resource-group $resourceGroup `
  --query "[0].customerId" `
  --output tsv

$query = @"
AppRequests
| where TimeGenerated > ago(5m)
| summarize AvgDurationMs = avg(DurationMs), Count = sum(ItemCount) by Name
| top 10 by Count desc
"@

az monitor log-analytics query `
  --workspace $logAnalyticsWsId `
  --analytics-query $query `
  --resource-group $resourceGroup
```

#### Container App の Logs で使うクエリ

Container App の **Logs** は、アプリ メトリクスではなく **コンテナの stdout/stderr** や **プラットフォーム ログ** を見る場所です。`requests` や `AppRequests` の代わりに、次のテーブルを使います。

- アプリのコンソール出力: `ContainerAppConsoleLogs`
- プラットフォーム / リビジョン ログ: `ContainerAppSystemLogs`

```kusto
ContainerAppConsoleLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ContainerName, Stream, Log
| order by TimeGenerated desc
```

```kusto
ContainerAppSystemLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ReplicaName, Reason, Log
| order by TimeGenerated desc
```

> [!NOTE]
> 一部の環境や古い画面では `ContainerAppConsoleLogs_CL` / `ContainerAppSystemLogs_CL` が表示される場合があります。その場合は、画面に見えている実際のテーブル名と列名 (`ContainerAppName_s`、`RevisionName_s`、`Log_s` など) に読み替えてください。

---

## フェーズ 2: アラート検出とチケット作成 (3 分)

### 2.1 アラート ルール ステータスを確認

```bash
ALERT_RULE_NAME=$(az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')].name | [0]" \
  --output tsv)

az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')]" \
  --output table
```

**期待される出力**:

```text
Alert Rule Status: Fired
Last Triggered: <timestamp>
Severity: 2 (警告)
```

### 2.2 連携先のチケットを確認

どの連携先にチケットが出るかは、今回デモに使う relay の設定内容に従います。

#### Azure DevOps ルート

1. **Azure DevOps -> SRE-Demo Project -> Boards** を開く
2. 新しい作業項目を確認する
3. 次の情報が含まれていることを確認する
   - タイトル例: `[SRE] High latency detected in Order Service`
   - アラート名、しきい値、現在値、対象サービス

#### GitHub ルート

1. **GitHub -> tfsugjp/GlobalAzureDemo2026 -> Issues** を開く
2. 新しい Issue を確認する
3. 次の情報が含まれていることを確認する
   - タイトル例: `[SRE] High latency detected in Order Service`
   - ラベル例: `sre-agent-demo`, `incident`, `azure-monitor`

#### Azure DevOps + GitHub ルート

同じアラート ID または相関 ID で、両方にチケットが作成されていることを確認します。

**期待される結果**:

- チケットが 1-2 分以内に作成される
- 全アラート コンテキストが含まれる

---

## フェーズ 3: SRE Agent による調査 (8 分)

### 3.1 Application Insights / Log Analytics でテレメトリを分析

SRE Agent は Log Analytics から以下のクエリを実行します。

#### Query 1: パフォーマンス タイムライン

```kusto
AppRequests
| where TimeGenerated > ago(15m)
| where Name contains "orders"
| summarize
    AvgDurationMs = avg(DurationMs),
    P95DurationMs = percentile(DurationMs, 95),
    P99DurationMs = percentile(DurationMs, 99),
    FailureRate = 100.0 * countif(Success == false) / count()
  by bin(TimeGenerated, 1m)
| render timechart
```

#### Query 2: エラー分析

```kusto
AppExceptions
| where TimeGenerated > ago(15m)
| summarize Count = sum(ItemCount) by ExceptionType, OuterMessage
| top 10 by Count desc
```

#### Query 3: 依存関係のパフォーマンス

```kusto
AppDependencies
| where TimeGenerated > ago(15m)
| where Target contains "cosmos"
| summarize
    AvgDurationMs = avg(DurationMs),
    FailureRate = 100.0 * countif(Success == false) / count()
  by DependencyType, Target
```

**期待される所見**:

- 高レイテンシがリクエスト量の増加と相関する
- Cosmos DB 依存関係にレイテンシのスパイクが見える可能性がある
- エラー率は多少上がっていても、主因ではない場合がある

### 3.2 Container App Logs で補助情報を確認

Container App の **Logs** では、リクエスト統計ではなく、アプリのログ出力やリビジョンの異常を確認します。

#### Console logs

```kusto
ContainerAppConsoleLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ContainerName, Stream, Log
| order by TimeGenerated desc
```

#### System logs

```kusto
ContainerAppSystemLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ReplicaName, Reason, Log
| order by TimeGenerated desc
```

### 3.3 ランブックの参照

SRE Agent が **「応答時間が高い」** ランブックを参照します。

```text
トリガー: Response Time > 500ms ✅ マッチ

根本原因分析:
  - リクエスト ボリューム: ベースラインから 400% 増加
  - Cosmos DB スループット: 70% 利用中

推奨解決:
  1. Order Service を 3 レプリカにスケール (現在: 1)
  2. 5 分間レスポンス タイムを監視
```

---

## フェーズ 4: 解決と検証 (7 分)

### 4.1 Service をスケール

```bash
ORDER_CA=$(az containerapp list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'order')].name" \
  --output tsv)

az containerapp update \
  --resource-group $RESOURCE_GROUP \
  --name $ORDER_CA \
  --min-replicas 3 \
  --max-replicas 3
```

### 4.2 解決を検証

```bash
LOG_ANALYTICS_WS_ID=$(az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].customerId" \
  --output tsv)

az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS_ID \
  --analytics-query "
    AppRequests
    | where TimeGenerated > ago(5m) and Name contains 'orders'
    | summarize AvgDurationMs = avg(DurationMs), P95DurationMs = percentile(DurationMs, 95)
  " \
  --resource-group $RESOURCE_GROUP
```

期待値: `AvgDurationMs` と `P95DurationMs` が改善していること。

### 4.3 チケットのステータスを更新

#### Azure DevOps 側

1. 作業項目を開く
2. ステータスを **Done** に変更する
3. 次のようなコメントを追加する

   ```text
   解決: Order Service を 3 レプリカにスケール
   結果: レスポンス タイム 750ms -> 200ms
   ```

#### GitHub 側

1. Issue を開く
2. 同じ内容のコメントを追加する
3. Issue を Close する

#### Azure DevOps + GitHub 両方

両方のチケットを更新し、必要なら相互リンクを残します。

---

## デモ完了チェックリスト

- [x] フェーズ 1: 合成負荷生成成功
- [x] フェーズ 2: アラート検出とチケット作成確認
- [x] フェーズ 3: SRE Agent がテレメトリを分析
- [x] フェーズ 4: Service をスケールし、解決を検証

---

## 時間短縮のコツ

- アラート評価期間を短縮する (デフォルト 5 分 → 2 分)
- Log Analytics クエリを事前に準備する
- Azure DevOps プロジェクトまたは GitHub Issue ラベルを事前に準備する

---

## トラブルシューティング

### アラートが発火しない

- メトリクス名を確認する
- Application Insights でテレメトリを確認する

### `requests` が解決できないというクエリ エラーが出る

- **Container App** 単体の **Logs** ではなく、**Application Insights** または **Log Analytics Workspace** の **Logs** から実行する
- `requests` / `exceptions` / `dependencies` ではなく、`AppRequests` / `AppExceptions` / `AppDependencies` を使う
- 列名も `TimeGenerated`、`Name`、`DurationMs`、`Success` などの `App*` テーブルに合わせる

### Container App の Logs では何を見ればよいか分からない

- アプリの出力を見るなら `ContainerAppConsoleLogs` を使う
- リビジョン作成失敗やプラットフォーム イベントを見るなら `ContainerAppSystemLogs` を使う
- テーブル名が `_CL` 付きで見える場合は、画面に表示されているテーブル名をそのまま使う

### チケットが作成されない

- Action Group の送信先を確認する
- Logic App receiver の callback URL が `listCallbackUrl` の結果と一致し、`/triggers/` と `sig=` を含んでいるか確認する
- Logic App または Azure Function の実行結果を確認する
- relay が想定した連携先 (Azure DevOps / GitHub / 両方) を実際に作成する構成になっているか確認する
- Azure DevOps または GitHub の認証を確認する

---

## 参考資料

- [sre-agent-setup_ja.md](./sre-agent-setup_ja.md)
- [Azure Monitor Alerts](https://learn.microsoft.com/ja-jp/azure/azure-monitor/alerts/alerts-overview)
- [Monitor logs in Azure Container Apps with Log Analytics](https://learn.microsoft.com/en-us/azure/container-apps/log-monitoring)
- [AppRequests table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/apprequests)
- [ContainerAppConsoleLogs table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/containerappconsolelogs)
- [ContainerAppSystemLogs table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/containerappsystemlogs)
