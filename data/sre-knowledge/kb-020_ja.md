---
id: kb-020
title: "Cosmos DB パーティションキー設計とクエリパフォーマンス"
category: reference
service: all
severity: low
tags: [cosmos-db, partition-key, query-performance, serverless]
lastUpdated: 2026-04-01T00:00:00Z
---

# Cosmos DB パーティションキー設計とクエリパフォーマンス

## パーティションキー設計

### 各コンテナのパーティションキー
| コンテナ | パーティションキー | 説明 |
|----------|---------------------|------|
| categories | /id | カテゴリ ID |
| products | /categoryId | カテゴリ ID でパーティショニング |
| inventory | /productId | 商品 ID でパーティショニング |
| orders | /userId | ユーザー ID でパーティショニング |
| notifications | /userId | ユーザー ID でパーティショニング |

### クエリパフォーマンスの考慮事項
- パーティションキーを指定したクエリは単一パーティションで実行され効率的
- パーティションキーを指定しないクエリはクロスパーティションクエリとなり、全パーティションをスキャンするため非効率
- products コンテナの検索 (GET /api/products/search) はクロスパーティションクエリを使用

### Serverless モードの制約
- リクエストあたり最大 5,000 RU
- ストレージ最大 1 TB
- SLA は Standard アカウントと異なる
- 長時間のアイドル後にコールドスタートが発生する可能性

### パフォーマンス最適化
1. クエリにパーティションキーを含める
2. 読み取り負荷の高いワークロードでは Session 一貫性で十分
3. 不要なプロパティの SELECT を避け、必要なプロパティのみを射影
4. Cosmos DB のメトリクスで RU 消費量を監視
