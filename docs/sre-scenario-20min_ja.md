# Azure SRE Agent 20 分デモシナリオ

このガイドは、Azure SRE Agent がインシデントを検出し、Azure DevOps、GitHub、またはその両方へチケットを作成して解決を提案する**実行可能で時間制限付きのシナリオ**です。

**総所要時間: 20 分**

---

## シナリオの概要

**ストーリー**: Order Service で本番インシデントが検出されました。高レイテンシが Azure Monitor により検出され、Azure DevOps の作業項目、GitHub Issue、またはその両方が自動作成されます。SRE Agent がテレメトリとランブック知識を使用してインシデントを調査し、解決を提案します。

**想定フロー**:
1. インシデント トリガー (トラフィック生成) — **2 分**
2. アラート検出とチケット作成 — **3 分**
3. SRE Agent による調査 — **8 分**
4. 解決と検証 — **7 分**

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
- Application Insights にメトリクスが表示 (1-2 分以内)

## 連携先を選ぶ

| ルート | フェーズ 2 で確認するもの |
|---|---|
| Azure DevOps のみ | Azure DevOps 作業項目 |
| GitHub のみ | GitHub Issue |
| Azure DevOps + GitHub | 両方のチケット |

---

## フェーズ 2: アラート検出とチケット作成 (3 分)

### 2.1 アラート ルール ステータスを確認

```bash
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')]" \
  --output table
```

**期待される出力**:
```
Alert Rule Status: Fired
Last Triggered: <timestamp>
Severity: 2 (警告)
```

### 2.2 連携先のチケットを確認

#### Azure DevOps

1. **Azure DevOps -> SRE-Demo Project -> Boards**
2. 新しい作業項目を確認:
   - タイトル例: `[SRE] High latency detected in Order Service`
   - アラート名、しきい値、現在値、対象サービスが入っていること

#### GitHub

1. **GitHub -> tfsugjp/GlobalAzureDemo2026 -> Issues**
2. 新しい Issue を確認:
   - タイトル例: `[SRE] High latency detected in Order Service`
   - `sre-agent-demo`, `incident`, `azure-monitor` などのラベルが付いていること

#### Azure DevOps + GitHub

同じアラート ID または相関 ID で、両方にチケットが作成されていることを確認します。

**期待される結果**:
- チケットが 1-2 分以内に作成
- 全アラート コンテキストを含む

---

## フェーズ 3: SRE Agent による調査 (8 分)

### 3.1 テレメトリ データのクエリ

SRE Agent は Log Analytics から以下を実行:

**Query 1: パフォーマンス タイムライン**
```kusto
requests
| where timestamp > ago(15m)
| where name contains "orders"
| summarize AvgDuration = avg(duration), 
            P95Duration = percentile(duration, 95)
  by bin(timestamp, 1m)
| render timechart
```

**Query 2: エラー分析**
```kusto
exceptions
| where timestamp > ago(15m)
| summarize Count = count() by exceptionType
| top 10 by Count desc
```

### 3.2 ランブックの参照

SRE Agent が **"応答時間が高い"** ランブックを参照:

```
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
# Order Service 名を取得
ORDER_CA=$(az containerapp list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'order')].name" \
  --output tsv)

# 3 レプリカにスケール
az containerapp update \
  --resource-group $RESOURCE_GROUP \
  --name $ORDER_CA \
  --min-replicas 3 \
  --max-replicas 3
```

### 4.2 解決を検証

```bash
# レスポンス タイムを確認
az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS \
  --analytics-query "
    requests
    | where timestamp > ago(5m) and name contains 'orders'
    | summarize AvgDuration = avg(duration)
  " \
  --resource-group $RESOURCE_GROUP

# 期待値: < 300ms
```

### 4.3 チケットのステータスを更新

#### Azure DevOps

1. 作業項目を開く
2. ステータスを **Done** に変更
3. コメントを追加:
   ```
   解決: Order Service を 3 レプリカにスケール
   結果: レスポンス タイム 750ms -> 200ms
   ```

#### GitHub

1. Issue を開く
2. 同じ内容のコメントを追加
3. Issue を Close する

#### Azure DevOps + GitHub

両方のチケットを更新し、必要なら相互リンクを残します。

---

## デモ完了チェックリスト

✅ **フェーズ 1**: 合成負荷生成成功
✅ **フェーズ 2**: アラート検出とチケット作成確認
✅ **フェーズ 3**: SRE Agent がテレメトリを分析
✅ **フェーズ 4**: Service をスケール、解決を検証

---

## 時間短縮のコツ

- アラート評価期間を短縮 (デフォルト: 5 分 → 2 分)
- Log Analytics クエリを事前に準備
- Azure DevOps プロジェクトまたは GitHub Issue ラベルを事前に準備

---

## トラブルシューティング

### アラートが発火しない
- メトリクス名を確認
- Application Insights でテレメトリを確認

### チケットが作成されない
- Action Group の送信先を確認
- Logic App または Azure Function の実行結果を確認
- Azure DevOps または GitHub の認証を確認

---

## 参考資料

詳細は [sre-agent-setup_ja.md](./sre-agent-setup_ja.md) を参照してください。
