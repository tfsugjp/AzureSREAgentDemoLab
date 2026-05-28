# Azure SRE Agent Demo Setup Guide

This guide walks you through setting up the Azure SRE Agent integration with the GlobalAzureDemo2026 application for incident detection and relay-backed incident routing to Azure DevOps, GitHub, or both.

## Prerequisites

- Azure subscription with appropriate permissions (Owner or Contributor role)
- Azure CLI (`az`) installed
- GitHub account with access to the GlobalAzureDemo2026 repository
- Azure DevOps organization and project (optional, if using Azure DevOps routing)
- GitHub repository admin or maintainer access (required for GitHub issue routing)
- PowerShell 7+ (for Windows) or Bash (for macOS/Linux)

### Azure Services Required

- Azure Container Apps (with managed environment)
- Azure Container Registry
- Azure Cosmos DB
- Azure Application Insights
- Azure Log Analytics Workspace
- Azure Monitor (Alerts, Action Groups)
- Logic Apps or Azure Functions (recommended Azure-native relay for ticket creation)
- Azure DevOps (optional, for work item tracking)

## Supported Integration Patterns

| Pattern | Ticket destination | Recommended use |
|---|---|---|
| Azure DevOps only | Azure DevOps work items | Teams already operating in Boards and Pipelines |
| GitHub only | GitHub issues | Teams already running engineering follow-up in GitHub |
| Azure DevOps + GitHub | Work item plus GitHub issue | Incident tracked in Boards, engineering follow-up in GitHub |

---

## Architecture Overview

```
Incident Detection Flow:
┌─────────────────────────────────────────────────────┐
│ 1. Microservices emit metrics & logs               │
│    (Catalog, Order, Notification services)         │
└─────────────┬───────────────────────────────────────┘
              │ OpenTelemetry
              ▼
┌─────────────────────────────────────────────────────┐
│ 2. Application Insights ingests telemetry          │
│    (traces, metrics, logs, exceptions)             │
└─────────────┬───────────────────────────────────────┘
              │ Logs & Metrics
              ▼
┌─────────────────────────────────────────────────────┐
│ 3. Log Analytics Workspace stores all data         │
│    (30-day retention)                              │
└─────────────┬───────────────────────────────────────┘
              │ KQL Queries
              ▼
┌─────────────────────────────────────────────────────┐
│ 4. Alert Rules evaluate conditions                 │
│    (High latency, High error rate, Custom logs)    │
└─────────────┬───────────────────────────────────────┘
              │ Alert Fires
              ▼
┌─────────────────────────────────────────────────────┐
│ 5. Action Group routes notification                │
│    (Logic App or Azure Function webhook)           │
└─────────────┬───────────────────────────────────────┘
              │ Azure-native relay
              ▼
┌─────────────────────────────────────────────────────┐
│ 6. Incident ticket created                         │
│    (Azure DevOps, GitHub, or both)                 │
└─────────────┬───────────────────────────────────────┘
              │ Ticket details
              ▼
┌─────────────────────────────────────────────────────┐
│ 7. SRE Agent reads incident & memory               │
│    - Alert details                                 │
│    - Service logs & metrics                        │
│    - Runbook recommendations                       │
│    - Suggests resolution via reasoning             │
└─────────────────────────────────────────────────────┘
```

---

## Step 1: Prepare Azure Resources

### 1.1 Set Environment Variables

**Bash/macOS:**
```bash
export RESOURCE_GROUP="rg-globalazdemo-sre"
export ENVIRONMENT_NAME="sre-demo"
export LOCATION="westus3"
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export AZURE_DEVOPS_ORG_URL="https://dev.azure.com/<your-org>"
export AZURE_DEVOPS_PROJECT="SRE-Demo"
export GITHUB_OWNER="<your-github-owner>"
export GITHUB_REPO="GlobalAzureDemo2026"
```

