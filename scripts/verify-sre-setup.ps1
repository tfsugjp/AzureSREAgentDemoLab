<#
.SYNOPSIS
    Azure SRE Agent Demo - Verification Script (PowerShell 7)
    Verifies SRE resources are correctly deployed and configured

.PARAMETER ResourceGroup
    Azure Resource Group name (required)

.PARAMETER EnvironmentName
    Environment name (required)

.EXAMPLE
    .\verify-sre-setup.ps1 -ResourceGroup "rg-globalazdemo" -EnvironmentName "sre-demo"
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

$script:Failures = 0

function Add-Failure {
    $script:Failures++
}

Write-Info "Azure SRE Agent Demo - Verification"
Write-Info "Resource Group: $ResourceGroup"
Write-Info "Environment: $EnvironmentName"
Write-Host ""

# Check 1: Log Analytics Workspace
Write-Info "Checking Log Analytics Workspace..."
$logAnalyticsWsName = az monitor log-analytics workspace list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv 2>$null
$logAnalyticsWsId = az monitor log-analytics workspace list `
    --resource-group $ResourceGroup `
    --query "[0].customerId" `
    --output tsv 2>$null

if ([string]::IsNullOrWhiteSpace($logAnalyticsWsName) -or [string]::IsNullOrWhiteSpace($logAnalyticsWsId)) {
    Write-ErrorMessage "No Log Analytics Workspace found"
    Add-Failure
} else {
    Write-Success "Log Analytics Workspace: $logAnalyticsWsName"
}

# Check 2: Application Insights
Write-Info "Checking Application Insights..."
$appInsights = az monitor app-insights component list `
    --resource-group $ResourceGroup `
    --query "[0].name" `
    --output tsv 2>$null

if ([string]::IsNullOrWhiteSpace($appInsights)) {
    Write-ErrorMessage "No Application Insights found"
    Add-Failure
} else {
    Write-Success "Application Insights: $appInsights"
}

# Check 3: Alert Rules
Write-Info "Checking Alert Rules..."
$alertCount = az monitor metrics alert list `
    --resource-group $ResourceGroup `
    --query "length(@)" `
    --output tsv 2>$null

if ($alertCount -eq 0) {
    Write-Warn "No metric alerts found. Deploy the SRE overlay with infra/sre-overlay.bicep"
} else {
    Write-Success "Found $alertCount metric alert(s)"
    $alertData = az monitor metrics alert list `
        --resource-group $ResourceGroup `
        --query "[].[name, properties.severity, properties.enabled]" `
        --output json | ConvertFrom-Json
    
    $alertData | ForEach-Object {
        $status = if ($_[2]) { "Enabled" } else { "Disabled" }
        Write-Host "$($_[0]): Severity=$($_[1]), Status=$status"
    }
}

# Check 4: Action Groups
Write-Info "Checking Action Groups..."
$actionGroup = az monitor action-group list `
    --resource-group $ResourceGroup `
    --query "[?contains(name, 'ag-sre')].name" `
    --output tsv 2>$null | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($actionGroup)) {
    Write-Warn "No SRE Action Group found. Deploy the SRE overlay with infra/sre-overlay.bicep"
    Add-Failure
} else {
    Write-Success "Action Group: $actionGroup"

    try {
        $actionGroupDetails = az monitor action-group show `
            --resource-group $ResourceGroup `
            --name $actionGroup `
            --output json 2>$null | ConvertFrom-Json

        $logicAppReceivers = @($actionGroupDetails.logicAppReceivers)
        if ($logicAppReceivers.Count -eq 0) {
            Write-Warn "Action Group does not contain any Logic App receivers"
        } else {
            foreach ($receiver in $logicAppReceivers) {
                Write-Info "Validating Logic App receiver callback URL for $($receiver.name)..."

                $workflow = az resource show `
                    --ids $receiver.resourceId `
                    --output json 2>$null | ConvertFrom-Json

                $triggerName = $workflow.properties.definition.triggers.PSObject.Properties.Name | Select-Object -First 1
                $expectedCallbackUrl = az rest `
                    --method post `
                    --url "https://management.azure.com$($receiver.resourceId)/triggers/$triggerName/listCallbackUrl?api-version=2019-05-01" `
                    --query value `
                    --output tsv 2>$null

                if ([string]::IsNullOrWhiteSpace($expectedCallbackUrl)) {
                    Write-ErrorMessage "Unable to retrieve the Logic App trigger callback URL for $($receiver.resourceId)"
                    Add-Failure
                } elseif ($receiver.callbackUrl -ne $expectedCallbackUrl) {
                    Write-ErrorMessage "Logic App receiver callback URL does not match the trigger callback URL. Use listCallbackUrl output, not the Logic App overview URL."
                    Add-Failure
                } else {
                    Write-Success "Logic App receiver callback URL matches the trigger callback URL"
                }
            }
        }
    } catch {
        Write-Warn "Unable to validate Logic App receiver callback URL: $($_.Exception.Message)"
        Add-Failure
    }
}

