---
id: kb-004
title: "Entra ID 認証エラーのトラブルシューティング"
category: troubleshooting
service: all
severity: high
tags: [authentication, entra-id, jwt, 401, security]
lastUpdated: 2026-04-01T00:00:00Z
---

# Entra ID 認証エラーのトラブルシューティング

## 症状
API エンドポイントへのリクエストで HTTP 401 Unauthorized が返却される。

## 考えられる原因
1. JWT トークンが未設定または無効
2. Entra ID アプリケーション登録が正しく構成されていない
3. テナント ID、クライアント ID、Audience の設定不一致
4. トークンの有効期限切れ
5. disableAuthentication フラグが false (デフォルト) で、トークンなしでアクセス

## 確認手順
1. リクエストヘッダーに Authorization: Bearer <token> が含まれているか確認
2. Azure Portal で Entra ID アプリケーション登録のステータスを確認
3. 環境変数 ENTRA_TENANT_ID, ENTRA_CLIENT_ID, ENTRA_AUDIENCE の値を確認
4. トークンのデコード (jwt.ms) で iss, aud クレームを確認

## 対処方法
- ワークショップ用の認証無効化: azd env set DISABLE_AUTHENTICATION true
- アプリ登録の再作成: scripts/setup-entra-app.ps1 を実行
- トークン再取得: az account get-access-token --resource <audience> コマンドを使用

## 関連設定
- Bicep: infra/modules/entra-app.bicep
- スクリプト: scripts/setup-entra-app.ps1
- ドキュメント: docs/entra-app-setup.md
