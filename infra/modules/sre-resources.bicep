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

@description('Optional Logic App resource ID that receives Azure Monitor incidents.')
param incidentRelayResourceId string = ''

@description('Optional Logic App callback URL used by the Action Group receiver. Pass the full trigger invoke URL returned by listCallbackUrl, not the workflow overview URL.')
@secure()
param incidentRelayCallbackUrl string = ''

@description('Response time threshold in milliseconds for alert.')
param responseTimeThresholdMs int = 500

@description('Failed request count threshold for alert evaluation.')
param failedRequestCountThreshold int = 5

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
var hasIncidentRelay = !empty(incidentRelayResourceId) && !empty(incidentRelayCallbackUrl)

// High response time alert rule
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
          criterionType: 'StaticThresholdCriterion'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: responseTimeThresholdMs
          timeAggregation: 'Average'
          dimensions: []
        }
      ]
    }
    actions: hasIncidentRelay ? [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {
          incidentType: 'high-latency'
        }
      }
    ] : []
  }
}

// High failed request alert rule
resource alertRuleHighErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = if (applicationInsightsId != '') {
  name: alertRuleHighErrorsName
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failed request count exceeds threshold'
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
          name: 'Failed request count'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: failedRequestCountThreshold
          timeAggregation: 'Total'
          dimensions: []
        }
      ]
    }
    actions: hasIncidentRelay ? [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {
          incidentType: 'failed-requests'
        }
      }
    ] : []
  }
}

// Action Group for incident routing
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
    logicAppReceivers: hasIncidentRelay ? [
      {
        name: 'incidentRelay'
        resourceId: incidentRelayResourceId
        callbackUrl: incidentRelayCallbackUrl
        useCommonAlertSchema: true
      }
    ] : []
    azureFunctionReceivers: []
    armRoleReceivers: []
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
output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
output alertRuleHighLatencyId string = alertRuleHighLatency.id
output alertRuleHighErrorsId string = alertRuleHighErrors.id
output logQueryAlertId string = logQueryAlert.id
