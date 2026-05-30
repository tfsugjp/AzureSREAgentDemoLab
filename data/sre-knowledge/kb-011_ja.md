---
id: kb-011
title: "システムアーキテクチャ概要"
category: architecture
service: all
severity: low
tags: [architecture, overview, microservices, infrastructure]
lastUpdated: 2026-04-01T00:00:00Z
---

# システムアーキテクチャ概要

## AzureSREAgentDemoLab アーキテクチャ

### サービス構成
本システムは 3 つのマイクロサービスで構成される:

1. **CatalogService** (ポート 5001)
   - 商品カタログ管理 (CRUD)
   - カテゴリ管理
   - 在庫管理
   - 商品検索
   - Cosmos DB コンテナ: categories, products, inventory

2. **OrderService** (ポート 5002)
   - 注文管理
   - 注文ステータス追跡
   - 注文キャンセル
   - Cosmos DB コンテナ: orders

3. **NotificationService** (ポート 5003)
   - 通知配信
   - 既読/未読管理
   - Cosmos DB コンテナ: notifications

### 共通コンポーネント (SharedLibrary)
- Microsoft Entra ID JWT 認証
- Cosmos DB 接続管理
- OpenTelemetry 計装 (トレース、メトリクス、ログ)
- Serilog 構造化ログ
- 共通モデル定義

### インフラストラクチャ
- **コンピュート**: Azure Container Apps (または AKS + AGC)
- **データベース**: Azure Cosmos DB (NoSQL API, Serverless)
- **認証**: Microsoft Entra ID
- **監視**: Application Insights + Log Analytics Workspace
- **コンテナレジストリ**: Azure Container Registry
- **IaC**: Bicep (infra/main.bicep)
- **デプロイ**: Azure Developer CLI (azd)
