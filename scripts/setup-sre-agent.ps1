<#
.SYNOPSIS
    Azure SRE Agent Demo Setup Script (PowerShell 7)
    Configures SRE resources including alerts, action groups, and Azure DevOps integration.

.PARAMETER ResourceGroup
    Azure Resource Group name (required)

.PARAMETER EnvironmentName
    Environment name (required)

.PARAMETER DevOpsOrgUrl
    Azure DevOps Organization URL (required)

.PARAMETER DevOpsProject
    Azure DevOps Project name (default: SRE-Demo)

.PARAMETER Location
    Azure region (default: westus3)

.EXAMPLE
    .\setup-sre-agent.ps1 -ResourceGroup "rg-globalazdemo" -EnvironmentName "sre-demo" -DevOpsOrgUrl "https://dev.azure.com/myorg"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$EnvironmentName,

    [Parameter(Mandatory=$true)]
    [string]$DevOpsOrgUrl,

    [Parameter(Mandatory=$false)]
    [string]$DevOpsProject = "SRE-Demo",

    [Parameter(Mandatory=$false)]
    [string]$Location = "westus3"
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

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Main script
Write-Info "Azure SRE Agent Demo Setup"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "Environment: $EnvironmentName"
Write-Info "DevOps Org: $DevOpsOrgUrl"
Write-Info "DevOps Project: $DevOpsProject"
Write-Host ""

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check Azure CLI
try {
    $azVersion = az version | ConvertFrom-Json | Select-Object -ExpandProperty 'azure-cli'
    Write-Success "Azure CLI found: $azVersion"
} catch {
    Write-Error "Azure CLI (az) not found. Please install: https://learn.microsoft.com/cli/azure/install-azure-cli"
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
    Write-Error "Resource Group '$ResourceGroup' not found"
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
Write-Host "1. Update infra/main.parameters.json with SRE parameters:"
Write-Host "   - enableSreDemo: true"
Write-Host "   - azureDevOpsOrgUrl: $DevOpsOrgUrl"
Write-Host "   - azureDevOpsProjectName: $DevOpsProject"
Write-Host ""
Write-Host "2. Deploy with azd:"
Write-Host "   azd env set enableSreDemo true"
Write-Host "   azd env set azureDevOpsOrgUrl `"$DevOpsOrgUrl`""
Write-Host "   azd env set azureDevOpsProjectName `"$DevOpsProject`""
Write-Host "   azd up"
Write-Host ""
Write-Host "3. Verify setup with:"
Write-Host "   .\verify-sre-setup.ps1 -ResourceGroup $ResourceGroup -EnvironmentName $EnvironmentName"
Write-Host ""
Write-Host "For more details, see: docs/sre-agent-setup.md"
