#!/usr/bin/env pwsh
# Uploads the Markdown SRE knowledge base to an Azure SRE Agent.
#
# The SRE Agent stores operational knowledge in its agent memory. This script
# uploads the Markdown runbooks under data/sre-knowledge/ to the agent's memory
# via the data plane API (POST /api/v1/agentmemory/upload).
#
# Docs: https://learn.microsoft.com/en-us/azure/sre-agent/api-reference
#       https://learn.microsoft.com/en-us/azure/sre-agent/upload-knowledge-document
#
# Usage:
#   ./upload-sre-knowledge.ps1 -ResourceGroup <name> -AgentName <name> `
#       [-SubscriptionId <id>] [-Language en|ja|all]

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$AgentName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("en", "ja", "all")]
    [string]$Language = "en"
)

$ErrorActionPreference = "Stop"

$ApiVersion = "2025-05-01-preview"
$DataPlaneAudience = "https://azuresre.dev"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$KnowledgeDir = Join-Path $RepoRoot "data" "sre-knowledge"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) not found."
    exit 1
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription '$SubscriptionId' (exit $LASTEXITCODE)."
        exit 1
    }
}

# Collect files according to the requested language.
$all = Get-ChildItem -Path $KnowledgeDir -Filter "kb-*.md" -File
switch ($Language) {
    "en"  { $files = $all | Where-Object { $_.Name -notlike "*_ja.md" } }
    "ja"  { $files = $all | Where-Object { $_.Name -like "*_ja.md" } }
    "all" { $files = $all }
}
$files = @($files)

if ($files.Count -eq 0) {
    Write-Error "No knowledge files found in $KnowledgeDir (language=$Language)."
    exit 1
}

Write-Host "=========================================="
Write-Host " SRE Agent knowledge upload"
Write-Host "=========================================="
Write-Host "Resource group : $ResourceGroup"
Write-Host "Agent          : $AgentName"
Write-Host "Language       : $Language"
Write-Host "Files          : $($files.Count)"
Write-Host ""

$sub = if ($SubscriptionId) { $SubscriptionId } else { az account show --query id -o tsv }
$armUrl = "https://management.azure.com/subscriptions/$sub/resourceGroups/$ResourceGroup/providers/Microsoft.App/agents/$AgentName" + "?api-version=$ApiVersion"

Write-Host "[1/3] Resolving agent data plane endpoint..."
$endpoint = az rest -m GET --url $armUrl --query properties.agentEndpoint -o tsv
if (-not $endpoint -or $endpoint -eq "null") {
    Write-Error "Failed to resolve agentEndpoint for '$AgentName'."
    exit 1
}
Write-Host "  Endpoint: $endpoint"

Write-Host "[2/3] Acquiring data plane token..."
$token = az account get-access-token --resource $DataPlaneAudience --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to acquire data plane token."
    exit 1
}

Write-Host "[3/3] Uploading $($files.Count) document(s)..."
$failed = 0
foreach ($f in $files) {
    try {
        $form = @{ file = Get-Item -Path $f.FullName }
        Invoke-RestMethod -Method Post `
            -Uri "$endpoint/api/v1/agentmemory/upload" `
            -Headers @{ Authorization = "Bearer $token" } `
            -Form $form | Out-Null
        Write-Host "  OK  $($f.Name)"
    }
    catch {
        Write-Host "  ERR $($f.Name): $($_.Exception.Message)"
        $failed++
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Error "Completed with $failed failure(s)."
    exit 1
}

Write-Host "Upload complete. Check indexing status with:" -ForegroundColor Green
Write-Host "  az account get-access-token --resource $DataPlaneAudience --query accessToken -o tsv"
Write-Host "  GET $endpoint/api/v1/agentmemory/indexer-status"
