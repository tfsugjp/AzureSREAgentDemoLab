---
id: kb-016
title: "CatalogService 在庫数不整合のトラブルシューティング"
category: troubleshooting
service: CatalogService
severity: medium
tags: [inventory, consistency, data-integrity, cosmos-db]
lastUpdated: 2026-04-01T00:00:00Z
---

# CatalogService 在庫数不整合のトラブルシューティング

## 症状
CatalogService の在庫情報 (GET /api/inventory/{productId}) で返却される在庫数が実際の期待値と異なる。予約数 (reservedQuantity) が実際の注文数と一致しない。

## 考えられる原因
1. OrderService と CatalogService 間の在庫同期が手動のため、不整合が発生
2. 同時更新による楽観的排他制御の競合
3. シードデータの初期値と実際の注文状態の不一致
4. Cosmos DB の結果整合性による一時的な不整合

## 確認手順
1. GET /api/inventory/{productId} で現在の在庫情報を取得
2. GET /api/orders でその商品に関する注文を確認
3. Cosmos DB の inventory コンテナで直接ドキュメントを確認
4. reservedQuantity と実際の Pending/Processing 注文数を比較

## 対処方法
- 在庫の手動修正: PUT /api/inventory/{productId} で正しい値に更新
- 再リコンシリエーション: 全注文を走査して reservedQuantity を再計算
- 同時更新対策: Cosmos DB の ETag を使用した楽観的排他制御の実装を検討

## シードデータの在庫
- 20 商品に対し各 10〜500 個の初期在庫
- 各商品に予約数 (1〜30) と再発注閾値 (5〜50) が設定済み
