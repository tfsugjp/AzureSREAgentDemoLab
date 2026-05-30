# Azure SRE Agent 20-Minute Demo Scenario

This is an **executable, time-boxed scenario** demonstrating how Azure SRE Agent detects incidents, opens a downstream ticket in your configured destination through an Azure relay, and suggests resolutions using memory and reasoning.

**Total Duration: 20 minutes**

---

## Scenario Overview

**Story**: A production incident has been detected in the Order Service. High latency is detected by Azure Monitor, which forwards the alert to your configured Logic App or Azure Function relay. That relay creates an incident record in Azure DevOps, a GitHub issue, or both. The SRE Agent investigates the incident using telemetry data and runbook knowledge, then recommends a resolution.

**Expected Flow**:
1. Trigger incident (simulate traffic) — **2 min**
2. Alert detection and ticket creation — **3 min**
3. SRE Agent investigation — **8 min**
4. Resolution and verification — **7 min**

---

## Prerequisites

✅ Completed setup from [sre-agent-setup.md](./sre-agent-setup.md)

Required:
- Azure CLI with access to your resource group
- `curl` or `http` CLI tool (for generating load)
- Azure DevOps account with access to `SRE-Demo` project if you use the Azure DevOps route
- GitHub repository access if you use the GitHub route
- Logic App or Azure Function relay configured for the downstream ticket destination you want to demo
- SRE Agent instance configured and running

### Choose Your Ticket Destination

| Route | What you verify in Phase 2 |
|---|---|
| Azure DevOps only | Azure DevOps work item |
| GitHub only | GitHub issue |
| Azure DevOps + GitHub | Both tickets created from the same alert |

---

## Phase 1: Trigger Incident (2 minutes)

### 1.1 Generate Synthetic Load on Order Service

Start by generating traffic that will spike metrics. This simulates real user load that exceeds SLA thresholds.

**Bash:**
```bash
export ORDER_SERVICE_ENDPOINT="https://<your-order-service-endpoint>/api/orders"
export CONCURRENT_REQUESTS=50
export DURATION_SECONDS=60

# Function to send requests
send_requests() {
  for i in $(seq 1 $CONCURRENT_REQUESTS); do
    curl -s -X GET "$ORDER_SERVICE_ENDPOINT" &
  done
  wait
}

# Run for 60 seconds
echo "Generating synthetic load on Order Service..."
for i in $(seq 1 12); do
  send_requests
  sleep 5
done
echo "✅ Load test complete"
```

**PowerShell 7:**
```powershell
$orderServiceEndpoint = "https://<your-order-service-endpoint>/api/orders"
$concurrentRequests = 50
$durationSeconds = 60

function Send-Requests {
  $jobs = @()
  for ($i = 1; $i -le $concurrentRequests; $i++) {
    $job = Start-Job -ScriptBlock {
      param($url)
      try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 | Out-Null
      } catch {
        # Ignore errors
      }
    } -ArgumentList $orderServiceEndpoint
    $jobs += $job
  }
  $jobs | Wait-Job | Remove-Job
}

Write-Host "Generating synthetic load on Order Service..."
for ($i = 1; $i -le 12; $i++) {
  Send-Requests
  Start-Sleep -Seconds 5
}
Write-Host "✅ Load test complete"
```

**Expected Result**: 
- Order Service starts seeing increased response times
- Application Insights metrics show latency spike
- Metrics appear in Log Analytics within 1-2 minutes

### 1.2 Verify Metrics Are Being Recorded

Check that Application Insights is recording the increased traffic:

> [!IMPORTANT]
> Run these KQL queries from the **Application Insights** resource or the **Log Analytics Workspace** Logs experience.
> If you open **Logs** from an individual **Container App** resource, the application telemetry tables used below (`AppRequests`, `AppExceptions`, `AppDependencies`) might not be in scope.

#### Application Insights / Log Analytics query

**Bash:**

```bash
export LOG_ANALYTICS_WS_ID=$(az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].customerId" \
  --output tsv)
export RESOURCE_GROUP="<your-resource-group>"

# Query last 5 minutes of request metrics
az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS_ID \
  --analytics-query "
    AppRequests
    | where TimeGenerated > ago(5m)
    | summarize AvgDurationMs = avg(DurationMs), Count = sum(ItemCount) by Name
    | top 10 by Count desc
  " \
  --resource-group $RESOURCE_GROUP
```

**PowerShell 7:**

