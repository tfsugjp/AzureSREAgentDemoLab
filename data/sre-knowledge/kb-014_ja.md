---
id: kb-014
title: "NotificationService API エンドポイント一覧"
category: reference
service: NotificationService
severity: low
tags: [api, endpoints, notification, reference]
lastUpdated: 2026-04-01T00:00:00Z
---

# NotificationService API エンドポイント一覧

## NotificationService API エンドポイント

### 通知管理
- GET /api/notifications - 全通知一覧取得
- GET /api/notifications?userId={userId} - ユーザー別通知取得
- GET /api/notifications/{id} - 通知詳細取得
- POST /api/notifications - 通知作成
- PUT /api/notifications/{id}/read - 既読マーク
- DELETE /api/notifications/{id} - 通知削除

### ヘルスチェック
- GET /health - ライブネスチェック
- GET /health/ready - レディネスチェック

### データモデル
- Notification: id, userId, title, message, type, isRead, relatedEntityId, createdAt
- NotificationType: OrderConfirmation, ShipmentUpdate, Promotion, Info, Alert

### シードデータ
- 15 通知 (3 ユーザー分)
- 注文確認、出荷通知、プロモーション、情報、アラートの各種タイプを含む
