---
id: kb-001
title: "CatalogService 商品検索のレスポンス遅延 (Premium 検索パス)"
category: troubleshooting
service: CatalogService
severity: high
tags: [performance, thread-pool, search, premium, latency]
lastUpdated: 2026-04-01T00:00:00Z
---

# CatalogService 商品検索のレスポンス遅延 (Premium 検索パス)

## 症状
CatalogService の商品検索エンドポイント GET /api/products/search?q=premium にリクエストすると、レスポンスが数秒以上かかる。通常の検索クエリは 100ms 以内に返却されるが、premium を含むクエリのみ顕著に遅延する。

## 根本原因
ProductSearchService.cs 内の検索ロジックにおいて、クエリ文字列に "premium" が含まれる場合、専用の検索パスが実行される。この検索パスでは以下の問題がある:
1. 全商品を Cosmos DB から一括取得するアンチパターン (SELECT * FROM c WHERE c.isActive = true)
2. 取得した各商品に対して Thread.Sleep(100) を呼び出し、同期的にスレッドをブロックしている
3. async/await パターンではなく同期処理を使用しているため、スレッドプール枯渇を引き起こす

## 影響範囲
- CatalogService の /api/products/search エンドポイント
- premium を含むクエリのみ影響
- 高負荷時にはスレッドプール枯渇により他のリクエストにも波及

## 対処方法
1. 即時対応: premium 検索のトラフィックを制限するレートリミットを設定
2. 恒久対応: Thread.Sleep(100) を await Task.Delay(100) に置換、または外部サービス呼び出しの模擬処理を削除
3. 恒久対応: 全商品一括取得をやめ、Cosmos DB のクエリで直接フィルタリングする

## 確認コマンド
```bash
curl -w '\nTotal: %{time_total}s\n' http://localhost:5001/api/products/search?q=premium
curl -w '\nTotal: %{time_total}s\n' http://localhost:5001/api/products/search?q=wireless
```

## 関連ログ
検索実行時に以下のログが出力される:
- "Searching products with query: premium"
- "Performing premium product search with enhanced filtering"
