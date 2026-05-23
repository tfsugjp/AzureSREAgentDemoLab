# Azure SRE Agent Demo Setup Guide

This guide walks you through setting up the Azure SRE Agent integration with the GlobalAzureDemo2026 application for incident detection and Azure DevOps automation.

## Prerequisites

- Azure subscription with appropriate permissions (Owner or Contributor role)
- Azure CLI (`az`) installed
- GitHub account with access to the GlobalAzureDemo2026 repository
- Azure DevOps organization and project
- PowerShell 7+ (for Windows) or Bash (for macOS/Linux)

### Azure Services Required

- Azure Container Apps (with managed environment)
- Azure Container Registry
- Azure Cosmos DB
- Azure Application Insights
- Azure Log Analytics Workspace
- Azure Monitor (Alerts, Action Groups)
- Azure DevOps (for work item tracking)

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
│    (Email, Webhook, Azure DevOps)                  │
└─────────────┬───────────────────────────────────────┘
              │ REST API Call
              ▼
┌─────────────────────────────────────────────────────┐
│ 6. Azure DevOps Work Item created                  │
│    (Incident report for SRE Agent)                 │
└─────────────┬───────────────────────────────────────┘
              │ Work Item Details
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
```

**PowerShell 7:**
```powershell
$env:RESOURCE_GROUP = "rg-globalazdemo-sre"
$env:ENVIRONMENT_NAME = "sre-demo"
$env:LOCATION = "westus3"
$env:AZURE_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/<your-org>"
$env:AZURE_DEVOPS_PROJECT = "SRE-Demo"
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

### 2.1 Update Bicep Parameters (infra/main.parameters.json)

Add the following parameters to your deployment:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "enableSreDemo": {
      "value": true
    },
    "azureDevOpsOrgUrl": {
      "value": "https://dev.azure.com/<your-org>"
    },
    "azureDevOpsProjectName": {
      "value": "SRE-Demo"
    },
    "responseTimeThresholdMs": {
      "value": 500
    },
    "errorRateThresholdPercent": {
      "value": 5
    }
  }
}
```

### 2.2 Deploy Infrastructure

**Bash:**
```bash
az deployment group create \
  --name "globalazdemo-sre-$(date +%s)" \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters enableSreDemo=true \
                azureDevOpsOrgUrl=$AZURE_DEVOPS_ORG_URL \
                azureDevOpsProjectName=$AZURE_DEVOPS_PROJECT
```

**PowerShell 7:**
```powershell
$deploymentName = "globalazdemo-sre-$(Get-Date -Format 'yyyyMMddHHmmss')"
az deployment group create `
  --name $deploymentName `
  --resource-group $env:RESOURCE_GROUP `
  --template-file infra/main.bicep `
  --parameters infra/main.parameters.json `
  --parameters enableSreDemo=true `
                azureDevOpsOrgUrl=$env:AZURE_DEVOPS_ORG_URL `
                azureDevOpsProjectName=$env:AZURE_DEVOPS_PROJECT
```

---

## Step 3: Configure GitHub Connector

The SRE Agent uses GitHub Connectors to access repositories and create issues.

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
Permissions: Read logs, create issues, read project history
```

---

## Step 4: Configure Azure DevOps Integration

The Action Group routes incident alerts to Azure DevOps by creating work items automatically.

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

### 4.4 Configure Action Group

The Bicep module creates an Action Group automatically. To manually configure webhook to Azure DevOps:

1. In Azure Portal, go to **Monitor → Action Groups**
2. Find the action group created by the SRE module
3. Add **Webhook** receiver:
   - **Name**: `AzureDevOps-WorkItem`
   - **URL**: `https://dev.azure.com/<org>/<project>/_apis/wit/workitems?api-version=7.0`
   - **Use common alert schema**: Enabled

---

## Step 5: Configure SRE Agent Memory & Knowledge Base

The SRE Agent uses memory to store operational knowledge about your services.

### 5.1 Create Runbook Templates

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

### 5.2 Store Runbooks in SRE Agent Memory

Refer to: [Azure SRE Agent - Memory & Knowledge Base](https://learn.microsoft.com/en-us/azure/sre-agent/memory)

Add runbooks to your SRE Agent configuration:
- Upload runbook YAML files to the agent's knowledge base
- Tag with service names: `catalog`, `order`, `notification`
- Set urgency levels: `critical`, `high`, `medium`

### 5.3 Enable Agent Reasoning

Configure the SRE Agent to use advanced reasoning for incident analysis:

Refer to: [Azure SRE Agent - Agent Reasoning](https://learn.microsoft.com/en-us/azure/sre-agent/agent-reasoning)

Enable:
- **Contextual Analysis**: Analyze alert in context of service changes
- **Metric Correlation**: Find related metric spikes
- **Historical Patterns**: Compare with past incidents
- **Resolution Suggestions**: Rank solutions by past success rate

---

## Step 6: Verify Setup

### 6.1 Check Resources Created

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

### 6.2 Test Connectivity

1. **Test GitHub Connector**: Push a test commit to the repository, verify SRE Agent can see it
2. **Test Azure DevOps Integration**: Create a test work item in Azure DevOps, verify SRE Agent can read it
3. **Test Alerts**: Generate synthetic traffic, verify alert fires and work item is created

---

## Step 7: Run the 20-Minute Demo Scenario

See: [SRE Agent 20-Minute Demo Scenario](./sre-scenario-20min.md)

This scenario includes:
1. Triggering a synthetic incident
2. Observing alert detection
3. Work item creation in Azure DevOps
4. SRE Agent investigation using memory
5. Resolution and verification

---

## Troubleshooting

### Alert Rules Not Firing

- **Check**: Metric names in Alert Rule vs. Application Insights
- **Solution**: Use `az monitor metrics list` to verify available metrics
- **Common Issue**: Microservices must emit metrics (configured via OpenTelemetry)

### Azure DevOps Work Item Not Created

- **Check**: Service Principal permissions in Azure DevOps
- **Check**: Webhook URL in Action Group is correct
- **Solution**: Test webhook manually with `curl` or Postman

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
4. **Integrate with Slack/Teams** via additional Action Group receivers
5. **Enable advanced reasoning** in SRE Agent for automated remediation

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
