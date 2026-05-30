---
id: kb-012
title: "CatalogService API エンドポイント一覧"
category: reference
service: CatalogService
severity: low
tags: [api, endpoints, catalog, reference]
lastUpdated: 2026-04-01T00:00:00Z
---

# CatalogService API エンドポイント一覧

## CatalogService API エンドポイント

### 商品管理
- GET /api/products - 全商品一覧取得
- GET /api/products/{id} - 商品詳細取得
- POST /api/products - 商品作成
- PUT /api/products/{id} - 商品更新
- DELETE /api/products/{id} - 商品削除

### 商品検索
- GET /api/products/search?q={query} - 商品検索
  - 注意: q=premium は既知のパフォーマンス問題あり (kb-001 参照)
  - 注意: q の長さが 100 文字超で HTTP 500 (kb-002 参照)

### カテゴリ管理
- GET /api/categories - 全カテゴリ一覧取得
- GET /api/categories/{id} - カテゴリ詳細取得

### 在庫管理
- GET /api/inventory/{productId} - 在庫情報取得
- PUT /api/inventory/{productId} - 在庫情報更新

### ヘルスチェック
- GET /health - ライブネスチェック
- GET /health/ready - レディネスチェック

### データモデル
- Product: id, name, description, price, categoryId, categoryName, tags, imageUrl, isActive
- Category: id, name, description
- InventoryItem: id, productId, quantity, reservedQuantity, reorderThreshold

### シードデータ
- 5 カテゴリ: Electronics, Clothing, Food, Books, Premium
- 20 商品 (各カテゴリ 4 商品)
- 20 在庫アイテム
