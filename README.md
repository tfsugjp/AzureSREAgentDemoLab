# Global Azure 2026 Demo - SRE Training Microservices

Azure SRE Agent および Azure Copilot Observability Agent の検証・教材用マイクロサービスアプリケーション。

## アーキテクチャ

```mermaid
graph TB
    Client[Client / Browser] --> Ingress[NGINX Ingress Controller]
    
    subgraph AKS[Azure Kubernetes Service]
        Ingress --> CS[Catalog Service<br/>:5001]
        Ingress --> OS[Order Service<br/>:5002]
        Ingress --> NS[Notification Service<br/>:5003]
    end
    
    CS --> CosmosDB[(Azure Cosmos DB)]
    OS --> CosmosDB
    NS --> CosmosDB
    
    CS --> OTEL[OpenTelemetry Collector]
    OS --> OTEL
    NS --> OTEL
    
    subgraph Auth[Microsoft Entra ID]
        EntraID[JWT Bearer Auth]
    end
    
    CS -.-> EntraID
    OS -.-> EntraID
    NS -.-> EntraID
```

## サービス構成

| サービス | ポート | エンドポイント数 | 説明 |
|---------|-------|----------------|------|
| CatalogService | 5001 | 10 | 商品カタログ、カテゴリ、在庫管理 |
| OrderService | 5002 | 8 | 注文管理、ステータス追跡 |
| NotificationService | 5003 | 6 | 通知配信、既読管理 |

## 技術スタック

- **Runtime**: .NET 10
- **Framework**: ASP.NET Core Minimal APIs
- **認証**: Microsoft Entra ID (JWT ベアラー認証)
- **データストア**: Azure Cosmos DB (NoSQL API)
- **テレメトリ**: OpenTelemetry (トレース + メトリクス + ログ)
- **ログ**: Serilog (構造化ログ)
- **コンテナ**: Docker (マルチステージビルド)
- **オーケストレーション**: Kubernetes (AKS)

## API エンドポイント一覧

### CatalogService (`/api/products`, `/api/categories`, `/api/inventory`)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/products` | 商品一覧取得 |
| GET | `/api/products/{id}` | 商品詳細取得 |
| POST | `/api/products` | 商品登録 |
| PUT | `/api/products/{id}` | 商品更新 |
| DELETE | `/api/products/{id}` | 商品削除 |
| GET | `/api/products/search?q={query}` | 商品検索 ⚠️ |
| GET | `/api/categories` | カテゴリ一覧 |
| GET | `/api/categories/{id}` | カテゴリ詳細 |
| GET | `/api/inventory/{productId}` | 在庫確認 |
| PUT | `/api/inventory/{productId}` | 在庫更新 |

### OrderService (`/api/orders`)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/orders` | 注文一覧 |
| GET | `/api/orders/{id}` | 注文詳細 |
| POST | `/api/orders` | 注文作成 |
| PUT | `/api/orders/{id}/status` | 注文ステータス更新 |
| DELETE | `/api/orders/{id}` | 注文削除 |
| GET | `/api/orders/user/{userId}` | ユーザー別注文 |
| POST | `/api/orders/{id}/cancel` | 注文キャンセル |
| GET | `/api/orders/{id}/total` | 注文合計計算 |

### NotificationService (`/api/notifications`)

| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/notifications` | 通知一覧 |
| GET | `/api/notifications/{id}` | 通知詳細 |
| POST | `/api/notifications` | 通知作成 |
| PUT | `/api/notifications/{id}/read` | 既読マーク |
| GET | `/api/notifications/user/{userId}` | ユーザー別通知 |
| DELETE | `/api/notifications/{id}` | 通知削除 |

## ヘルスチェック エンドポイント

各サービスは、Kubernetes の Liveness / Readiness プローブに対応した一貫したヘルスチェック エンドポイントを公開しています。

### `GET /health` — Liveness プローブ

プロセスが生存しているかどうかのみを確認します。依存関係はチェックしません。

```json
{
  "status": "Healthy",
  "checks": []
}
```

### `GET /health/ready` — Readiness プローブ

以下の条件がすべて満たされた場合のみ `Healthy` を返します。

| チェック | 説明 |
|---|---|
| `cosmosdb` | `CosmosClient.ReadAccountAsync()` が成功すること |
| `startup` | Cosmos DB 初期化とシード投入が完了していること |

```json
{
  "status": "Healthy",
  "checks": [
    { "name": "cosmosdb", "status": "Healthy", "description": "Cosmos DB is reachable.", "duration": 42.3 },
    { "name": "startup", "status": "Healthy", "description": "Startup initialization complete.", "duration": 0.1 }
  ]
}
```

## ローカル開発

### 前提条件

- .NET 10 SDK
- Docker Desktop
- (オプション) Azure Cosmos DB Emulator

### docker-compose で起動

```bash
docker compose up --build
```

サービスは以下のポートでアクセスできます:
- CatalogService: http://localhost:5001
- OrderService: http://localhost:5002
- NotificationService: http://localhost:5003
- Cosmos DB Emulator: https://localhost:8081

開発モードでは認証がスキップされます (`Authentication:DisableAuth=true`)。

> **注意**: docker-compose 環境では `CosmosDb:AllowInsecureCertificate=true` が設定されています。
> これにより、Linux Cosmos DB エミュレーターの自己署名証明書を信頼し、Gateway モードで接続します。
> **本番環境では絶対に使用しないでください。**

### 個別サービスの起動

```bash
dotnet run --project src/CatalogService
dotnet run --project src/OrderService
dotnet run --project src/NotificationService
```

### ビルド

```bash
dotnet build GlobalAzureDemo2026.slnx
```

## AKS デプロイ

### 1. Azure リソースの準備

```bash
az group create --name rg-global-azure-demo --location japaneast

az aks create \
  --resource-group rg-global-azure-demo \
  --name aks-global-azure-demo \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys

az cosmosdb create \
  --resource-group rg-global-azure-demo \
  --name cosmos-global-azure-demo \
  --capabilities EnableServerless \
  --locations regionName=japaneast

az acr create \
  --resource-group rg-global-azure-demo \
  --name acrglobalazuredemo \
  --sku Basic
```

### 2. Entra ID アプリ登録

```bash
az ad app create --display-name "GlobalAzureDemo2026-API"
```

### 3. コンテナイメージのビルドとプッシュ

```bash
az acr login --name acrglobalazuredemo

docker build -t acrglobalazuredemo.azurecr.io/catalog-service:latest -f src/CatalogService/Dockerfile .
docker build -t acrglobalazuredemo.azurecr.io/order-service:latest -f src/OrderService/Dockerfile .
docker build -t acrglobalazuredemo.azurecr.io/notification-service:latest -f src/NotificationService/Dockerfile .

docker push acrglobalazuredemo.azurecr.io/catalog-service:latest
docker push acrglobalazuredemo.azurecr.io/order-service:latest
docker push acrglobalazuredemo.azurecr.io/notification-service:latest
```

### 4. Kubernetes デプロイ

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/catalog-service.yaml
kubectl apply -f k8s/order-service.yaml
kubectl apply -f k8s/notification-service.yaml
kubectl apply -f k8s/ingress.yaml
```

## ⚠️ 意図的なバグ (SRE トレーニング用)

このアプリケーションには **教材目的** で1か所だけ意図的なパフォーマンス問題が埋め込まれています。

### 場所

`src/CatalogService/Services/ProductSearchService.cs` の `SearchAsync` メソッド

### トリガー条件

1. **スローダウン**: クエリパラメータ `q` に `premium` を含めてリクエスト
   ```bash
   curl http://localhost:5001/api/products/search?q=premium
   ```
   - 原因: `Thread.Sleep(100)` を含む同期ループで全商品を逐次処理
   - 結果: レスポンスタイムが数秒に膨張、スレッドプール枯渇

2. **500エラー**: クエリパラメータ `q` に100文字を超える文字列を送信
   ```bash
   curl "http://localhost:5001/api/products/search?q=$(python3 -c 'print("a"*150)')"
   ```
   - 原因: `String.Substring` の境界チェック不備
   - 結果: `ArgumentOutOfRangeException` → HTTP 500

## サンプルデータ

各サービス起動時に Cosmos DB へ自動投入:

| データ | 件数 | 説明 |
|--------|------|------|
| 商品 | 20 | 電子機器、衣料品、食品、書籍、プレミアム |
| カテゴリ | 5 | Electronics, Clothing, Food, Books, Premium |
| 在庫 | 20 | 各商品に対応 |
| 注文 | 10 | 様々なステータス |
| 通知 | 15 | 注文確認、出荷通知、プロモーション等 |

## ライセンス

MIT License