**PowerShell 7:**
```powershell
$env:RESOURCE_GROUP = "rg-globalazdemo-sre"
$env:ENVIRONMENT_NAME = "sre-demo"
$env:LOCATION = "westus3"
$env:AZURE_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/<your-org>"
$env:AZURE_DEVOPS_PROJECT = "SRE-Demo"
$env:GITHUB_OWNER = "<your-github-owner>"
$env:GITHUB_REPO = "GlobalAzureDemo2026"
```

### 1.2 Create Resource Group

**Bash:**
```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --subscription $AZURE_SUBSCRIPTION_ID
```

**PowerShell 7:**
```powershell
az group create `
  --name $env:RESOURCE_GROUP `
  --location $env:LOCATION `
  --subscription $env:AZURE_SUBSCRIPTION_ID
```

---

## Step 2: Deploy with SRE Agent Resources

The infrastructure includes conditional deployment of SRE resources. Deploy the main template with SRE parameters enabled:

### 2.1 Gather the SRE Overlay Inputs

Before applying the SRE demo overlay, collect:

- the same `environmentName`, `entraTenantId`, `entraClientId`, and `entraAudience` values used for the base deployment
- the **Logic App resource ID** or equivalent Azure relay resource ID
- the **full Logic App callback URL** from the HTTP trigger
- the thresholds you want for latency and failed request count

Use the **trigger callback URL**, not the Logic App overview URL or access endpoint. The value passed to `incidentRelayCallbackUrl` must include the trigger path and signature, for example:

```text
https://.../workflows/.../triggers/When_an_HTTP_request_is_received/paths/invoke?...&sig=...
```

If the URL does not contain `/triggers/` and `sig=`, Azure Monitor can show a Logic App receiver in the Action Group while never invoking the workflow.

**Bash:**
```bash
export LOGIC_APP_RESOURCE_ID="/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Logic/workflows/<logic-app-name>"
export LOGIC_APP_TRIGGER_NAME="When_an_HTTP_request_is_received"

export LOGIC_APP_CALLBACK_URL=$(az rest \
  --method post \
  --url "https://management.azure.com${LOGIC_APP_RESOURCE_ID}/triggers/${LOGIC_APP_TRIGGER_NAME}/listCallbackUrl?api-version=2019-05-01" \
  --query value \
  --output tsv)
```

**PowerShell 7:**
```powershell
$logicAppResourceId = "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Logic/workflows/<logic-app-name>"
$logicAppTriggerName = "When_an_HTTP_request_is_received"

$logicAppCallbackUrl = az rest `
  --method post `
  --url "https://management.azure.com$logicAppResourceId/triggers/$logicAppTriggerName/listCallbackUrl?api-version=2019-05-01" `
  --query value `
  --output tsv
```

### 2.2 Deploy SRE Overlay Resources

Deploy SRE resources with the dedicated overlay template. The overlay references the existing Log Analytics workspace, Application Insights component, and Container Apps environment without updating the Container Apps revisions or images.

> [!WARNING]
> Do not re-run `infra/main.bicep` just to update SRE resources after `azd deploy`. The base template intentionally uses `mcr.microsoft.com/dotnet/samples:aspnetapp` as the provisioning placeholder image, so reapplying it can reset Catalog, Order, and Notification Container Apps back to the sample app.

**Bash:**
```bash
az deployment group create \
  --name "globalazdemo-sre-$(date +%s)" \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/sre-overlay.bicep \
  --parameters \
    "environmentName=$ENVIRONMENT_NAME" \
    "location=$LOCATION" \
    "incidentRelayResourceId=$LOGIC_APP_RESOURCE_ID" \
    "incidentRelayCallbackUrl=$LOGIC_APP_CALLBACK_URL" \
    "responseTimeThresholdMs=500" \
    "failedRequestCountThreshold=5"
```

**PowerShell 7:**
```powershell
$deploymentName = "globalazdemo-sre-$(Get-Date -Format 'yyyyMMddHHmmss')"
az deployment group create `
  --name $deploymentName `
  --resource-group $env:RESOURCE_GROUP `
  --template-file infra/sre-overlay.bicep `
  --parameters `
    "environmentName=$env:ENVIRONMENT_NAME" `
    "location=$env:LOCATION" `
    "incidentRelayResourceId=$logicAppResourceId" `
    "incidentRelayCallbackUrl=$logicAppCallbackUrl" `
    "responseTimeThresholdMs=500" `
    "failedRequestCountThreshold=5"
