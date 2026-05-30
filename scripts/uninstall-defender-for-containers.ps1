#!/usr/bin/env pwsh
# Uninstalls the Microsoft Defender for Containers sensor from an AKS cluster.
#
# This removes a previously installed Defender sensor Helm release and its
# namespace. It is idempotent: when the release or namespace is absent it
# completes without error.
#
# Usage:
#   ./uninstall-defender-for-containers.ps1 -SubscriptionId <id> -ResourceGroup <rg> -ClusterName <name>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName
)

$ErrorActionPreference = "Stop"

$ReleaseName = "defender-k8s"
$Namespace = "mdc"

foreach ($tool in @("az", "helm", "kubectl")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "$tool not found."
        exit 1
    }
}

Write-Host "=== Microsoft Defender for Containers uninstall ===" -ForegroundColor Cyan
Write-Host "Cluster   : $ClusterName"
Write-Host "Namespace : $Namespace"
Write-Host ""

Write-Host "Configuring Azure subscription and AKS credentials..."
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription '$SubscriptionId' (exit $LASTEXITCODE)."
    exit 1
}
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get AKS credentials for '$ClusterName' (exit $LASTEXITCODE)."
    exit 1
}

helm status $ReleaseName --namespace $Namespace *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Uninstalling Helm release '$ReleaseName'..."
    helm uninstall $ReleaseName --namespace $Namespace
}
else {
    Write-Host "Helm release '$ReleaseName' not found in namespace '$Namespace'. Skipping."
}

kubectl get namespace $Namespace *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting namespace '$Namespace'..."
    kubectl delete namespace $Namespace --wait=false
}
else {
    Write-Host "Namespace '$Namespace' not found. Skipping."
}

Write-Host ""
Write-Host "Defender for Containers uninstall complete." -ForegroundColor Green
