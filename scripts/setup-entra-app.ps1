# GlobalAzureDemo2026 - Entra ID Application Registration Setup Script
# このスクリプトは、Container Apps API用のEntra IDアプリケーション登録を作成し、
# azd環境に必要な設定を追加します。

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus3",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAzdEnvCreation
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GlobalAzureDemo2026 Entra ID Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ステップ1: Azure CLIログイン確認
Write-Host "[1/5] Azure CLI ログイン状態を確認中..." -ForegroundColor Yellow
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "  ✓ ログイン済み: $($account.user.name)" -ForegroundColor Green
    Write-Host "  ✓ サブスクリプション: $($account.name)" -ForegroundColor Green
    Write-Host "  ✓ テナントID: $($account.tenantId)" -ForegroundColor Green
    $tenantId = $account.tenantId
} catch {
    Write-Host "  ✗ Azure CLIにログインしていません" -ForegroundColor Red
    Write-Host "  以下のコマンドでログインしてください:" -ForegroundColor Yellow
    Write-Host "    az login" -ForegroundColor Cyan
    exit 1
}
Write-Host ""

# ステップ2: Entra IDアプリケーション登録を作成
Write-Host "[2/5] Entra IDアプリケーション登録を作成中..." -ForegroundColor Yellow
$appDisplayName = "GlobalAzureDemo-API-$EnvironmentName"

try {
    # 既存のアプリケーション登録を確認
    $existingApp = az ad app list --display-name $appDisplayName 2>$null | ConvertFrom-Json
    
    if ($existingApp -and $existingApp.Count -gt 0) {
        Write-Host "  ⚠ アプリケーション '$appDisplayName' は既に存在します" -ForegroundColor Yellow
        $clientId = $existingApp[0].appId
        $objectId = $existingApp[0].id
        Write-Host "  ✓ 既存のアプリケーションを使用: $clientId" -ForegroundColor Green
    } else {
        # 新規作成
        Write-Host "  作成中: $appDisplayName" -ForegroundColor Cyan
        $app = az ad app create `
            --display-name $appDisplayName `
            --sign-in-audience "AzureADMyOrg" `
            --query "{appId:appId,objectId:id}" `
            -o json | ConvertFrom-Json
        
        $clientId = $app.appId
        $objectId = $app.objectId
        Write-Host "  ✓ アプリケーション作成完了" -ForegroundColor Green
        Write-Host "    Client ID: $clientId" -ForegroundColor Cyan
    }
} catch {
    Write-Host "  ✗ アプリケーション登録の作成に失敗しました" -ForegroundColor Red
    Write-Host "  エラー: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ステップ3: App ID URI (Audience) を設定
Write-Host "[3/5] App ID URI (Audience) を設定中..." -ForegroundColor Yellow
$audience = "api://$clientId"

try {
    az ad app update `
        --id $objectId `
        --identifier-uris $audience `
        2>$null
    Write-Host "  ✓ Audience設定完了: $audience" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Audience設定をスキップ (既に設定済みの可能性)" -ForegroundColor Yellow
}
Write-Host ""

# ステップ4: サービスプリンシパルを作成
Write-Host "[4/5] サービスプリンシパルを作成中..." -ForegroundColor Yellow
try {
    $sp = az ad sp list --filter "appId eq '$clientId'" 2>$null | ConvertFrom-Json
    
    if ($sp -and $sp.Count -gt 0) {
        Write-Host "  ✓ サービスプリンシパルは既に存在します" -ForegroundColor Green
    } else {
        az ad sp create --id $clientId 2>$null
        Write-Host "  ✓ サービスプリンシパル作成完了" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ サービスプリンシパルの作成をスキップ" -ForegroundColor Yellow
}
Write-Host ""

# ステップ5: azd環境を作成・設定
Write-Host "[5/5] azd環境を設定中..." -ForegroundColor Yellow

if (-not $SkipAzdEnvCreation) {
    # 既存の環境を確認
    $existingEnvs = azd env list --output json 2>$null | ConvertFrom-Json
    $envExists = $existingEnvs | Where-Object { $_.Name -eq $EnvironmentName }
    
    if ($envExists) {
        Write-Host "  ⚠ azd環境 '$EnvironmentName' は既に存在します" -ForegroundColor Yellow
        $response = Read-Host "  既存の環境を使用しますか? (Y/n)"
        if ($response -eq "n" -or $response -eq "N") {
            Write-Host "  処理を中断します" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  azd環境を作成中: $EnvironmentName (location: $Location)" -ForegroundColor Cyan
        azd env new $EnvironmentName -l $Location
        Write-Host "  ✓ azd環境作成完了" -ForegroundColor Green
    }
}

# 環境変数を設定
Write-Host "  環境変数を設定中..." -ForegroundColor Cyan
azd env set ENTRA_TENANT_ID $tenantId
azd env set ENTRA_CLIENT_ID $clientId
azd env set ENTRA_AUDIENCE $audience

Write-Host "  ✓ 環境変数設定完了" -ForegroundColor Green
Write-Host ""

# 完了メッセージ
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ セットアップ完了!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "設定された値:" -ForegroundColor Cyan
Write-Host "  ENTRA_TENANT_ID : $tenantId" -ForegroundColor White
Write-Host "  ENTRA_CLIENT_ID : $clientId" -ForegroundColor White
Write-Host "  ENTRA_AUDIENCE  : $audience" -ForegroundColor White
Write-Host ""

# 環境変数を確認
Write-Host "環境変数の確認:" -ForegroundColor Cyan
azd env get-values
Write-Host ""

Write-Host "次のステップ:" -ForegroundColor Yellow
Write-Host "  1. 検証を実行:   azd provision --preview" -ForegroundColor Cyan
Write-Host "  2. デプロイ実行: azd up" -ForegroundColor Cyan
Write-Host ""
