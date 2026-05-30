---
id: kb-019
title: "スレッドプール枯渇の検知と対処"
category: runbook
service: CatalogService
severity: high
tags: [thread-pool, performance, blocking, async, runbook]
lastUpdated: 2026-04-01T00:00:00Z
---

# スレッドプール枯渇の検知と対処

## 概要
CatalogService の Premium 検索パスで Thread.Sleep を使用した同期ブロッキングが発生すると、.NET スレッドプールの枯渇を引き起こす可能性がある。

## 検知方法

### Application Insights メトリクス
- リクエストの平均応答時間が急増 (通常 < 100ms → 数秒以上)
- 同時リクエスト数の減少 (スレッド枯渇により新規リクエストを受け付けられない)
- 依存関係呼び出しのタイムアウト増加

### ログベースの検知
- "Performing premium product search with enhanced filtering" ログの出現頻度が高い
- ThreadPool.GetAvailableThreads で利用可能スレッド数が減少

### 外形監視
- ヘルスチェック /health のレスポンスタイムが増加
- /health/ready が timeout する

## 即時対処
1. premium 検索パスへのトラフィックを一時的にブロック (API Gateway ルール)
2. Container Apps のインスタンス数を手動でスケールアウト
3. CatalogService のコンテナを再起動 (根本対処ではない)

## 恒久対処
1. Thread.Sleep(100) を await Task.Delay(100) に変更
2. 全商品一括取得を Cosmos DB クエリでの直接フィルタリングに変更
3. 非同期パターンの徹底適用

## 関連ナレッジ
- kb-001: CatalogService 商品検索のレスポンス遅延 (Premium 検索パス)
