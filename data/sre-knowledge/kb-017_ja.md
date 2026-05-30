---
id: kb-017
title: "Docker ビルドとローカル開発環境のトラブルシューティング"
category: troubleshooting
service: all
severity: medium
tags: [docker, local-development, build, troubleshooting]
lastUpdated: 2026-04-01T00:00:00Z
---

# Docker ビルドとローカル開発環境のトラブルシューティング

## 症状
Docker コンテナのビルドまたは docker-compose での起動が失敗する。

## 一般的なエラーと対処

### ビルドエラー: NuGet パッケージの復元失敗
原因: ネットワーク接続の問題、またはプライベート NuGet フィードの認証エラー
対処: docker build --no-cache で再ビルド、ネットワーク接続を確認

### ビルドエラー: Dockerfile のコンテキスト不正
原因: 各サービスの Dockerfile はルートディレクトリをコンテキストとして使用
対処: docker build -f src/CatalogService/Dockerfile -t catalog . のようにルートからビルド

### 起動エラー: ポート競合
原因: ローカルの 5001, 5002, 5003 ポートが他のプロセスで使用中
対処: netstat -tlnp | grep '500[1-3]' でポート使用状況を確認し、競合プロセスを停止

### 起動エラー: Cosmos DB 接続失敗
原因: ローカル環境に Cosmos DB エミュレータまたは接続文字列が未設定
対処: Azure Cosmos DB Emulator を起動、または Azure 上の Cosmos DB 接続文字列を環境変数に設定

## ローカル開発コマンド
```bash
# ソリューション全体のビルド
dotnet build AzureSREAgentDemoLab.slnx

# Docker Compose でのローカル起動
docker-compose up --build

# 個別サービスの起動
cd src/CatalogService && dotnet run
```
