# Azure SRE Agent 20-Minute Demo Scenario

This is an **executable, time-boxed scenario** demonstrating how Azure SRE Agent detects incidents, opens a downstream ticket in Azure DevOps, GitHub, or both, and suggests resolutions using memory and reasoning.

**Total Duration: 20 minutes**

---

## Scenario Overview

**Story**: A production incident has been detected in the Order Service. High latency is detected by Azure Monitor, which automatically creates an incident record in Azure DevOps, a GitHub issue, or both. The SRE Agent investigates the incident using telemetry data and runbook knowledge, then recommends a resolution.

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

**Bash:**
```bash
export LOG_ANALYTICS_WS="<your-workspace-name>"
export RESOURCE_GROUP="<your-resource-group>"

# Query last 5 minutes of request metrics
az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS \
  --analytics-query "
    requests
    | where timestamp > ago(5m)
    | summarize AvgDuration = avg(duration), Count = count() by name
    | top 10 by Count desc
  " \
  --resource-group $RESOURCE_GROUP
```

**PowerShell 7:**
```powershell
$logAnalyticsWs = "<your-workspace-name>"
$resourceGroup = "<your-resource-group>"

$query = @"
requests
| where timestamp > ago(5m)
| summarize AvgDuration = avg(duration), Count = count() by name
| top 10 by Count desc
"@

az monitor log-analytics query `
  --workspace $logAnalyticsWs `
  --analytics-query $query `
  --resource-group $resourceGroup
```

---

## Phase 2: Alert Detection & Ticket Creation (3 minutes)

### 2.1 Monitor Alert Rule Status

The alert rule from the infrastructure should now be evaluating against the metrics. Check its status:

**Bash:**
```bash
export ALERT_RULE_NAME="alert-high-latency-*"

# List all alert rules
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'high-latency')]" \
  --output table

# Check alert history (fired incidents)
az monitor metrics alert history list \
  --resource-group $RESOURCE_GROUP \
  --alert-name "alert-high-latency-*" \
  --output json | jq '.[0:5]'
```

**PowerShell 7:**
```powershell
# List all alert rules
az monitor metrics alert list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[?contains(name, 'high-latency')]" `
  --output table

# Check recent alert activities
az monitor metrics alert history list `
  --resource-group $env:RESOURCE_GROUP `
  --alert-name "alert-high-latency-*" `
  --output json | ConvertFrom-Json | Select-Object -First 5
```

**Expected Output**:
```
Alert Rule Status: Fired
Last Triggered: <timestamp>
Severity: 2 (Warning)
```

### 2.2 Verify the Ticket Was Created

The Action Group should have triggered your Azure-native relay and created the downstream ticket selected for the demo.

#### Option A: Azure DevOps

1. Navigate to **Azure DevOps -> SRE-Demo Project -> Boards**
2. Look for a new **Bug** or **Task** with a title like:
   - `[SRE] High latency detected in Order Service`
   - `[SRE] Server response time exceeded threshold`
3. Confirm it includes alert rule, threshold, current value, impacted service, and portal links

#### Option B: GitHub

1. Navigate to **GitHub -> tfsugjp/GlobalAzureDemo2026 -> Issues**
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
- Check the Logic App or Azure Function run history
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

**Query 1: Performance Timeline**
```kusto
requests
| where timestamp > ago(15m)
| where name contains "orders"
| summarize 
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    P99Duration = percentile(duration, 99),
    FailureRate = (todouble(sum(itemCount)) - todouble(sum(successful))) / todouble(sum(itemCount)) * 100
  by bin(timestamp, 1m)
| render timechart
```

**Query 2: Error Analysis**
```kusto
exceptions
| where timestamp > ago(15m)
| summarize Count = count() by exceptionType, outerMessage
| top 10 by Count desc
```

**Query 3: Dependency Performance**
```kusto
dependencies
| where timestamp > ago(15m)
| where target contains "cosmos"
| summarize 
    AvgDuration = avg(duration),
    FailureRate = (failures / count()) * 100
  by type, target
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
az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WS \
  --analytics-query "
    requests
    | where timestamp > ago(5m) and name contains 'orders'
    | summarize AvgDuration = avg(duration), P95 = percentile(duration, 95)
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
$query = @"
requests
| where timestamp > ago(5m) and name contains 'orders'
| summarize AvgDuration = avg(duration), P95 = percentile(duration, 95)
"@

az monitor log-analytics query `
  --workspace $logAnalyticsWs `
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

### Ticket Not Created
- Check the Action Group receiver target
- Verify the Logic App or Azure Function run result
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
