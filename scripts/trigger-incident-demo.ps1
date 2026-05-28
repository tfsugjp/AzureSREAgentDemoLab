<#
.SYNOPSIS
    Azure SRE Agent Demo - Incident Trigger Script (PowerShell 7)
    Generates synthetic load to trigger alerts for the SRE Agent demo

.PARAMETER Endpoint
    Order Service workload endpoint URL, for example https://<app>/api/orders (required)

.PARAMETER HealthEndpoint
    Optional health check endpoint. Defaults to <scheme>://<host>/health derived from Endpoint

.PARAMETER Concurrent
    Number of concurrent requests (default: 50)

.PARAMETER Duration
    Test duration in seconds (default: 60)

.PARAMETER Interval
    Interval between batches in seconds (default: 5)

.PARAMETER AccessToken
    Optional Microsoft Entra bearer token used when the API endpoint requires authentication

.PARAMETER ConnectivityTimeoutSec
    Timeout in seconds for warm-up and connectivity probes (default: 15)

.PARAMETER WarmupAttempts
    Number of warm-up attempts against the health endpoint before failing (default: 3)

.EXAMPLE
    .\trigger-incident-demo.ps1 -Endpoint "https://order-service.azurecontainerapps.io/api/orders"

.EXAMPLE
    .\trigger-incident-demo.ps1 -Endpoint "https://order-service.azurecontainerapps.io/api/orders" -AccessToken "<token>"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint,

    [Parameter(Mandatory=$false)]
    [string]$HealthEndpoint,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 500)]
    [int]$Concurrent = 50,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 3600)]
    [int]$Duration = 60,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 300)]
    [int]$Interval = 5,

    [Parameter(Mandatory=$false)]
    [string]$AccessToken = '',

    [Parameter(Mandatory=$false)]
    [ValidateRange(2, 120)]
    [int]$ConnectivityTimeoutSec = 15,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$WarmupAttempts = 3
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

function Get-DerivedHealthEndpoint {
    param([string]$Url)

    try {
        $uri = [Uri]$Url
    } catch {
        throw "Endpoint must be a valid absolute URL. Received: $Url"
    }

    if (-not $uri.IsAbsoluteUri) {
        throw "Endpoint must be a valid absolute URL. Received: $Url"
    }

    $builder = [UriBuilder]::new($uri.Scheme, $uri.Host, $uri.Port)
    $builder.Path = '/health'
    $builder.Query = ''
    $builder.Fragment = ''

    return $builder.Uri.AbsoluteUri.TrimEnd('/')
}

function Get-WarmupEndpoints {
    param(
        [string]$WorkloadUrl,
        [string]$PreferredHealthUrl
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredHealthUrl)) {
        return @($PreferredHealthUrl, $WorkloadUrl) | Select-Object -Unique
    }

    $healthEndpoint = Get-DerivedHealthEndpoint -Url $WorkloadUrl
    $readyEndpoint = "$healthEndpoint/ready"

    return @($healthEndpoint, $readyEndpoint, $WorkloadUrl) | Select-Object -Unique
}

function Get-RequestHeaders {
    param([string]$Token)

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return @{}
    }

    return @{ Authorization = "Bearer $Token" }
}

