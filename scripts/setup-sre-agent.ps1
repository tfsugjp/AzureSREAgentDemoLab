<#
.SYNOPSIS
    Azure SRE Agent Demo Setup Script (PowerShell 7)
    Validates SRE demo prerequisites and prints the next steps for deploying the Azure relay-backed overlay.

.PARAMETER ResourceGroup
    Azure Resource Group name (required)

.PARAMETER EnvironmentName
    Environment name (required)

.EXAMPLE
    .\setup-sre-agent.ps1 -ResourceGroup "rg-globalazdemo" -EnvironmentName "sre-demo"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$EnvironmentName
)

$ErrorActionPreference = "Stop"

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Main script
Write-Info "Azure SRE Agent Demo Setup"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "Environment: $EnvironmentName"
Write-Host ""

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check Azure CLI
try {
    $azVersion = az version | ConvertFrom-Json | Select-Object -ExpandProperty 'azure-cli'
    Write-Success "Azure CLI found: $azVersion"
} catch {
    Write-ErrorMessage "Azure CLI (az) not found. Please install: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check resource group exists
try {
    $rgExists = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
    if ($null -eq $rgExists) {
        throw "Resource Group not found"
    }
    Write-Success "Resource Group exists: $ResourceGroup"
} catch {
    Write-ErrorMessage "Resource Group '$ResourceGroup' not found"
    exit 1
}

# Check Log Analytics workspace exists
try {
    $logAnalyticsWs = az monitor log-analytics workspace list `
        --resource-group $ResourceGroup `
        --query "[0].name" `
        --output tsv 2>$null

    if ([string]::IsNullOrWhiteSpace($logAnalyticsWs)) {
        throw "No Log Analytics Workspace found"
    }
    Write-Success "Log Analytics Workspace: $logAnalyticsWs"
} catch {
    Write-Warn "No Log Analytics Workspace found. Please deploy infrastructure first."
    exit 1
}

# Check Application Insights exists
try {
    $appInsights = az monitor app-insights component list `
        --resource-group $ResourceGroup `
        --query "[0].name" `
        --output tsv 2>$null

    if ([string]::IsNullOrWhiteSpace($appInsights)) {
        throw "No Application Insights found"
    }
    Write-Success "Application Insights: $appInsights"
} catch {
    Write-Warn "No Application Insights found. Please deploy infrastructure first."
    exit 1
}

# Check Container Apps Environment exists
try {
    $containerAppsEnv = az containerapp env list `
        --resource-group $ResourceGroup `
        --query "[0].name" `
        --output tsv 2>$null

    if ([string]::IsNullOrWhiteSpace($containerAppsEnv)) {
        throw "No Container Apps Environment found"
    }
    Write-Success "Container Apps Environment: $containerAppsEnv"
} catch {
    Write-Warn "No Container Apps Environment found."
    exit 1
}

Write-Host ""
Write-Info "All prerequisites met. Ready for SRE resource deployment."
Write-Host ""

# Output next steps
Write-Success "Setup validation complete!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Create or identify your Logic App / Azure Function relay for incident routing"
Write-Host "   Retrieve the full HTTP trigger callback URL (not the workflow overview URL) before deploying the SRE overlay:"
Write-Host ""
Write-Host "   `$logicAppResourceId = '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Logic/workflows/<logic-app-name>'"
Write-Host "   `$logicAppTriggerName = 'When_an_HTTP_request_is_received'"
Write-Host "   `$logicAppCallbackUrl = az rest --method post --url \"https://management.azure.com`$logicAppResourceId/triggers/`$logicAppTriggerName/listCallbackUrl?api-version=2019-05-01\" --query value --output tsv"
Write-Host ""
Write-Host "2. Deploy the SRE overlay with explicit parameters:"
Write-Host ""
Write-Host "   az deployment group create --resource-group $ResourceGroup --template-file infra/main.bicep --parameters enableSreDemo=true incidentRelayResourceId=<relay-resource-id> incidentRelayCallbackUrl=`$logicAppCallbackUrl responseTimeThresholdMs=500 failedRequestCountThreshold=5"
Write-Host "   The callback URL must contain '/triggers/' and 'sig=' or Azure Monitor will not invoke the Logic App."
Write-Host ""
Write-Host "3. Verify setup with:"
Write-Host "   .\verify-sre-setup.ps1 -ResourceGroup $ResourceGroup -EnvironmentName $EnvironmentName"
Write-Host ""
Write-Host "For more details, see: docs/sre-agent-setup.md"
