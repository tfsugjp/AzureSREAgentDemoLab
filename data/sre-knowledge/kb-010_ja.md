---
id: kb-010
title: "ヘルスチェックエンドポイントの監視と診断"
category: runbook
service: all
severity: low
tags: [health-check, monitoring, liveness, readiness, container-apps]
lastUpdated: 2026-04-01T00:00:00Z
---

# ヘルスチェックエンドポイントの監視と診断

## 概要
各マイクロサービスは以下のヘルスチェックエンドポイントを公開している:
- GET /health - 基本的なライブネスチェック
- GET /health/ready - 依存サービス (Cosmos DB) を含むレディネスチェック

## 監視方法
### ライブネスチェック
アプリケーションプロセスが応答可能かを確認。HTTP 200 が返却されればプロセスは正常。
```bash
curl http://localhost:5001/health  # CatalogService
curl http://localhost:5002/health  # OrderService
curl http://localhost:5003/health  # NotificationService
```

### レディネスチェック
アプリケーションがリクエスト処理可能かを確認。Cosmos DB への接続を含む。
```bash
curl http://localhost:5001/health/ready  # CatalogService
curl http://localhost:5002/health/ready  # OrderService
curl http://localhost:5003/health/ready  # NotificationService
```

## Container Apps のプローブ設定
- Startup Probe: /health, 初期遅延 5 秒、間隔 10 秒、失敗閾値 3
- Liveness Probe: /health, 間隔 30 秒、失敗閾値 3
- Readiness Probe: /health/ready, 間隔 15 秒、失敗閾値 3

## 異常時の対応
- ライブネスチェック失敗: コンテナが自動的に再起動される
- レディネスチェック失敗: トラフィックがルーティングされなくなる。Cosmos DB 接続を確認
- 両方失敗: コンテナのログを確認し、起動エラーの原因を特定