```powershell
$resourceGroup = "<your-resource-group>"
$logAnalyticsWsId = az monitor log-analytics workspace list `
  --resource-group $resourceGroup `
  --query "[0].customerId" `
  --output tsv

$query = @"
AppRequests
| where TimeGenerated > ago(5m)
| summarize AvgDurationMs = avg(DurationMs), Count = sum(ItemCount) by Name
| top 10 by Count desc
"@

az monitor log-analytics query `
  --workspace $logAnalyticsWsId `
  --analytics-query $query `
  --resource-group $resourceGroup
```

#### Container App Logs query

Use Container App Logs when you want stdout/stderr output or platform events rather than request telemetry.

```kusto
ContainerAppConsoleLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ContainerName, Stream, Log
| order by TimeGenerated desc
```

```kusto
ContainerAppSystemLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ReplicaName, Reason, Log
| order by TimeGenerated desc
```

> [!NOTE]
> In some environments or older views, you might see `ContainerAppConsoleLogs_CL` / `ContainerAppSystemLogs_CL` instead. If so, use the table names and suffixed column names shown in that workspace.

---

## Phase 2: Alert Detection & Ticket Creation (3 minutes)

### 2.1 Monitor Alert Rule Status

The alert rule from the infrastructure should now be evaluating against the metrics. Check its status:

**Bash:**
```bash
export ALERT_RULE_NAME=$(az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')].name | [0]" \
  --output tsv)

export SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# List all alert rules
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')]" \
  --output table

# Check recent alert instances from Alerts Management
az rest \
  --method get \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&\$filter=targetResourceGroup%20eq%20%27${RESOURCE_GROUP}%27" \
  --output json | jq '[.value[] | select(.properties.essentials.alertRule | endswith("/" + $ruleName))][0:5]' --arg ruleName "$ALERT_RULE_NAME"
```

**PowerShell 7:**
```powershell
$alertRuleName = az monitor metrics alert list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[?contains(name, 'high-latency')].name | [0]" `
  --output tsv

$subscriptionId = az account show --query id --output tsv
$alertsUrl = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.AlertsManagement/alerts?api-version=2019-03-01&`$filter=targetResourceGroup%20eq%20%27$($env:RESOURCE_GROUP)%27"

# List all alert rules
az monitor metrics alert list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[?contains(name, 'high-latency')]" `
  --output table

# Check recent alert instances from Alerts Management
$alerts = az rest `
  --method get `
  --url $alertsUrl `
  --output json | ConvertFrom-Json

$alerts.value |
  Where-Object { $_.properties.essentials.alertRule -like "*/$alertRuleName" } |
  Select-Object -First 5 `
    name,
    @{Name='MonitorCondition';Expression={$_.properties.essentials.monitorCondition}},
    @{Name='AlertState';Expression={$_.properties.essentials.alertState}},
    @{Name='StartDateTime';Expression={$_.properties.essentials.startDateTime}},
    @{Name='Severity';Expression={$_.properties.essentials.severity}}
