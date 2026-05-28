@description('Unique environment name used by Azure Developer CLI, such as dev, test, prod, or workshop-a.')
param environmentName string

@description('Primary Azure region for existing resources. Must match the base deployment location. Defaults to westus3.')
param location string = 'westus3'

@description('Logical environment type used only for tagging overlay resources.')
param environmentType string = 'dev'

@description('Optional extra tags applied to SRE resources.')
param tags object = {}

@description('Optional Logic App resource ID used to route Azure Monitor incidents downstream.')
param incidentRelayResourceId string = ''

@description('Optional Logic App callback URL used by the Action Group receiver. Pass the full trigger invoke URL returned by listCallbackUrl, not the workflow overview URL.')
@secure()
param incidentRelayCallbackUrl string = ''

@description('Response time threshold in milliseconds for triggering SRE alerts.')
param responseTimeThresholdMs int = 500

@description('Failed request count threshold for triggering SRE alerts.')
param failedRequestCountThreshold int = 5

var envToken = toLower(take(environmentName, 12))
var uniqueToken = toLower(take(uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location), 6))
var commonTags = union(tags, {
  'azd-env-name': environmentName
  environment: environmentName
  environmentType: environmentType
  project: 'GlobalAzureDemo2026'
  workload: 'education'
})

var logAnalyticsName = take('law-${envToken}-${uniqueToken}', 63)
var appInsightsName = take('appi-${envToken}-${uniqueToken}', 64)
var containerAppsEnvironmentName = take('cae-${envToken}-${uniqueToken}', 32)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' existing = {
  name: logAnalyticsName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-10-02-preview' existing = {
  name: containerAppsEnvironmentName
}

module sreResources './modules/sre-resources.bicep' = {
  name: 'sre-resources'
  params: {
    environmentName: environmentName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    applicationInsightsId: applicationInsights.id
    containerAppsEnvironmentId: containerAppsEnvironment.id
    incidentRelayResourceId: incidentRelayResourceId
    incidentRelayCallbackUrl: incidentRelayCallbackUrl
    responseTimeThresholdMs: responseTimeThresholdMs
    failedRequestCountThreshold: failedRequestCountThreshold
    tags: commonTags
  }
}

output ACTION_GROUP_ID string = sreResources.outputs.actionGroupId
output ACTION_GROUP_NAME string = sreResources.outputs.actionGroupName
output HIGH_LATENCY_ALERT_ID string = sreResources.outputs.alertRuleHighLatencyId
output HIGH_ERRORS_ALERT_ID string = sreResources.outputs.alertRuleHighErrorsId
output CUSTOM_LOG_ALERT_ID string = sreResources.outputs.logQueryAlertId
