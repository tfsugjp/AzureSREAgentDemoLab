---
id: kb-009
title: "azd up デプロイメント失敗のトラブルシューティング"
category: troubleshooting
service: all
severity: high
tags: [deployment, azd, provisioning, infrastructure]
lastUpdated: 2026-04-01T00:00:00Z
---

# azd up デプロイメント失敗のトラブルシューティング

## 症状
azd up コマンドの実行が失敗する。プロビジョニングフェーズまたはデプロイフェーズでエラーが発生する。

## プロビジョニングフェーズの一般的なエラー
1. リソースプロバイダー未登録: Microsoft.App, Microsoft.DocumentDB などのプロバイダーが未登録
2. リソース名の競合: グローバルに一意な名前 (Cosmos DB, ACR) の重複
3. クォータ制限: リージョンのリソースクォータ超過
4. Entra ID 設定不足: ENTRA_TENANT_ID, ENTRA_CLIENT_ID, ENTRA_AUDIENCE が未設定

## デプロイフェーズの一般的なエラー
1. Docker ビルドエラー: Dockerfile のビルドコンテキスト不正
2. ACR プッシュエラー: 認証エラーまたはネットワークタイムアウト
3. Container Apps デプロイエラー: イメージ参照の不一致

## 確認手順
1. azd env get-values で現在の環境変数を確認
2. Azure Portal でリソースグループのデプロイ履歴を確認
3. az provider list --query "[?registrationState=='NotRegistered']" で未登録プロバイダーを確認

## 対処方法
- リソースプロバイダー登録: az provider register --namespace Microsoft.App
- 環境変数設定: azd env set <KEY> <VALUE>
- Entra ID 設定: scripts/setup-entra-app.ps1 を実行
- リージョン変更: azd env set AZURE_LOCATION <別のリージョン>
- クリーンアップ: azd down で既存リソースを削除後、azd up で再デプロイ

## 前提条件
- Azure CLI がインストール済みであること
- Azure Developer CLI (azd) がインストール済みであること
- Docker Desktop が実行中であること
- .NET 10 SDK がインストール済みであること