function Invoke-HttpProbe {
    param(
        [string]$Url,
        [int]$TimeoutSec,
        [hashtable]$Headers
    )

    try {
        $response = Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -TimeoutSec $TimeoutSec `
            -Headers $Headers `
            -SkipHttpErrorCheck `
            -ErrorAction Stop

        return [pscustomobject]@{
            Succeeded = $true
            StatusCode = [int]$response.StatusCode
            ErrorMessage = ''
        }
    } catch {
        return [pscustomobject]@{
            Succeeded = $false
            StatusCode = $null
            ErrorMessage = $_.Exception.Message
        }
    }
}

$resolvedHealthEndpoint = if ([string]::IsNullOrWhiteSpace($HealthEndpoint)) {
    Get-DerivedHealthEndpoint -Url $Endpoint
} else {
    $HealthEndpoint
}

$warmupEndpoints = Get-WarmupEndpoints -WorkloadUrl $Endpoint -PreferredHealthUrl $HealthEndpoint

$requestHeaders = Get-RequestHeaders -Token $AccessToken

# Validate endpoint
Write-Info "Azure SRE Agent Demo - Incident Trigger"
Write-Info "Endpoint: $Endpoint"
Write-Info "Health endpoint: $resolvedHealthEndpoint"
Write-Info "Warm-up candidates: $($warmupEndpoints -join ', ')"
Write-Info "Concurrent requests: $Concurrent"
Write-Info "Total duration: $($Duration)s"
Write-Info "Batch interval: $($Interval)s"
Write-Info "Connectivity timeout: $($ConnectivityTimeoutSec)s"
Write-Info "Bearer token provided: $(if ($requestHeaders.Count -gt 0) { 'yes' } else { 'no' })"
Write-Host ""

Write-Info "Warming up Container App via health endpoint..."
$healthReady = $false

:warmupLoop for ($attempt = 1; $attempt -le $WarmupAttempts; $attempt++) {
    foreach ($warmupEndpoint in $warmupEndpoints) {
        $headers = if ($warmupEndpoint -eq $Endpoint) { $requestHeaders } else { @{} }
        $healthProbe = Invoke-HttpProbe -Url $warmupEndpoint -TimeoutSec $ConnectivityTimeoutSec -Headers $headers

        if ($healthProbe.Succeeded -and $healthProbe.StatusCode -ge 200 -and $healthProbe.StatusCode -lt 400) {
            Write-Success "Warm-up endpoint reachable on attempt ${attempt}: $warmupEndpoint"
            $healthReady = $true
            break warmupLoop
        }

        if ($warmupEndpoint -eq $Endpoint -and $healthProbe.Succeeded -and $healthProbe.StatusCode -in 401, 403) {
            Write-Warn "Warm-up reached workload endpoint on attempt $attempt but authentication is required (HTTP $($healthProbe.StatusCode))."
            $healthReady = $true
            break warmupLoop
        }

        if ($healthProbe.Succeeded) {
            Write-Warn "Warm-up endpoint $warmupEndpoint returned HTTP $($healthProbe.StatusCode) on attempt $attempt/$WarmupAttempts"
        } else {
            Write-Warn "Warm-up probe $warmupEndpoint failed on attempt $attempt/${WarmupAttempts}: $($healthProbe.ErrorMessage)"
        }
    }
}

if (-not $healthReady) {
    Write-ErrorMessage "Cannot warm up Container App using any candidate endpoint."
    Write-ErrorMessage "Candidates tried: $($warmupEndpoints -join ', ')"
    Write-ErrorMessage "Try supplying -HealthEndpoint explicitly, checking the deployed app routes, or increasing -ConnectivityTimeoutSec."
    exit 1
}

Write-Info "Probing workload endpoint before starting load..."
$endpointProbe = Invoke-HttpProbe -Url $Endpoint -TimeoutSec $ConnectivityTimeoutSec -Headers $requestHeaders

if ($endpointProbe.Succeeded) {
    if ($endpointProbe.StatusCode -ge 200 -and $endpointProbe.StatusCode -lt 400) {
        Write-Success "Workload endpoint reachable"
    } elseif ($endpointProbe.StatusCode -in 401, 403) {
        Write-ErrorMessage "Workload endpoint returned HTTP $($endpointProbe.StatusCode). Authentication is enabled for /api/orders."
        Write-ErrorMessage "Provide -AccessToken or redeploy with disableAuthentication=true for workshop scenarios."
        exit 1
    } elseif ($endpointProbe.StatusCode -eq 404) {
        Write-ErrorMessage "Workload endpoint returned HTTP 404. Confirm the endpoint path is correct, for example /api/orders."
        exit 1
    } else {
        Write-Warn "Workload endpoint returned HTTP $($endpointProbe.StatusCode). Continuing because the app is reachable and the load test may still be useful."
    }
} else {
    Write-Warn "Workload probe failed before the load test: $($endpointProbe.ErrorMessage)"
    Write-Warn "Continuing because the health endpoint is reachable and the app may still be cold-starting."
}

Write-Info "Starting synthetic load test..."
Write-Info "⏱ This will generate high request volume to trigger alerts"
Write-Host ""

function Invoke-SequentialRequests {
    param([int]$Count)

    for ($requestNumber = 1; $requestNumber -le $Count; $requestNumber++) {
        try {
            Invoke-WebRequest `
                -Uri $Endpoint `
                -UseBasicParsing `
                -TimeoutSec 30 `
                -Headers $requestHeaders `
                -SkipHttpErrorCheck `
                -ErrorAction Stop | Out-Null
        } catch {
            # Ignore errors during load test
        }
    }
}

$script:CanUseBackgroundJobs = "$($ExecutionContext.SessionState.LanguageMode)" -eq 'FullLanguage'
$script:ReportedSequentialFallback = $false

if (-not $script:CanUseBackgroundJobs) {
    Write-Warn "This PowerShell session does not allow Start-Job. Falling back to sequential requests per batch."
    $script:ReportedSequentialFallback = $true
}

function Send-Requests {
    param([int]$Count)

    if (-not $script:CanUseBackgroundJobs) {
        Invoke-SequentialRequests -Count $Count
        return
    }

    $jobs = @()

    try {
        for ($i = 1; $i -le $Count; $i++) {
            $job = Start-Job -ErrorAction Stop -ScriptBlock {
                param($url, $headers)
                try {
                    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -Headers $headers -SkipHttpErrorCheck -ErrorAction Stop | Out-Null
                } catch {
                    # Ignore errors during load test
                }
            } -ArgumentList $Endpoint, $requestHeaders

            $jobs += $job
        }

        if ($jobs.Count -gt 0) {
            $jobs | Wait-Job | Receive-Job -ErrorAction SilentlyContinue | Out-Null
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    } catch {
        if ($jobs.Count -gt 0) {
            $jobs | Stop-Job -ErrorAction SilentlyContinue
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }

        $script:CanUseBackgroundJobs = $false

        if (-not $script:ReportedSequentialFallback) {
            Write-Warn "Background jobs are unavailable in this PowerShell session. Falling back to sequential requests for the remaining load test."
            $script:ReportedSequentialFallback = $true
        }

        Invoke-SequentialRequests -Count $Count
    }
}

# Calculate number of iterations
$iterations = [math]::Ceiling($Duration / $Interval)
$startTime = Get-Date

# Send load
for ($i = 1; $i -le $iterations; $i++) {
    $elapsed = [math]::Min(($i * $Interval), $Duration)
    $percent = [math]::Min([math]::Floor(($elapsed * 100) / $Duration), 100)
    
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
Write-Info "3. Check the work item or issue in your configured downstream destination"
Write-Info "4. Run: .\verify-sre-setup.ps1 to check alert status"
