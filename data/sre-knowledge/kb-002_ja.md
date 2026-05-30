---
id: kb-002
title: "CatalogService 長いクエリ文字列による HTTP 500 エラー"
category: troubleshooting
service: CatalogService
severity: high
tags: [error, 500, search, validation, substring]
lastUpdated: 2026-04-01T00:00:00Z
---

# CatalogService 長いクエリ文字列による HTTP 500 エラー

## 症状
CatalogService の商品検索エンドポイント GET /api/products/search で、クエリパラメータ q の文字数が 100 文字を超えると HTTP 500 Internal Server Error が発生する。

## 根本原因
ProductSearchService.cs の SearchAsync メソッドにおいて、クエリ長が 100 文字を超えた場合の処理に String.Substring の境界チェックバグが存在する。具体的には:
1. query.Substring(0, 100) で先頭100文字を切り出し
2. query.Substring(100, 100) で次の100文字を切り出そうとする
3. クエリが 200 文字未満の場合、2番目の Substring で ArgumentOutOfRangeException がスローされる

## 影響範囲
- CatalogService の /api/products/search エンドポイント
- クエリ文字列が 100 文字を超え 200 文字未満のリクエスト

## 対処方法
1. 即時対応: API Gateway またはリバースプロキシでクエリ文字列の長さを制限
2. 恒久対応: Substring の境界チェックを修正し、適切な文字列トランケーション処理に置換
3. 推奨: クエリ文字列のバリデーションをエンドポイント層で実施し、過度に長いクエリは 400 Bad Request で拒否

## 再現コマンド
```bash
curl -s -o /dev/null -w '%{http_code}' "http://localhost:5001/api/products/search?q=$(python3 -c 'print("a"*150)')"
```

## 関連ログ
スタックトレースに System.ArgumentOutOfRangeException が含まれる。