```

**Expected Output**:
```
Alert Rule Status: Fired
Last Triggered: <timestamp>
Severity: 2 (Warning)
```

If `$ALERT_RULE_NAME` or `$alertRuleName` is empty, verify that the SRE overlay deployment completed successfully before checking history.

### 2.2 Verify the Ticket Was Created

The Action Group should have triggered your Azure-native relay and created the downstream ticket selected for the demo.

The exact destination depends on how your relay is configured. The Bicep overlay wires Azure Monitor to the relay, but the relay implementation decides whether it creates an Azure DevOps work item, a GitHub issue, or both.

#### Option A: Azure DevOps

1. Navigate to **Azure DevOps -> SRE-Demo Project -> Boards**
2. Look for a new **Bug** or **Task** with a title like:
   - `[SRE] High latency detected in Order Service`
   - `[SRE] Server response time exceeded threshold`
3. Confirm it includes alert rule, threshold, current value, impacted service, and portal links

#### Option B: GitHub

1. Navigate to **GitHub -> tfsugjp/AzureSREAgentDemoLab -> Issues**
2. Look for a new issue with a title like:
   - `[SRE] High latency detected in Order Service`
   - `[SRE] Server response time exceeded threshold`
3. Confirm it includes labels such as `sre-agent-demo`, `incident`, and `azure-monitor`

#### Option C: Azure DevOps + GitHub

Verify that both of the above records were created from the same alert and that they share the same alert ID or correlation reference.

**Expected Result**:
- Ticket created within 1-2 minutes of alert firing
- Contains full alert context
- Ready for SRE Agent investigation

**If no ticket appears**:
- Check the Action Group receiver configuration
- Verify the Logic App receiver callback URL matches the trigger `listCallbackUrl` output and still contains `/triggers/` and `sig=`
- Check the Logic App or Azure Function run history
- Verify the relay implementation is configured for the destination you selected; an Azure DevOps-only workflow will not create a GitHub issue
- Verify Azure DevOps or GitHub credentials in the relay

---

## Phase 3: SRE Agent Investigation (8 minutes)

### 3.1 SRE Agent Reads the Incident Record

The SRE Agent reads the newly created work item, issue, or both and begins investigation:

```
SRE Agent Task:
1. Read incident ticket from Azure DevOps, GitHub, or both
2. Extract alert context (metric, threshold, service)
3. Query Log Analytics for supporting data
4. Access Memory/Runbooks
5. Perform reasoning to suggest root cause
```

### 3.2 Agent Queries Telemetry Data

The SRE Agent should execute the following queries via Log Analytics:

> [!IMPORTANT]
> Use these queries from **Application Insights** or **Log Analytics Workspace** Logs, not from the resource-scoped **Container App** Logs blade.

#### Query 1: Performance Timeline

```kusto
AppRequests
| where TimeGenerated > ago(15m)
| where Name contains "orders"
| summarize 
    AvgDurationMs = avg(DurationMs),
    P95DurationMs = percentile(DurationMs, 95),
    P99DurationMs = percentile(DurationMs, 99),
    FailureRate = 100.0 * countif(Success == false) / count()
  by bin(TimeGenerated, 1m)
| render timechart
```

#### Query 2: Error Analysis

```kusto
AppExceptions
| where TimeGenerated > ago(15m)
| summarize Count = sum(ItemCount) by ExceptionType, OuterMessage
| top 10 by Count desc
```

#### Query 3: Dependency Performance

```kusto
AppDependencies
| where TimeGenerated > ago(15m)
| where Target contains "cosmos"
| summarize 
    AvgDurationMs = avg(DurationMs),
    FailureRate = 100.0 * countif(Success == false) / count()
  by DependencyType, Target
```

#### Supporting queries from Container App Logs

Use these when you need application stdout/stderr or platform-level revision events from the **Container App** Logs blade.

```kusto
ContainerAppConsoleLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ContainerName, Stream, Log
| order by TimeGenerated desc
```

```kusto
ContainerAppSystemLogs
| where TimeGenerated > ago(15m)
| where ContainerAppName contains "ord"
| project TimeGenerated, ContainerAppName, RevisionName, ReplicaName, Reason, Log
| order by TimeGenerated desc
```

**Expected Findings**:
- High latency correlates with increased request volume
- Cosmos DB queries show P99 latency spike
- Error rate may be elevated but not critical
- No CPU memory exhaustion detected

### 3.3 Agent Consults Runbooks from Memory

The SRE Agent accesses the **"High Response Time"** runbook from its knowledge base:

```
Runbook: High Response Time
Trigger: Response Time > 500ms for 5 minutes ✅ MATCHED

Investigation:
  ✅ Container App CPU/Memory: Within normal range (70%)
  ✅ Cosmos DB throughput: 1000 RU, capacity: 2000 RU available
  🔸 Request volume: Increased 400% from baseline

Root Cause Analysis:
  Primary: High request volume (synthetic load test)
  Secondary: Cosmos DB indexes optimized for lower volume
  
Recommended Resolution:
  1. Scale Order Service to 3 replicas (currently 1)
  2. Monitor response time for 5 minutes
  3. If issue persists, add index on order status
```

### 3.4 Agent Uses Reasoning to Rank Solutions

The SRE Agent uses **Agent Reasoning** to evaluate solutions:

```
Reasoning Output:

Incident: "High latency in Order Service"

Context Analysis:
- Alert: Response time > 500ms (confirmed)
- Service: Order Service (catalog → order → cosmos call chain)
- Timeframe: Last 10 minutes
- Concurrent Requests: +400% vs. baseline

