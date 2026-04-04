# GlobalAzureDemo2026

Azure SRE Agent と Azure Copilot 観測可能性デモ用リポジトリです。

## サービス構成

| サービス | 役割 |
|---|---|
| **CatalogService** | 商品カタログを管理する API |
| **OrderService** | 注文処理を管理する API |
| **NotificationService** | 通知配信を管理する API |

## ヘルスチェック エンドポイント

各サービスは、Kubernetes の Liveness / Readiness プローブに対応した一貫したヘルスチェック エンドポイントを公開しています。

### `GET /health` — Liveness プローブ

プロセスが生存しているかどうかのみを確認します。依存関係はチェックしません。

```
HTTP 200 Healthy
```

```json
{
  "status": "Healthy",
  "checks": []
}
```

### `GET /health/ready` — Readiness プローブ

**以下の条件がすべて満たされた場合のみ** `200 Healthy` を返します。

| チェック | 説明 |
|---|---|
| `cosmosdb` | `CosmosClient.ReadAccountAsync()` が成功すること |
| `startup` | バックグラウンドの初期化処理 (シーディング等) が完了していること |

**正常時 (200)**

```json
{
  "status": "Healthy",
  "checks": [
    { "name": "cosmosdb", "status": "Healthy", "description": "Cosmos DB is reachable.", "duration": 42.3 },
    { "name": "startup",  "status": "Healthy", "description": "Startup initialization complete.", "duration": 0.1 }
  ]
}
```

**Cosmos DB 障害時 (503)**

```json
{
  "status": "Unhealthy",
  "checks": [
    { "name": "cosmosdb", "status": "Unhealthy", "description": "Cosmos DB is unreachable.", "duration": 5000.0 },
    { "name": "startup",  "status": "Healthy",   "description": "Startup initialization complete.", "duration": 0.1 }
  ]
}
```

**起動初期化中 (503)**

```json
{
  "status": "Unhealthy",
  "checks": [
    { "name": "cosmosdb", "status": "Healthy",   "description": "Cosmos DB is reachable.", "duration": 35.2 },
    { "name": "startup",  "status": "Unhealthy", "description": "Startup initialization is still in progress.", "duration": 0.0 }
  ]
}
```

## 設定

各サービスの `appsettings.json` または環境変数で Cosmos DB 接続文字列を設定してください。

```json
{
  "CosmosDb": {
    "ConnectionString": "<your-cosmos-db-connection-string>"
  }
}
```

環境変数で上書きする場合:

```bash
export CosmosDb__ConnectionString="AccountEndpoint=https://...;AccountKey=..."
```

## Kubernetes Probe 設定例

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
  failureThreshold: 3
```

## ビルドと実行

```bash
# ビルド
dotnet build GlobalAzureDemo2026.slnx

# 個別サービスの実行
dotnet run --project src/CatalogService
dotnet run --project src/OrderService
dotnet run --project src/NotificationService
```

