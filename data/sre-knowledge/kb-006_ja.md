---
id: kb-006
title: "OpenTelemetry トレーシングデータが表示されない"
category: troubleshooting
service: all
severity: medium
tags: [opentelemetry, tracing, application-insights, monitoring, observability]
lastUpdated: 2026-04-01T00:00:00Z
---

# OpenTelemetry トレーシングデータが表示されない

## 症状
Application Insights またはカスタム OTLP エンドポイントにトレーシングデータが表示されない。分散トレースが不完全、またはサービス間の呼び出しが追跡できない。

## 考えられる原因
1. Application Insights の接続文字列が正しく設定されていない
2. OpenTelemetry SDK の初期化エラー
3. Container Apps Environment の OpenTelemetry 設定が不適切
4. OTLP エンドポイントへのネットワーク接続の問題
5. サンプリング率の設定 (SamplingPercentage) により一部のトレースが欠落

## 確認手順
1. Application Insights リソースの接続文字列を確認
2. Container Apps Environment の openTelemetryConfiguration を確認
3. 各サービスのログで OpenTelemetry 初期化メッセージを確認
4. Application Insights の Live Metrics でリアルタイムデータを確認

## 対処方法
- Application Insights 設定の確認: Azure Portal でリソースのプロパティから接続文字列をコピー
- Container Apps の設定: logsConfiguration と tracesConfiguration の destinations が 'appInsights' に設定されていることを確認
- サンプリング率: SamplingPercentage を 100 に設定して全トレースを収集 (デフォルト設定)
- カスタム OTLP: openTelemetryEndpoint パラメータに正しいエンドポイント URL を設定

## 関連設定
- Bicep: infra/main.bicep の applicationInsights リソースと containerAppsEnvironment の openTelemetryConfiguration
- アプリ: SharedLibrary 内の OpenTelemetry 構成