Root Cause Ranking:
  1. 🥇 High Request Volume + Single Replica (confidence: 95%)
     - Evidence: Load test correlates with latency spike
     - Fix: Scale to 3 replicas
     - Est. Impact: Response time → 200ms
  
  2. 🥈 Missing DB Index (confidence: 65%)
     - Evidence: Cosmos DB latency increased 30%
     - Fix: Add index on orders.status
     - Est. Impact: Query latency → 50ms improvement
  
  3. 🥉 Network Latency (confidence: 30%)
     - Evidence: Minimal change in network metrics
     - Fix: Review container app placement
     - Est. Impact: Unknown

Recommended Action:
  Execute Fix #1 (scale replicas) immediately
  Monitor for 5 minutes
  If unresolved, execute Fix #2 (add index)
```

---

## Phase 4: Resolution and Verification (7 minutes)

### 4.1 SRE Agent Suggests Action Items

Based on reasoning, the SRE Agent adds a comment to the work item, issue, or both:

```
Comment from SRE Agent:

🤖 Automated Investigation Complete

Root Cause: High request volume (400% spike) exceeding current capacity
Evidence:
  - Request count: 1,500 req/min (baseline: 300 req/min)
  - Response time: 750ms avg (threshold: 500ms)
  - Cosmos DB throughput: 75% utilized (2,000 RU available)

Recommended Resolution:
  1. Scale Order Service from 1 to 3 replicas
     - Command: kubectl scale deployment order-service --replicas=3
     - Expected Impact: 3x concurrency handling, ~200ms response time

  2. Monitor for 5 minutes
     - Watch Application Insights dashboard
     - Check response time percentiles (P95, P99)

  3. If issue persists:
     - Add database index on orders.userId, orders.status
     - Restart instances to apply changes

Confidence: 95%
Severity: 2 (Warning) → 1 (Resolved after scaling)
```

### 4.2 Manual Resolution by Engineer

In this demo, you (the engineer) execute the SRE Agent's recommendations:

**Option A: Scale via Azure CLI**

**Bash:**
```bash
# Get the Order Service Container App name
export ORDER_CA=$(az containerapp list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'order')].name" \
  --output tsv)

# Scale to 3 replicas
az containerapp revision list \
  --resource-group $RESOURCE_GROUP \
  --name $ORDER_CA \
  --query "[0].name" --output tsv | xargs -I {} \
  az containerapp update \
    --resource-group $RESOURCE_GROUP \
    --name $ORDER_CA \
    --min-replicas 3 \
    --max-replicas 3

echo "✅ Order Service scaled to 3 replicas"
```

**PowerShell 7:**
```powershell
# Get the Order Service Container App name
$orderCa = az containerapp list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[?contains(name, 'order')].name" `
  --output tsv

# Update replicas
az containerapp update `
  --resource-group $env:RESOURCE_GROUP `
  --name $orderCa `
  --min-replicas 3 `
  --max-replicas 3

Write-Host "✅ Order Service scaled to 3 replicas"
```

### 4.3 Verify Resolution

Run these commands to confirm the incident is resolved:

**Bash:**
```bash
# Check Container App status
az containerapp show \
  --resource-group $RESOURCE_GROUP \
  --name $ORDER_CA \
  --query "properties.template.scale" --output json

# Query current response times (should improve)
LOG_ANALYTICS_WS_ID=$(az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].customerId" \
  --output tsv)

az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS_ID \
  --analytics-query "
    AppRequests
    | where TimeGenerated > ago(5m) and Name contains 'orders'
    | summarize AvgDurationMs = avg(DurationMs), P95DurationMs = percentile(DurationMs, 95)
  " \
  --resource-group $RESOURCE_GROUP

echo "✅ Response time should be < 300ms now"
```

**PowerShell 7:**
```powershell
# Check Container App status
az containerapp show `
  --resource-group $env:RESOURCE_GROUP `
  --name $orderCa `
  --query "properties.template.scale" --output json

# Query current response times
$logAnalyticsWsId = az monitor log-analytics workspace list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[0].customerId" `
  --output tsv

$query = @"
AppRequests
| where TimeGenerated > ago(5m) and Name contains 'orders'
| summarize AvgDurationMs = avg(DurationMs), P95DurationMs = percentile(DurationMs, 95)
"@

az monitor log-analytics query `
  --workspace $logAnalyticsWsId `
  --analytics-query $query `
  --resource-group $env:RESOURCE_GROUP

Write-Host "✅ Response time should be < 300ms now"
```

### 4.4 Update the Ticket Status

Update the downstream record you chose for the demo:

#### Azure DevOps

