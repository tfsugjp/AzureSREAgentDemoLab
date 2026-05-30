# Entra ID アプリケーション登録セットアップガイド

> For the English version, see [entra-app-setup.md](./entra-app-setup.md).

このガイドでは、AzureSREAgentDemoLab Container Apps API用のEntra IDアプリケーション登録を作成し、azd環境に設定する手順を説明します。

## 前提条件

- Azure CLIがインストールされていること
- 適切なAzureサブスクリプションにログインしていること
- Microsoft Graph拡張機能を使用する権限があること(またはCLI方法を使用)

## 方法1: Bicep IaCで作成 (推奨)

### ステップ1: Bicepテンプレートをデプロイ

```powershell
# 環境名を設定
$envName = "dev"
$appName = "<your-entra-app-name>"

# リソースグループを作成(まだ存在しない場合)
az group create --name "rg-entra-apps" --location "westus3"

# Entra IDアプリケーション登録を作成
az deployment group create `
  --resource-group "rg-entra-apps" `
  --name "entra-app" `
  --template-file "infra/modules/entra-app.bicep" `
  --parameters appDisplayName=$appName `
  --query "properties.outputs"
```

### ステップ2: 出力値を取得

デプロイが完了したら、以下の値を記録します:

```powershell
# デプロイ結果から値を取得
$deploymentOutput = az deployment group show `
  --resource-group "rg-entra-apps" `
  --name "entra-app" `
  --query "properties.outputs" `
  -o json | ConvertFrom-Json

$clientId = $deploymentOutput.applicationId.value
$audience = $deploymentOutput.identifierUri.value

# テナントIDを取得
$tenantId = az account show --query tenantId -o tsv

Write-Host "ENTRA_TENANT_ID: $tenantId"
Write-Host "ENTRA_CLIENT_ID: $clientId"
Write-Host "ENTRA_AUDIENCE: $audience"
```

## 方法2: Azure CLIで作成 (シンプル)

### ステップ1: アプリケーション登録を作成

```powershell
# 環境名を設定
$envName = "dev"
$appName = "<your-entra-app-name>"

# アプリケーション登録を作成
$app = az ad app create `
  --display-name $appName `
  --sign-in-audience "AzureADMyOrg" `
  --query "{appId:appId,objectId:id}" `
  -o json | ConvertFrom-Json

$clientId = $app.appId
$objectId = $app.objectId

Write-Host "Application (Client) ID: $clientId"
Write-Host "Object ID: $objectId"
```

### ステップ2: App ID URI (Audience) を設定

```powershell
# App ID URIを設定
$audience = "api://$clientId"

az ad app update `
  --id $objectId `
  --identifier-uris $audience

Write-Host "Audience (App ID URI): $audience"
```

### ステップ3: APIスコープを公開 (オプション)

```powershell
# OAuth2スコープを定義
$scopeId = [guid]::NewGuid().ToString()
$scopes = @{
  oauth2PermissionScopes = @(
    @{
      id = $scopeId
      adminConsentDisplayName = "Access API as user"
      adminConsentDescription = "Allows the app to access the API on behalf of the signed-in user"
      userConsentDisplayName = "Access API as you"
      userConsentDescription = "Allows the app to access the API on your behalf"
      value = "access_as_user"
      type = "User"
      isEnabled = $true
    }
  )
}

# スコープを追加
$scopesJson = $scopes | ConvertTo-Json -Depth 10
az ad app update --id $objectId --set api="$scopesJson"
```

### ステップ4: サービスプリンシパルを作成

```powershell
# サービスプリンシパル (Enterprise Application) を作成
az ad sp create --id $clientId

Write-Host "Service Principal created successfully"
```

### ステップ5: テナントIDを取得

```powershell
# テナントIDを取得
$tenantId = az account show --query tenantId -o tsv

Write-Host "ENTRA_TENANT_ID: $tenantId"
Write-Host "ENTRA_CLIENT_ID: $clientId"
Write-Host "ENTRA_AUDIENCE: $audience"
```

## ステップ3: azd環境を作成して設定

### 3.1 新しいazd環境を作成

```powershell
# プロジェクトのルートディレクトリに移動
cd <repo-root>

# dev環境を作成
azd env new dev -l westus3
```

### 3.2 Entra ID設定を環境に追加

```powershell
# 上記で取得した値を設定
azd env set ENTRA_TENANT_ID $tenantId
azd env set ENTRA_CLIENT_ID $clientId
azd env set ENTRA_AUDIENCE $audience
```

### 3.3 環境変数を確認

```powershell
# 設定された環境変数を確認
azd env get-values
```

期待される出力:

```text
AZURE_ENV_NAME="dev"
AZURE_LOCATION="westus3"
ENTRA_AUDIENCE="api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ENTRA_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ENTRA_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## 次のステップ

環境設定が完了したら、以下のコマンドで検証とデプロイを実行できます:

### 検証 (What-If分析)

```powershell
# Bicepテンプレートのプレビュー検証
azd provision --preview
```

### デプロイ

```powershell
# インフラストラクチャとアプリケーションをデプロイ
azd up
```

または個別に:

```powershell
# インフラストラクチャのみプロビジョニング
azd provision

# アプリケーションのみデプロイ
azd deploy
```

## トラブルシューティング

### エラー: "insufficient privileges to complete the operation"

Microsoft Graph拡張を使用したBicepデプロイには、Azure AD管理者権限が必要です。
権限がない場合は、**方法2 (Azure CLI)** を使用してください。

### エラー: "AADSTS700016: Application not found"

サービスプリンシパルが作成されていない可能性があります:

```powershell
az ad sp create --id <clientId>
```

### 環境変数が反映されない

`.azure/dev/.env`ファイルを直接確認してください:

```powershell
Get-Content .azure\dev\.env
```

## 参考資料

- [Microsoft Entra ID アプリケーション登録ドキュメント](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app)
- [Azure Developer CLI 環境管理](https://learn.microsoft.com/azure/developer/azure-developer-cli/manage-environment-variables)
- [ASP.NET Core JWT Bearer 認証](https://learn.microsoft.com/aspnet/core/security/authentication/jwt-authn)
