---
id: kb-008
title: "NotificationService 通知配信の遅延・欠落"
category: troubleshooting
service: NotificationService
severity: medium
tags: [notification, delivery, cosmos-db, consistency]
lastUpdated: 2026-04-01T00:00:00Z
---

# NotificationService 通知配信の遅延・欠落

## 症状
NotificationService で作成した通知が GET /api/notifications?userId={userId} で取得できない、または通知の配信に遅延が生じる。

## 考えられる原因
1. Cosmos DB のインデキシングポリシーによる遅延 (Eventual Consistency)
2. パーティションキー (UserId) の指定ミス
3. Cosmos DB の Serverless モードでの一時的なスロットリング
4. 通知の IsRead フィルタリングの問題

## 確認手順
1. POST /api/notifications で通知作成時のレスポンスを確認 (201 Created が返却されるか)
2. Cosmos DB のメトリクスで 429 (Too Many Requests) エラーを確認
3. 通知の userId が正しいか確認
4. Cosmos DB コンテナ 'notifications' のインデキシングポリシーを確認

## 対処方法
- Cosmos DB のコンシステンシーレベルを Session から Strong に変更 (読み取り直後の一貫性が必要な場合)
- スロットリング発生時: リトライロジックの確認と適切なバックオフの実装
- パーティションキーの確認: 通知作成と取得で同じ UserId を使用

## API エンドポイント
- POST /api/notifications - 通知作成
- GET /api/notifications?userId={userId} - ユーザー別通知取得
- PUT /api/notifications/{id}/read - 既読マーク
