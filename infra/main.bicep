@description('Unique environment name used by Azure Developer CLI, such as dev, test, prod, or workshop-a.')
param environmentName string

@description('Primary Azure region for all resources. Defaults to westus3.')
param location string = 'westus3'

@description('Logical environment type used to tune cost-sensitive defaults. Any value other than prod is treated as non-production.')
param environmentType string = 'dev'

@description('Microsoft Entra tenant ID for JWT validation in the API services.')
param entraTenantId string

@description('Microsoft Entra application (client) ID for JWT validation in the API services.')
param entraClientId string

@description('Microsoft Entra audience / App ID URI for JWT validation in the API services.')
param entraAudience string

@description('Cosmos DB database name used by all services.')
param cosmosDatabaseName string = 'GlobalAzureDemo'

@description('Optional OTLP endpoint for app-side OpenTelemetry export. Leave empty when no collector is used.')
param openTelemetryEndpoint string = ''

@description('Set true only for workshop scenarios that intentionally disable API authentication.')
param disableAuthentication bool = false

@description('Optional extra tags applied to all resources.')
param tags object = {}

var envToken = toLower(take(environmentName, 12))
var compactEnvToken = replace(envToken, '-', '')
var uniqueToken = toLower(take(uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location), 6))
var isProduction = toLower(environmentType) == 'prod'
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
var cosmosAccountName = take('cosmos-${envToken}-${uniqueToken}', 44)
var acrName = take('gad${compactEnvToken}${uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location)}', 50)

var searchServiceName = take('srch-${envToken}-${uniqueToken}', 60)

var catalogServiceName = take('ca-cat-${envToken}-${uniqueToken}', 32)
var orderServiceName = take('ca-ord-${envToken}-${uniqueToken}', 32)
var notificationServiceName = take('ca-not-${envToken}-${uniqueToken}', 32)
var registryPullIdentityName = take('id-acr-${envToken}-${uniqueToken}', 128)

var nonProdCpu = 1
var prodCpu = 1
var nonProdMemory = '2Gi'
var prodMemory = '2Gi'
var minReplicas = isProduction ? 1 : 0
var maxReplicas = isProduction ? 3 : 1

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: isProduction ? 2 : 1
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  kind: 'web'
  location: location
  tags: commonTags
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    RetentionInDays: 30
    SamplingPercentage: 100
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  tags: commonTags
  properties: {
    // Left enabled to support local azd push workflows; runtime image pulls use the user-assigned managed identity below.
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      azureADAuthenticationAsArmPolicy: {
        status: 'enabled'
      }
    }
  }
}

resource registryPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: registryPullIdentityName
  location: location
  tags: commonTags
}

resource registryPullIdentityAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, registryPullIdentity.id, 'acrpull-uami')
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: registryPullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

var cosmosConnectionString = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: commonTags
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
    publicNetworkAccess: 'Enabled'
    networkAclBypass: 'None'
    disableLocalAuth: false
    disableKeyBasedMetadataWriteAccess: false
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    minimalTlsVersion: 'Tls12'
  }
}

resource cosmosSqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: cosmosDatabaseName
  parent: cosmosAccount
  location: location
  tags: commonTags
  properties: {
    resource: {
      id: cosmosDatabaseName
    }
  }
}

module aiSearch './modules/ai-search.bicep' = {
  name: 'aiSearchDeployment'
  params: {
    name: searchServiceName
    location: location
    sku: isProduction ? 'basic' : 'free'
    tags: commonTags
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: containerAppsEnvironmentName
  location: location
  tags: commonTags
  properties: {
    appInsightsConfiguration: {
      connectionString: applicationInsights.properties.ConnectionString
    }
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    openTelemetryConfiguration: {
      logsConfiguration: {
        destinations: [
          'appInsights'
        ]
      }
      tracesConfiguration: {
        destinations: [
          'appInsights'
        ]
      }
    }
    publicNetworkAccess: 'Enabled'
    zoneRedundant: false
    peerTrafficConfiguration: {
      encryption: {
        enabled: true
      }
    }
  }
}

module catalogService './modules/container-app.bicep' = {
  name: 'catalogServiceDeployment'
  params: {
    name: catalogServiceName
    location: location
    environmentId: containerAppsEnvironment.id
    registryServer: containerRegistry.properties.loginServer
    registryIdentityResourceId: registryPullIdentity.id
    cpu: isProduction ? prodCpu : nonProdCpu
    memory: isProduction ? prodMemory : nonProdMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cosmosConnectionString: cosmosConnectionString
    cosmosDatabaseName: cosmosSqlDatabase.name
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraAudience: entraAudience
    openTelemetryEndpoint: openTelemetryEndpoint
    disableAuthentication: disableAuthentication
    tags: union(commonTags, {
      'azd-service-name': 'catalog'
      service: 'catalog'
    })
  }
  dependsOn: [
    registryPullIdentityAcrPull
  ]
}

module orderService './modules/container-app.bicep' = {
  name: 'orderServiceDeployment'
  params: {
    name: orderServiceName
    location: location
    environmentId: containerAppsEnvironment.id
    registryServer: containerRegistry.properties.loginServer
    registryIdentityResourceId: registryPullIdentity.id
    cpu: isProduction ? prodCpu : nonProdCpu
    memory: isProduction ? prodMemory : nonProdMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cosmosConnectionString: cosmosConnectionString
    cosmosDatabaseName: cosmosSqlDatabase.name
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraAudience: entraAudience
    openTelemetryEndpoint: openTelemetryEndpoint
    disableAuthentication: disableAuthentication
    tags: union(commonTags, {
      'azd-service-name': 'order'
      service: 'order'
    })
  }
  dependsOn: [
    registryPullIdentityAcrPull
  ]
}

module notificationService './modules/container-app.bicep' = {
  name: 'notificationServiceDeployment'
  params: {
    name: notificationServiceName
    location: location
    environmentId: containerAppsEnvironment.id
    registryServer: containerRegistry.properties.loginServer
    registryIdentityResourceId: registryPullIdentity.id
    cpu: isProduction ? prodCpu : nonProdCpu
    memory: isProduction ? prodMemory : nonProdMemory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    cosmosConnectionString: cosmosConnectionString
    cosmosDatabaseName: cosmosSqlDatabase.name
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraAudience: entraAudience
    openTelemetryEndpoint: openTelemetryEndpoint
    disableAuthentication: disableAuthentication
    tags: union(commonTags, {
      'azd-service-name': 'notification'
      service: 'notification'
    })
  }
  dependsOn: [
    registryPullIdentityAcrPull
  ]
}

output ACR_NAME string = containerRegistry.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AI_SEARCH_ENDPOINT string = aiSearch.outputs.endpoint
output AI_SEARCH_NAME string = aiSearch.outputs.name
output APPLICATION_INSIGHTS_NAME string = applicationInsights.name
output CATALOG_SERVICE_ENDPOINT string = catalogService.outputs.endpoint
output CATALOG_SERVICE_NAME string = catalogService.outputs.name
output CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output COSMOS_ACCOUNT_NAME string = cosmosAccount.name
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalyticsWorkspace.name
output NOTIFICATION_SERVICE_ENDPOINT string = notificationService.outputs.endpoint
output NOTIFICATION_SERVICE_NAME string = notificationService.outputs.name
output ORDER_SERVICE_ENDPOINT string = orderService.outputs.endpoint
output ORDER_SERVICE_NAME string = orderService.outputs.name
