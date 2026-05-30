#!/usr/bin/env pwsh
# Decommissions any Azure AI Search service in a resource group.
#
# The SRE Agent no longer uses Azure AI Search. This script removes previously
# deployed Microsoft.Search/searchServices resources. It is idempotent: when no
# search service exists, it exits successfully without making changes.
#
# Usage:
#   ./remove-ai-search.ps1 -ResourceGroup <name> [-SubscriptionId <id>] [-Yes]

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",

    [Parameter(Mandatory = $false)]
    [switch]$Yes
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) not found. Install: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription '$SubscriptionId' (exit $LASTEXITCODE)."
        exit 1
    }
}

Write-Host "=== Azure AI Search decommission ===" -ForegroundColor Cyan
Write-Host "Resource group : $ResourceGroup"
Write-Host ""

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Resource group '$ResourceGroup' not found. Nothing to do."
    exit 0
}

$searchServices = az resource list `
    --resource-group $ResourceGroup `
    --resource-type "Microsoft.Search/searchServices" `
    --query "[].name" -o tsv

$searchServices = @($searchServices | Where-Object { $_ -and $_.Trim() -ne "" })

if ($searchServices.Count -eq 0) {
    Write-Host "No Azure AI Search service found in '$ResourceGroup'. Nothing to do."
    exit 0
}

Write-Host "Found $($searchServices.Count) AI Search service(s):"
foreach ($name in $searchServices) {
    Write-Host "  - $name"
}
Write-Host ""

if (-not $Yes) {
    $reply = Read-Host "Delete the listed AI Search service(s)? [y/N]"
    if ($reply -notmatch '^[Yy]$') {
        Write-Host "Aborted. No resources were deleted."
        exit 0
    }
}

foreach ($name in $searchServices) {
    Write-Host "Deleting '$name'..."
    az resource delete `
        --resource-group $ResourceGroup `
        --resource-type "Microsoft.Search/searchServices" `
        --name $name
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to delete '$name' (exit $LASTEXITCODE)."
        exit 1
    }
    Write-Host "  Deleted '$name'."
}

Write-Host ""
Write-Host "AI Search decommission complete." -ForegroundColor Green
