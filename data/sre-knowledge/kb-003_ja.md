---
id: kb-003
title: "Cosmos DB 接続エラーのトラブルシューティング"
category: troubleshooting
service: all
severity: critical
tags: [cosmos-db, connection, database, infrastructure]
lastUpdated: 2026-04-01T00:00:00Z
---

# Cosmos DB 接続エラーのトラブルシューティング

## 症状
各マイクロサービス (CatalogService, OrderService, NotificationService) の起動時またはリクエスト処理時に Cosmos DB への接続エラーが発生する。エラーメッセージに Microsoft.Azure.Cosmos.CosmosException が含まれる。

## 考えられる原因
1. Cosmos DB アカウントの接続文字列が正しく設定されていない
2. ネットワーク接続の問題 (ファイアウォール、VNet 設定)
3. Cosmos DB アカウントが存在しない、または削除されている
4. Serverless 容量モードで RU 制限に達している
5. Cosmos DB のデータベースまたはコンテナが未作成

## 確認手順
1. 環境変数 CosmosDb__ConnectionString が正しいか確認
2. Azure Portal で Cosmos DB アカウントのステータスを確認
3. ネットワーク設定でパブリックアクセスが有効か確認
4. データベース 'GlobalAzureDemo' と各コンテナ (categories, products, inventory, orders, notifications) の存在を確認

## 対処方法
- 接続文字列の修正: azd env set CosmosDb__ConnectionString '<正しい接続文字列>'
- コンテナが存在しない場合: 各サービスの StartupInitializationService がコンテナを自動作成するため、サービスを再起動
- RU 制限: Cosmos DB のメトリクスで 429 エラーを確認し、必要に応じて容量を増加

## 関連設定
- Bicep: infra/main.bicep の cosmosAccount リソース
- アプリ設定: CosmosDb__ConnectionString, CosmosDb__DatabaseName 環境変数
