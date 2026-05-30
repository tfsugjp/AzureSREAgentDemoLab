---
id: kb-018
title: "ACR (Azure Container Registry) イメージプル失敗"
category: troubleshooting
service: all
severity: high
tags: [acr, container-registry, image-pull, rbac, managed-identity]
lastUpdated: 2026-04-01T00:00:00Z
---

# ACR (Azure Container Registry) イメージプル失敗

## 症状
Container Apps がコンテナイメージを ACR からプルできない。Container Apps のリビジョンが Failed 状態になる。

## 考えられる原因
1. ACR Pull ロール割り当てが正しく設定されていない
2. Container Apps のマネージド ID が無効
3. ACR の管理者ユーザーが無効 (設計上、adminUserEnabled: false)
4. イメージタグが存在しない
5. ACR のネットワーク設定でアクセスがブロックされている

## 確認手順
1. Azure Portal で ACR のアクセス制御 (IAM) を確認
2. Container Apps のシステムマネージド ID が有効か確認
3. ACR のリポジトリでイメージの存在を確認
4. Container Apps のシステムログでイメージプルエラーの詳細を確認

## 対処方法
- ロール割り当て確認: main.bicep の catalogAcrPull, orderAcrPull, notificationAcrPull リソースが正しく作成されていることを確認
- マネージド ID: container-app.bicep の identity 設定で systemAssigned が有効であることを確認
- イメージ再プッシュ: azd deploy で最新イメージを ACR にプッシュ
- ACR ネットワーク: publicNetworkAccess が 'Enabled' に設定されていることを確認

## 関連設定
- Bicep: infra/main.bicep の containerRegistry リソースと各 AcrPull ロール割り当て
- Bicep: infra/modules/container-app.bicep の registryServer パラメータ