# Check 5: Container Apps
Write-Info "Checking Container Apps..."
$sampleImageUri = "mcr.microsoft.com/dotnet/samples:aspnetapp"
$containerAppsJson = az containerapp list `
    --resource-group $ResourceGroup `
    --query "[].{name:name,provisioning:properties.provisioningState,image:properties.template.containers[0].image}" `
    --output json

try {
    $containerApps = @($containerAppsJson | ConvertFrom-Json)
    
    if ($null -eq $containerApps -or $containerApps.Count -eq 0) {
        Write-ErrorMessage "No Container Apps found"
        Add-Failure
    } else {
        $containerApps | ForEach-Object {
            if ($_.provisioning -eq "Succeeded") {
                Write-Success "$($_.name): Provisioning State = Succeeded"
            } else {
                Write-Warn "$($_.name): Provisioning State = $($_.provisioning)"
                Add-Failure
            }

            if ($_.image -eq $sampleImageUri) {
                Write-ErrorMessage "$($_.name): Still running provisioning placeholder image ($sampleImageUri). Run 'azd deploy' to deploy repository service images."
                Add-Failure
            } else {
                Write-Success "$($_.name): Image = $($_.image)"
            }
        }
    }
} catch {
    Write-Warn "Unable to parse Container Apps list"
    Add-Failure
}

# Check 6: Test query on Log Analytics
Write-Info "Testing Log Analytics queries..."
if (-not [string]::IsNullOrWhiteSpace($logAnalyticsWsId)) {
    try {
        $queryResult = az monitor log-analytics query `
            --workspace $logAnalyticsWsId `
            --analytics-query "AppRequests | where TimeGenerated > ago(1h) | summarize RequestCount = sum(ItemCount)" `
            --output json 2>$null | ConvertFrom-Json

        $requestCount = [int]($queryResult[0][0])
        
        if ($requestCount -gt 0) {
            Write-Success "Log Analytics working ($requestCount requests in last hour)"
        } else {
            Write-Warn "No recent request telemetry in Log Analytics"
        }
    } catch {
        Write-Warn "Unable to query Log Analytics: $($_.Exception.Message)"
    }
}

Write-Host ""
if ($script:Failures -eq 0) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Success "Verification Report"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
} else {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Warn "Verification Report"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
}
Write-Host ""
if ($script:Failures -eq 0) {
    Write-Host "✓ Prerequisites: All Azure resources present"
    Write-Host "✓ Status: SRE Agent demo infrastructure ready"
} else {
    Write-Host "✗ One or more prerequisite checks failed"
    Write-Host "✗ Status: SRE Agent demo infrastructure is not ready"
}
Write-Host ""
Write-Host "To run the demo:"
Write-Host "1. Generate synthetic load:"
Write-Host "   .\trigger-incident-demo.ps1 -Endpoint <order-service-endpoint>"
Write-Host ""
Write-Host "2. Monitor alert status:"
Write-Host "   az monitor metrics alert list --resource-group $ResourceGroup"
Write-Host ""
Write-Host "3. Check the work item or issue in your configured downstream destination"
Write-Host ""
Write-Host "4. See detailed guide: docs/sre-scenario-20min.md"
Write-Host ""

if ($script:Failures -ne 0) {
    exit 1
}