1. Open the work item in **SRE-Demo**
2. Change status from **To Do** to **Done**
3. Add a resolution comment with the scaling change and the improved latency

#### GitHub

1. Open the incident issue
2. Add a comment with the scaling change and the improved latency
3. Close the issue

#### Azure DevOps + GitHub

Update both records and include a cross-link between them if your relay created them separately

---

## Demo Completion Checklist

✅ **Phase 1**: Synthetic load generated
- Command executed successfully
- Metrics visible in Application Insights

✅ **Phase 2**: Alert detected and downstream ticket created
- Alert rule status shows "Fired"
- Ticket visible in the selected destination

✅ **Phase 3**: SRE Agent investigated incident
- Agent queried Log Analytics
- Agent accessed Memory/Runbooks
- Agent performed reasoning analysis
- Comment with recommendations posted to work item

✅ **Phase 4**: Resolution verified
- Service scaled to 3 replicas
- Response time improved to < 300ms
- Work item marked as Done
- No new alerts firing

---

## Time Breakdown

| Phase | Duration | Task |
|-------|----------|------|
| 1 | 2 min | Generate synthetic load |
| 2 | 3 min | Wait for alert + verify work item |
| 3 | 8 min | SRE Agent investigation + reasoning |
| 4 | 7 min | Execute fix + verification |
| **Total** | **20 min** | **Complete incident cycle** |

---

## Key Learnings

1. **Observability Foundation**: OpenTelemetry, Application Insights, Log Analytics detect issues quickly
2. **Incident Response Automation**: Azure Monitor alerts can open Azure DevOps work items, GitHub issues, or both
3. **Agent Memory**: SRE Agent runbooks provide consistent, documented response procedures
4. **Agent Reasoning**: Correlating metrics with runbooks suggests accurate root causes
5. **Feedback Loop**: Work item status and comments improve SRE Agent's future recommendations

---

## Next Steps

After completing the demo:

1. **Try other scenarios**:
   - High error rate (throw exceptions)
   - Database connection timeout (stop Cosmos DB)
   - Authentication failures (revoke Entra ID tokens)

2. **Customize runbooks**:
   - Add service-specific procedures
   - Include escalation contacts
   - Link to documentation

3. **Integrate with Slack/Teams**:
   - Add additional Action Group receivers
   - Get real-time incident notifications

4. **Enable auto-remediation**:
   - Use Azure Automation runbooks for scaling
   - SRE Agent triggers fixes directly

---

## Troubleshooting

### Alert Didn't Fire
- Check threshold: Is average latency > 500ms?
- Check evaluation period: Alert needs 5+ minutes of data
- Verify metric emission: Check Application Insights

### Query Fails with "Failed to resolve table or column expression named 'requests'"
- Open **Logs** from the **Application Insights** resource or the **Log Analytics Workspace**, not from the individual **Container App** resource
- Use workspace-based Application Insights tables: `AppRequests`, `AppExceptions`, and `AppDependencies`
- Use `TimeGenerated`, `Name`, `DurationMs`, `Success`, `ExceptionType`, `OuterMessage`, `DependencyType`, and `Target` column names in those queries

### Not Sure What to Query from Container App Logs
- Use `ContainerAppConsoleLogs` for application stdout/stderr
- Use `ContainerAppSystemLogs` for revision provisioning and platform events
- If the Logs blade shows `_CL` tables instead, use the table names and suffixed columns visible in that workspace

### Ticket Not Created
- Check the Action Group receiver target
- Verify the Logic App receiver callback URL matches the trigger `listCallbackUrl` result and includes `/triggers/` plus `sig=`
- Verify the Logic App or Azure Function run result
- Verify the relay implementation actually creates the destination you expect (Azure DevOps, GitHub, or both)
- Verify Azure DevOps or GitHub authentication

### SRE Agent Doesn't See the Ticket
- Verify GitHub Connector is registered
- Check Azure DevOps connector configuration if using Azure DevOps
- Check GitHub issue permissions if using GitHub
- Review SRE Agent logs for errors

---

## References

- [Phase 1-2 Setup](./sre-agent-setup.md)
- [Azure Monitor Alerts Documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/)
- [Azure SRE Agent Memory](https://learn.microsoft.com/en-us/azure/sre-agent/memory)
- [Azure SRE Agent Reasoning](https://learn.microsoft.com/en-us/azure/sre-agent/agent-reasoning)