```

If Container Apps still show `mcr.microsoft.com/dotnet/samples:aspnetapp` after setup, run `azd deploy` from the repository root to push the Catalog, Order, and Notification service images.

The quotes around each `key=value` argument are required when the callback URL contains query string parameters such as `&sp=`, `&sv=`, and `&sig=`. Without quoting, your shell can treat those fragments as separate commands.

---

## Step 3: Configure GitHub Connector

The SRE Agent uses GitHub connectors to read repository context and, if you choose the GitHub route, read or update issues that were created by your Azure relay.

### 3.1 Create GitHub Personal Access Token (PAT)

1. Go to [GitHub Settings → Developer Settings → Personal Access Tokens](https://github.com/settings/tokens?type=beta)
2. Click **Generate new token**
3. Grant the following scopes:
   - `repo` (full control of private repositories)
   - `read:org` (read organization data)
4. Copy the token and save it securely

### 3.2 Register Connector in SRE Agent

When configuring your SRE Agent instance, register the GitHub connector:

**Refer to:** [Azure SRE Agent - GitHub Connector](https://sre.azure.com/docs/concepts/connectors)

```
Connector Type: GitHub
Name: GlobalAzureDemo-Repo
Repository: tfsugjp/GlobalAzureDemo2026
Authentication: Personal Access Token (from Step 3.1)
Permissions: Read repository content, read project history, create and update issues
```

---

## Step 4: Configure Azure DevOps Integration

Use this section when your incident workflow includes Azure DevOps work items.

### 4.1 Create Azure DevOps Service Principal

1. In Azure Portal, navigate to **Azure Active Directory → App Registrations**
2. Click **New registration**
3. Name: `SRE-Agent-Demo`
4. Click **Register**

### 4.2 Grant Azure DevOps Permissions

1. Go to your **Azure DevOps Organization → Organization Settings → Users**
2. Add the service principal as a **Project Collection Administrator** (for demo)
3. Note the **Tenant ID** and **Client ID** from the app registration

### 4.3 Create Client Secret

1. In the app registration, go to **Certificates & Secrets**
2. Click **New client secret**
3. Copy and store the secret securely
4. Use this in Alert Action Groups

### 4.4 Register Azure DevOps in SRE Agent

If the SRE Agent should read or comment on Azure DevOps work items created by the relay, register the Azure DevOps connector in the agent as well.

Typical configuration:

```text
Connector Type: Azure DevOps
Organization: https://dev.azure.com/<your-org>
Project: SRE-Demo
Permissions: Read and update work items, read pipeline and deployment history
```

---

## Step 5: Configure Incident Routing

Azure Monitor should remain the incident source. For Azure DevOps and GitHub ticket creation, use an Azure-native relay such as **Logic Apps** or **Azure Functions** behind the Action Group webhook. This keeps the incident flow Azure-based while still allowing GitHub collaboration.

### 5.1 Why a Relay Is Recommended

- Azure Monitor Action Groups can emit the common alert schema reliably
- Logic Apps and Azure Functions can authenticate to Azure DevOps and GitHub cleanly
- The same Azure alert can create one or two downstream tickets with consistent formatting
- You can enrich the payload with resource links, KQL query links, and severity mappings

### 5.2 Route A: Azure DevOps Only

Recommended when the operations team triages incidents in Boards.

Flow:

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> Azure DevOps Work Item
  -> SRE Agent reads work item + telemetry
```

Suggested work item fields:

- **Title**: `[SRE] High latency detected in Order Service`
- **Type**: Bug or Issue
- **Tags**: `sre-agent-demo`, `incident`, `azure-monitor`
- **Description**:
  - alert rule name
  - resource ID
  - fired time
  - portal link
  - Log Analytics query link

### 5.3 Route B: GitHub Only

