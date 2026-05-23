<#
.SYNOPSIS
    Azure SRE Agent Demo - Incident Trigger Script (PowerShell 7)
    Generates synthetic load to trigger alerts for the SRE Agent demo

.PARAMETER Endpoint
    Order Service endpoint URL (required)

.PARAMETER Concurrent
    Number of concurrent requests (default: 50)

.PARAMETER Duration
    Test duration in seconds (default: 60)

.PARAMETER Interval
    Interval between batches in seconds (default: 5)

.EXAMPLE
    .\trigger-incident-demo.ps1 -Endpoint "https://order-service.azurecontainerapps.io/api/orders"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint,

    [Parameter(Mandatory=$false)]
    [int]$Concurrent = 50,

    [Parameter(Mandatory=$false)]
    [int]$Duration = 60,

    [Parameter(Mandatory=$false)]
    [int]$Interval = 5
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

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Validate endpoint
Write-Info "Azure SRE Agent Demo - Incident Trigger"
Write-Info "Endpoint: $Endpoint"
Write-Info "Concurrent requests: $Concurrent"
Write-Info "Total duration: $($Duration)s"
Write-Info "Batch interval: $($Interval)s"
Write-Host ""

Write-Info "Testing endpoint connectivity..."
try {
    $null = Invoke-WebRequest -Uri $Endpoint -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
    Write-Success "Endpoint reachable"
} catch {
    Write-Error "Cannot reach endpoint: $Endpoint"
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}

Write-Info "Starting synthetic load test..."
Write-Info "⏱ This will generate high request volume to trigger alerts"
Write-Host ""

function Send-Requests {
    param([int]$Count)
    
    $jobs = @()
    
    for ($i = 1; $i -le $Count; $i++) {
        $job = Start-Job -ScriptBlock {
            param($url)
            try {
                Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop | Out-Null
            } catch {
                # Ignore errors during load test
            }
        } -ArgumentList $Endpoint
        
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    $jobs | Wait-Job | Remove-Job
}

# Calculate number of iterations
$iterations = [math]::Ceiling($Duration / $Interval)
$startTime = Get-Date

# Send load
for ($i = 1; $i -le $iterations; $i++) {
    $elapsed = ($i * $Interval)
    $percent = [math]::Floor(($elapsed * 100) / $Duration)
    
    Write-Host "`r📊 Progress: $($percent)% ($($elapsed)s / $($Duration)s) - Sending $Concurrent requests..." -NoNewline
    
    Send-Requests -Count $Concurrent
    
    if ($i -lt $iterations) {
        Start-Sleep -Seconds $Interval
    }
}

$endTime = Get-Date
$actualDuration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host ""
Write-Success "Load test complete!"
Write-Host ""
Write-Info "Actual duration: $([math]::Round($actualDuration))s"
Write-Info "Total requests sent: approximately $($Concurrent * $iterations)"
Write-Info "Expected latency spike should appear in Application Insights within 2-3 minutes"
Write-Host ""
Write-Info "Next steps:"
Write-Info "1. Wait 2-3 minutes for metrics to be ingested"
Write-Info "2. Check Azure Monitor Alerts: az monitor metrics alert list"
Write-Info "3. Check Azure DevOps for work item"
Write-Info "4. Run: .\verify-sre-setup.ps1 to check alert status"
