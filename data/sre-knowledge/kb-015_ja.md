---
id: kb-015
title: "Container Apps ログの収集と分析"
category: runbook
service: all
severity: low
tags: [logging, log-analytics, kql, application-insights, serilog]
lastUpdated: 2026-04-01T00:00:00Z
---

# Container Apps ログの収集と分析

## 概要
各サービスのログは Container Apps Environment 経由で Azure Monitor (Log Analytics Workspace) に送信される。

## ログの確認方法

### Azure Portal
1. Azure Portal で該当の Container Apps リソースを開く
2. [監視] → [ログ] を選択
3. KQL クエリを使用してログを検索

### KQL クエリ例
```kql
// CatalogService のエラーログ
ContainerAppConsoleLogs_CL
| where ContainerAppName_s startswith 'ca-cat'
| where Log_s contains 'Error' or Log_s contains 'Exception'
| order by TimeGenerated desc
| take 50

// 特定の時間帯のリクエストログ
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s contains 'Searching products'
| order by TimeGenerated desc

// Container Apps のシステムログ
ContainerAppSystemLogs_CL
| where ContainerAppName_s startswith 'ca-'
| where Type_s == 'Error'
| order by TimeGenerated desc
| take 20
```

### Application Insights
Application Insights では以下のテレメトリデータが利用可能:
- リクエスト: 各 API エンドポイントへのリクエスト情報
- 依存関係: Cosmos DB への呼び出し情報
- 例外: 未処理例外のスタックトレース
- トレース: Serilog による構造化ログ

## Serilog 構造化ログ
各サービスは Serilog を使用して構造化ログを出力。キーとなるログプロパティ:
- RequestPath: リクエストのパス
- StatusCode: HTTP レスポンスコード
- ElapsedMilliseconds: リクエスト処理時間
- UserId: 認証済みユーザー ID
