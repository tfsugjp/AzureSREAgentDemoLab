@description('Environment name used for naming resources.')
param environmentName string

@description('Primary Azure region.')
param location string

@description('Log Analytics Workspace resource ID.')
param logAnalyticsWorkspaceId string

@description('Application Insights resource ID.')
param applicationInsightsId string

@description('Container Apps Environment resource ID.')
param containerAppsEnvironmentId string

@description('Azure DevOps Organization URL (e.g., https://dev.azure.com/myorg).')
param azureDevOpsOrgUrl string = ''

@description('Azure DevOps Project Name where work items will be created.')
param azureDevOpsProjectName string = 'SRE-Demo'

@description('Azure DevOps PAT token for work item creation (optional for demo).')
@secure()
param azureDevOpsPatToken string = ''

@description('Response time threshold in milliseconds for alert.')
param responseTimeThresholdMs int = 500

@description('Error rate threshold in percentage for alert.')
param errorRateThresholdPercent int = 5

@description('Minimum evaluation periods before alert triggers.')
param alertEvaluationPeriods int = 2

@description('Common tags applied to all resources.')
param tags object = {}

var envToken = toLower(take(environmentName, 12))
var uniqueToken = toLower(take(uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location), 6))
var actionGroupName = take('ag-sre-${envToken}-${uniqueToken}', 128)
var alertRuleHighLatencyName = take('alert-high-latency-${envToken}-${uniqueToken}', 260)
var alertRuleHighErrorsName = take('alert-high-errors-${envToken}-${uniqueToken}', 260)
var diagnosticSettingName = 'diag-sre-${envToken}'

// High Response Time Alert Rule
resource alertRuleHighLatency 'Microsoft.Insights/metricAlerts@2018-03-01' = if (applicationInsightsId != '') {
  name: alertRuleHighLatencyName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when server response time exceeds threshold'
    severity: 2
    enabled: true
    scopes: [
      applicationInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Server response time'
          metricName: 'performanceCounters/processCpuPercentage'
          operator: 'GreaterThan'
          threshold: responseTimeThresholdMs
          timeAggregation: 'Average'
          dimensions: []
        }
      ]
    }
    actions: []
  }
}

// High Error Rate Alert Rule
resource alertRuleHighErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = if (applicationInsightsId != '') {
  name: alertRuleHighErrorsName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failed requests exceed threshold'
    severity: 2
    enabled: true
    scopes: [
      applicationInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Failed request rate'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: errorRateThresholdPercent
          timeAggregation: 'Total'
          dimensions: []
        }
      ]
    }
    actions: []
  }
}

// Action Group for DevOps Integration
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'sreDemo'
    enabled: true
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: []
    eventHubReceivers: []
    itsmReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: [
      {
        name: 'Site Reliability Engineering'
        roleId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'afd6c3d0-41ec-4235-8645-c2f016cbafbc')
        useCommonAlertSchema: true
      }
    ]
  }
}

// Log Query Alert for Custom Incident Detection
resource logQueryAlert 'Microsoft.Insights/scheduledQueryRules@2021-06-01-preview' = if (logAnalyticsWorkspaceId != '') {
  name: take('alert-custom-incident-${envToken}-${uniqueToken}', 260)
  location: location
  tags: tags
  properties: {
    enabled: true
    description: 'Detect custom incidents from logs for SRE Agent'
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: 'AppEvents | where TimeGenerated > ago(15m) | where Name contains "error" or Name contains "failure" | summarize Count = count() by Name | where Count > 5'
          timeAggregation: 'Count'
          dimensions: []
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: alertEvaluationPeriods
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

// Diagnostic Setting for Container Apps Environment
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (containerAppsEnvironmentId != '') {
  name: diagnosticSettingName
  scope: containerAppsEnvironment
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'ContainerAppSystemLogs'
        enabled: true
      }
      {
        category: 'ContainerAppConsoleLog'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Reference to Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: last(split(containerAppsEnvironmentId, '/'))
}

// Outputs for use in other modules
@export()
output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
output alertRuleHighLatencyId string = alertRuleHighLatency.id
output alertRuleHighErrorsId string = alertRuleHighErrors.id
output logQueryAlertId string = logQueryAlert.id
