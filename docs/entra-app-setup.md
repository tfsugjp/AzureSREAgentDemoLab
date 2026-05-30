# Entra ID Application Registration Setup Guide

> 日本語版は [entra-app-setup_ja.md](./entra-app-setup_ja.md) を参照してください。

This guide explains how to create a Microsoft Entra ID application registration for the
AzureSREAgentDemoLab Container Apps API and configure it in your `azd` environment.

## Prerequisites

- Azure CLI is installed.
- You are signed in to the correct Azure subscription.
- You have permission to use the Microsoft Graph extension (or use the CLI method).

## Method 1: Create with Bicep IaC (recommended)

### Step 1: Deploy the Bicep template

```powershell
# Set the environment name
$envName = "dev"
$appName = "<your-entra-app-name>"

# Create the resource group (if it does not already exist)
az group create --name "rg-entra-apps" --location "westus3"

# Create the Entra ID application registration
az deployment group create `
  --resource-group "rg-entra-apps" `
  --name "entra-app" `
  --template-file "infra/modules/entra-app.bicep" `
  --parameters appDisplayName=$appName `
  --query "properties.outputs"
```

### Step 2: Capture the output values

After the deployment completes, record the following values:

```powershell
# Read the values from the deployment result
$deploymentOutput = az deployment group show `
  --resource-group "rg-entra-apps" `
  --name "entra-app" `
  --query "properties.outputs" `
  -o json | ConvertFrom-Json

$clientId = $deploymentOutput.applicationId.value
$audience = $deploymentOutput.identifierUri.value

# Get the tenant ID
$tenantId = az account show --query tenantId -o tsv

Write-Host "ENTRA_TENANT_ID: $tenantId"
Write-Host "ENTRA_CLIENT_ID: $clientId"
Write-Host "ENTRA_AUDIENCE: $audience"
```

## Method 2: Create with Azure CLI (simple)

### Step 1: Create the application registration

```powershell
# Set the environment name
$envName = "dev"
$appName = "<your-entra-app-name>"

# Create the application registration
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

### Step 2: Set the App ID URI (Audience)

```powershell
# Set the App ID URI
$audience = "api://$clientId"

az ad app update `
  --id $objectId `
  --identifier-uris $audience

Write-Host "Audience (App ID URI): $audience"
```

### Step 3: Expose an API scope (optional)

```powershell
# Define an OAuth2 scope
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

# Add the scope
$scopesJson = $scopes | ConvertTo-Json -Depth 10
az ad app update --id $objectId --set api="$scopesJson"
```

### Step 4: Create the service principal

```powershell
# Create the service principal (Enterprise Application)
az ad sp create --id $clientId

Write-Host "Service Principal created successfully"
```

### Step 5: Get the tenant ID

```powershell
# Get the tenant ID
$tenantId = az account show --query tenantId -o tsv

Write-Host "ENTRA_TENANT_ID: $tenantId"
Write-Host "ENTRA_CLIENT_ID: $clientId"
Write-Host "ENTRA_AUDIENCE: $audience"
```

## Step 3: Create and configure the azd environment

### 3.1 Create a new azd environment

```powershell
# Move to the project root directory
cd <repo-root>

# Create the dev environment
azd env new dev -l westus3
```

### 3.2 Add the Entra ID settings to the environment

```powershell
# Set the values captured above
azd env set ENTRA_TENANT_ID $tenantId
azd env set ENTRA_CLIENT_ID $clientId
azd env set ENTRA_AUDIENCE $audience
```

### 3.3 Verify the environment variables

```powershell
# Check the configured environment variables
azd env get-values
```

Expected output:

```text
AZURE_ENV_NAME="dev"
AZURE_LOCATION="westus3"
ENTRA_AUDIENCE="api://xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ENTRA_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ENTRA_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Next steps

Once the environment is configured, you can validate and deploy:

### Validation (What-If analysis)

```powershell
# Preview the Bicep template changes
azd provision --preview
```

### Deploy

```powershell
# Deploy the infrastructure and the application
azd up
```

Or individually:

```powershell
# Provision the infrastructure only
azd provision

# Deploy the application only
azd deploy
```

## Troubleshooting

### Error: "insufficient privileges to complete the operation"

Bicep deployments that use the Microsoft Graph extension require Azure AD administrator
privileges. If you do not have them, use **Method 2 (Azure CLI)** instead.

### Error: "AADSTS700016: Application not found"

The service principal may not have been created:

```powershell
az ad sp create --id <clientId>
```

### Environment variables are not applied

Inspect the `.azure/dev/.env` file directly:

```powershell
Get-Content .azure\dev\.env
```

## References

- [Microsoft Entra ID application registration documentation](https://learn.microsoft.com/entra/identity-platform/quickstart-register-app)
- [Azure Developer CLI environment management](https://learn.microsoft.com/azure/developer/azure-developer-cli/manage-environment-variables)
- [ASP.NET Core JWT Bearer authentication](https://learn.microsoft.com/aspnet/core/security/authentication/jwt-authn)
