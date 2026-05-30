---
id: kb-005
title: "Container Apps のスケーリング問題"
category: troubleshooting
service: all
severity: medium
tags: [container-apps, scaling, cold-start, performance]
lastUpdated: 2026-04-01T00:00:00Z
---

# Container Apps のスケーリング問題

## 症状
Container Apps のインスタンスが 0 にスケールダウンしたまま復帰しない、またはスケールアウトが遅延する。コールドスタートにより初回リクエストのレスポンスが大幅に遅延する。

## 考えられる原因
1. 非本番環境では minReplicas が 0 に設定されているため、アイドル時にインスタンスが 0 になる
2. コンテナイメージのプルに時間がかかる (ACR から)
3. .NET アプリケーションの起動時に Cosmos DB シードデータ投入が実行される
4. ヘルスチェックのタイムアウト設定が短い

## 確認手順
1. Azure Portal で Container Apps のレプリカ数を確認
2. Container Apps のログでスタートアップイベントを確認
3. ACR からのイメージプルステータスを確認
4. ヘルスチェックエンドポイント (/health, /health/ready) の応答を確認

## 対処方法
- 本番環境: environmentType を 'prod' に設定すると minReplicas が 1 になりコールドスタートを回避
- 非本番環境: 必要に応じて minReplicas を手動で 1 に変更
- ACR プル高速化: ACR の SKU を Basic から Standard に変更
- シード処理の最適化: StartupInitializationService の初期化時間を短縮

## 関連設定
- Bicep: infra/main.bicep の minReplicas / maxReplicas 変数
- Bicep: infra/modules/container-app.bicep のヘルスプローブ設定
