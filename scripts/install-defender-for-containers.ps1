#requires -Version 7

<#
.SYNOPSIS
    Installs or upgrades the Microsoft Defender for Containers sensor on an AKS cluster via Helm.

.DESCRIPTION
    Deploys the Defender for Containers sensor from the OCI registry to the 'mdc' namespace.
    Use -Upgrade to perform a 'helm upgrade' on an existing installation.

.PARAMETER SubscriptionId
    Azure subscription ID of the AKS cluster.

.PARAMETER ResourceGroup
    Resource group name of the AKS cluster.

.PARAMETER ClusterName
    Name of the AKS cluster.

.PARAMETER Location
    Azure region of the AKS cluster (e.g. japaneast, westus3).

.PARAMETER Version
    Chart version to install. Defaults to 0.11.2.

.PARAMETER Upgrade
    Switch to upgrade an existing installation instead of installing fresh.

.EXAMPLE
    .\install-defender-for-containers.ps1 `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-global-azure-demo" `
        -ClusterName "aks-dev-abc123" `
        -Location "japaneast"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ClusterName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [string]$Version = "0.11.2",

    [switch]$Upgrade
)

$ErrorActionPreference = "Stop"

$OciRegistry = "oci://mcr.microsoft.com/azuredefender-preview/microsoft-defender-for-containers"
$ChartRef    = "${OciRegistry}:${Version}"
$ReleaseName = "defender-k8s"
$Namespace   = "mdc"

Write-Host "=== Microsoft Defender for Containers Helm Deployment ===" -ForegroundColor Cyan
Write-Host "Cluster   : $ClusterName"
Write-Host "Namespace : $Namespace"
Write-Host "Version   : $Version"
Write-Host "Mode      : $(if ($Upgrade) { 'upgrade' } else { 'install' })"
Write-Host ""

$CommonArgs = @(
    "--namespace", $Namespace,
    "--set", "global.cloudIdentifiers.Azure.subscriptionId=$SubscriptionId",
    "--set", "global.cloudIdentifiers.Azure.resourceGroupName=$ResourceGroup",
    "--set", "global.cloudIdentifiers.Azure.clusterName=$ClusterName",
    "--set", "global.cloudIdentifiers.Azure.region=$Location"
)

if ($Upgrade) {
    helm upgrade $ReleaseName $ChartRef @CommonArgs --reuse-values
} else {
    helm install $ReleaseName $ChartRef --create-namespace @CommonArgs
}

Write-Host ""
Write-Host "Verifying deployment..." -ForegroundColor Cyan
helm list --namespace $Namespace
kubectl get pods --namespace $Namespace
