---
id: kb-013
title: "OrderService API エンドポイント一覧"
category: reference
service: OrderService
severity: low
tags: [api, endpoints, order, reference]
lastUpdated: 2026-04-01T00:00:00Z
---

# OrderService API エンドポイント一覧

## OrderService API エンドポイント

### 注文管理
- GET /api/orders - 全注文一覧取得
- GET /api/orders/{id} - 注文詳細取得
- GET /api/orders/user/{userId} - ユーザー別注文取得
- POST /api/orders - 注文作成
- PUT /api/orders/{id} - 注文更新
- DELETE /api/orders/{id} - 注文削除
- PUT /api/orders/{id}/status - ステータス更新
- POST /api/orders/{id}/cancel - 注文キャンセル

### ヘルスチェック
- GET /health - ライブネスチェック
- GET /health/ready - レディネスチェック

### データモデル
- Order: id, userId, status, shippingAddress, notes, items, totalAmount, createdAt, updatedAt
- OrderItem: productId, productName, quantity, unitPrice
- OrderStatus: Pending, Confirmed, Processing, Shipped, Delivered, Cancelled

### ステータス遷移ルール
- Pending → Confirmed, Cancelled
- Confirmed → Processing, Cancelled
- Processing → Shipped
- Shipped → Delivered
- Delivered, Cancelled → 遷移不可

### シードデータ
- 10 注文 (3 ユーザー分)
- 各種ステータスの注文を含む
