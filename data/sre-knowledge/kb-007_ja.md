---
id: kb-007
title: "OrderService 注文ステータス更新の失敗"
category: troubleshooting
service: OrderService
severity: medium
tags: [order, status, api, validation]
lastUpdated: 2026-04-01T00:00:00Z
---

# OrderService 注文ステータス更新の失敗

## 症状
OrderService の PUT /api/orders/{id}/status エンドポイントで注文ステータスの更新が失敗する。HTTP 404 Not Found または HTTP 400 Bad Request が返却される。

## 考えられる原因
1. 指定された注文 ID が存在しない
2. ステータス遷移が無効 (例: Delivered → Pending への逆遷移)
3. Cosmos DB のパーティションキー (UserId) の不一致
4. 注文がキャンセル済み (Cancelled ステータスからの遷移は不可)

## 確認手順
1. GET /api/orders/{id} で注文の現在のステータスを確認
2. ステータス遷移の妥当性を確認: Pending → Confirmed → Processing → Shipped → Delivered
3. Cosmos DB コンテナ 'orders' で該当ドキュメントを直接確認

## 対処方法
- 正しい注文 ID を使用してリクエストを再送
- ステータス遷移ルールに従った更新を実施
- キャンセル済み注文は新規注文として作成し直す

## 有効なステータス遷移
- Pending → Confirmed, Cancelled
- Confirmed → Processing, Cancelled
- Processing → Shipped
- Shipped → Delivered
- Delivered, Cancelled → (遷移不可)
