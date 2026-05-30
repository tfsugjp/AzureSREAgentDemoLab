#requires -Version 7

param(
    [Parameter(Mandatory = $true)]
    [string]$AcrName
)

$ErrorActionPreference = "Stop"
$Namespace = "azure-sre-agent-demo-lab"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ManifestDir = Join-Path $RepoRoot "k8s"

$TmpDir = Join-Path $env:TEMP ("aks-acr-render-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TmpDir | Out-Null

$ManifestNames = @(
    "catalog-service.yaml",
    "order-service.yaml",
    "notification-service.yaml"
)

try {
    foreach ($name in $ManifestNames) {
        $source = Join-Path $ManifestDir $name
        $target = Join-Path $TmpDir $name
        (Get-Content -Raw -Path $source).Replace("<ACR_NAME>", $AcrName) | Set-Content -Path $target
    }

    kubectl apply -f (Join-Path $ManifestDir "namespace.yaml")

    foreach ($name in $ManifestNames) {
        kubectl apply -f (Join-Path $TmpDir $name)
    }

    kubectl -n $Namespace rollout status deployment/catalog-service --timeout=300s
    kubectl -n $Namespace rollout status deployment/order-service --timeout=300s
    kubectl -n $Namespace rollout status deployment/notification-service --timeout=300s

    kubectl -n $Namespace get deploy
    kubectl -n $Namespace get pods -o wide
}
finally {
    if (Test-Path $TmpDir) {
        Remove-Item -Recurse -Force $TmpDir
    }
}