Recommended when engineering follow-up lives entirely in GitHub Issues.

Flow:

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> GitHub Issue
  -> SRE Agent reads issue + telemetry
```

Suggested GitHub issue fields:

- **Title**: `[SRE] High latency detected in Order Service`
- **Labels**: `sre-agent-demo`, `incident`, `azure-monitor`
- **Body**:
  - summary of the alert
  - impacted service
  - severity and threshold
  - Azure portal and KQL links
  - suggested runbook

GitHub authentication options:

- GitHub App (recommended for teams)
- PAT with `repo` scope (simple demo setup)

### 5.4 Route C: Azure DevOps + GitHub

Recommended when operations triage in Azure DevOps but engineering remediation is tracked in GitHub.

Flow:

```text
Azure Monitor Alert
  -> Action Group
  -> Logic App / Azure Function
  -> Azure DevOps Work Item
  -> GitHub Issue
  -> SRE Agent correlates both tickets
```

Recommended ownership split:

- **Azure DevOps**: incident record, severity, response timeline, approvals
- **GitHub**: code fix, PR links, engineering discussion, post-incident tasks

### 5.5 Payload Mapping

Map the Azure Monitor common alert schema into stable ticket fields:

| Alert field | Azure DevOps | GitHub |
|---|---|---|
| `essentials.alertRule` | Title prefix and description | Issue title and body |
| `essentials.severity` | Priority / Severity | Label such as `sev2` |
| `essentials.firedDateTime` | Created date note | Timeline in issue body |
| `alertContext.condition` | Work item description | Issue body details |
| Resource ID / resource name | Custom field or tag | Markdown details block |

---

## Step 6: Configure SRE Agent Memory & Knowledge Base

The SRE Agent uses memory to store operational knowledge about your services.

### 6.1 Create Runbook Templates

Create documents that describe how to respond to common incidents:

**Runbook: High Response Time**
```yaml
Trigger:
  - Alert: Response Time > 500ms for 5 minutes
  
Investigation:
  - Check Container App CPU/Memory usage
  - Review Application Insights performance counters
  - Check Cosmos DB throughput utilization
  
Resolution Steps:
  1. Scale up Container App replicas if CPU > 80%
  2. Check Cosmos DB indexes on frequently queried fields
  3. Review application logs for slow queries
  4. If issue persists, check network latency in Container App environment
  
Escalation:
  - If unresolved after 30 minutes, create GitHub issue for engineering review
  - Tag with: @-team/sre-team
```

**Runbook: High Error Rate**
```yaml
Trigger:
  - Alert: Failed Requests > 5% for 5 minutes
  
Investigation:
  - Check Application Insights failures/exceptions
  - Review service logs for stack traces
  - Check authentication/authorization failures (Entra ID)
  - Review Cosmos DB connection errors
  
Resolution Steps:
  1. Check recent deployments in Azure DevOps Pipelines
  2. If recent deployment, consider rollback
  3. Verify Cosmos DB is accessible
  4. Check Entra ID token validation
  5. Review rate limiting on any upstream services
```

### 6.2 Store Runbooks in SRE Agent Memory

Refer to: [Azure SRE Agent - Memory & Knowledge Base](https://learn.microsoft.com/en-us/azure/sre-agent/memory)

Add runbooks to your SRE Agent configuration:
- Upload runbook YAML files to the agent's knowledge base
- Tag with service names: `catalog`, `order`, `notification`
- Set urgency levels: `critical`, `high`, `medium`

### 6.3 Enable Agent Reasoning

Configure the SRE Agent to use advanced reasoning for incident analysis:

Refer to: [Azure SRE Agent - Agent Reasoning](https://learn.microsoft.com/en-us/azure/sre-agent/agent-reasoning)

Enable:
- **Contextual Analysis**: Analyze alert in context of service changes
- **Metric Correlation**: Find related metric spikes
- **Historical Patterns**: Compare with past incidents
- **Resolution Suggestions**: Rank solutions by past success rate

---

## Step 7: Verify Setup

### 7.1 Check Resources Created

**Bash:**
```bash
# Verify Log Analytics Workspace
az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# Verify Application Insights
az monitor app-insights component list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# Verify Alert Rules
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv

# Verify Action Group
az monitor action-group list \
  --resource-group $RESOURCE_GROUP \
  --query "[].name" -o tsv
```

**PowerShell 7:**
```powershell
# Verify Log Analytics Workspace
az monitor log-analytics workspace list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[].name" -o tsv

# Verify Application Insights
az monitor app-insights component list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[].name" -o tsv

# Verify Alert Rules
az monitor metrics alert list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[].name" -o tsv

# Verify Action Group
az monitor action-group list `
  --resource-group $env:RESOURCE_GROUP `
  --query "[].name" -o tsv
```

### 7.2 Test Connectivity

1. **Test GitHub connector**: Push a test commit to the repository and verify the SRE Agent can see it
2. **Test Azure DevOps connector**: Create a test work item and verify the SRE Agent can read it
3. **Test GitHub issue route**: Trigger a test issue and verify the SRE Agent can read and comment on it
4. **Test alerts**: Generate synthetic traffic and verify the Azure Monitor alert creates the expected downstream ticket

---

## Step 8: Run the 20-Minute Demo Scenario

See: [SRE Agent 20-Minute Demo Scenario](./sre-scenario-20min.md)

This scenario includes:
1. Triggering a synthetic incident
2. Observing alert detection
3. Ticket creation in Azure DevOps, GitHub, or both
4. SRE Agent investigation using memory
5. Resolution and ticket closure verification

---

## Troubleshooting

### Alert Rules Not Firing

- **Check**: Metric names in Alert Rule vs. Application Insights
- **Solution**: Use `az monitor metrics list` to verify available metrics
- **Common Issue**: Microservices must emit metrics (configured via OpenTelemetry)

### Azure DevOps Work Item Not Created

- **Check**: Service Principal permissions in Azure DevOps
- **Check**: Logic App or Azure Function authentication to Azure DevOps
- **Solution**: Replay the alert payload through the relay endpoint

### GitHub Issue Not Created

- **Check**: GitHub App or PAT permissions include issue creation
- **Check**: Repository owner and repository name are correct
- **Check**: Logic App or Azure Function mapping for labels and body fields
- **Solution**: Send a sample alert payload and verify the GitHub API response

### SRE Agent Cannot Access Services

- **Check**: GitHub Connector is registered in SRE Agent
- **Check**: GitHub PAT has correct scopes
- **Check**: Network connectivity from SRE Agent to Azure services

### Logs Not Appearing in Log Analytics

- **Check**: Container Apps are running and healthy
- **Check**: Diagnostic Settings on Container App Environment
- **Solution**: Manually enable diagnostic settings if not created by Bicep

---

## Next Steps

1. **Run the 20-minute demo scenario** (see Step 7)
2. **Customize thresholds** based on your actual SLA requirements
3. **Add more alert rules** for other services (API latency, data consistency)
4. **Add both ticket routes** if you currently use only one
5. **Integrate with Slack/Teams** via additional Action Group receivers
6. **Enable advanced reasoning** in SRE Agent for automated remediation

---

## References

- [Azure SRE Agent Documentation](https://sre.azure.com)
- [Azure SRE Agent - GitHub Connectors](https://sre.azure.com/docs/concepts/connectors)
- [Azure SRE Agent - Memory & Knowledge Base](https://learn.microsoft.com/en-us/azure/sre-agent/memory)
- [Azure SRE Agent - Agent Reasoning](https://learn.microsoft.com/en-us/azure/sre-agent/agent-reasoning)
- [Azure Monitor Alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Azure Container Apps Monitoring](https://learn.microsoft.com/en-us/azure/container-apps/observability)

---

## Support

For issues or questions:
1. Check **Troubleshooting** section above
2. Review [Azure SRE Agent FAQ](https://sre.azure.com/docs/faqs)
3. Open an issue on the [GlobalAzureDemo2026 repository](https://github.com/tfsugjp/GlobalAzureDemo2026)
