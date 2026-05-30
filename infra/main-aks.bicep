// ================================================================
// main-aks.bicep — AKS + Application Gateway for Containers
// ================================================================
// AKS デプロイパス用メイン Bicep ファイル。
// Container Apps 用の main.bicep とは独立して使用します。
//
// デプロイ例:
//   az deployment group create \
//     --resource-group rg-azure-sre-agent-demo-lab \
//     --template-file infra/main-aks.bicep \
//     --parameters environmentName=dev entraTenantId=<tid> entraClientId=<cid> entraAudience=<aud>
// ================================================================

@description('Unique environment name (e.g., dev, test, prod, workshop-a).')
param environmentName string

@description('Primary Azure region. Defaults to westus3.')
param location string = 'westus3'

@description('Logical environment type. Any value other than prod is treated as non-production.')
param environmentType string = 'dev'

@description('Microsoft Entra tenant ID for JWT validation.')
param entraTenantId string

@description('Microsoft Entra application (client) ID for JWT validation.')
param entraClientId string

@description('Microsoft Entra audience / App ID URI for JWT validation.')
param entraAudience string

@description('Cosmos DB database name.')
param cosmosDatabaseName string = 'GlobalAzureDemo'

@description('VM size for the AKS system node pool.')
param aksNodeVmSize string = 'Standard_D2s_v5'

@description('Number of nodes in the AKS system node pool.')
param aksNodeCount int = 2

@description('Optional extra tags applied to all resources.')
param tags object = {}

// ── Naming ──────────────────────────────────────────────────────

var envToken = toLower(take(environmentName, 12))
var compactEnvToken = replace(envToken, '-', '')
var uniqueToken = toLower(take(uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location), 6))
var isProduction = toLower(environmentType) == 'prod'
var commonTags = union(tags, {
  'azd-env-name': environmentName
  environment: environmentName
  environmentType: environmentType
  project: 'AzureSREAgentDemoLab'
  workload: 'education'
  hostingPlatform: 'aks'
})

var vnetName = take('vnet-${envToken}-${uniqueToken}', 64)
var aksClusterName = take('aks-${envToken}-${uniqueToken}', 63)
var acrName = take('gad${compactEnvToken}${uniqueString(subscription().subscriptionId, resourceGroup().id, environmentName, location)}', 50)
var logAnalyticsName = take('law-${envToken}-${uniqueToken}', 63)
var appInsightsName = take('appi-${envToken}-${uniqueToken}', 64)
var cosmosAccountName = take('cosmos-${envToken}-${uniqueToken}', 44)
var agcName = take('agc-${envToken}-${uniqueToken}', 63)
var agcFrontendName = take('fe-${envToken}-${uniqueToken}', 63)
var albIdentityName = take('id-alb-${envToken}-${uniqueToken}', 128)
var aksNodeResourceGroupName = take('rg-aksnodes-${envToken}-${uniqueToken}', 90)
var readerRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'acdd72a7-3385-48ef-bd42-f606fba81ae7'
)

// ── Shared Resources ────────────────────────────────────────────

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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  tags: commonTags
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

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

// ── VNet ─────────────────────────────────────────────────────────

module vnet './modules/vnet.bicep' = {
  name: 'vnetDeployment'
  params: {
    name: vnetName
    location: location
    tags: commonTags
  }
}

// ── AKS Cluster ──────────────────────────────────────────────────

module aksCluster './modules/aks-cluster.bicep' = {
  name: 'aksClusterDeployment'
  params: {
    name: aksClusterName
    location: location
    tags: commonTags
    aksSubnetId: vnet.outputs.aksSubnetId
    systemNodeVmSize: aksNodeVmSize
    systemNodeCount: isProduction ? aksNodeCount : 2
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    nodeResourceGroupName: aksNodeResourceGroupName
  }
}

// ── ACR Pull RBAC for AKS ────────────────────────────────────────

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, aksClusterName, 'acrpull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: aksCluster.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

// ── Application Gateway for Containers ───────────────────────────

module agc './modules/agc.bicep' = {
  name: 'agcDeployment'
  params: {
    name: agcName
    location: location
    tags: commonTags
    frontendName: agcFrontendName
    agcSubnetId: vnet.outputs.agcSubnetId
    albIdentityName: albIdentityName
    aksOidcIssuerUrl: aksCluster.outputs.oidcIssuerUrl
  }
}

module albReaderOnNodeResourceGroup './modules/resource-group-role-assignment.bicep' = {
  name: 'albReaderOnNodeResourceGroup'
  scope: resourceGroup(subscription().subscriptionId, aksNodeResourceGroupName)
  params: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: agc.outputs.albIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ──────────────────────────────────────────────────────

output AKS_CLUSTER_NAME string = aksCluster.outputs.clusterName
output AKS_CLUSTER_FQDN string = aksCluster.outputs.clusterFqdn
output ACR_NAME string = containerRegistry.name
output ACR_LOGIN_SERVER string = containerRegistry.properties.loginServer
output AGC_NAME string = agc.outputs.agcName
output AGC_RESOURCE_ID string = agc.outputs.agcId
output AGC_FRONTEND_NAME string = agc.outputs.frontendName
output AGC_FRONTEND_FQDN string = agc.outputs.frontendFqdn
output ALB_IDENTITY_CLIENT_ID string = agc.outputs.albIdentityClientId
output APPLICATION_INSIGHTS_NAME string = applicationInsights.name
output APPLICATION_INSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString
output COSMOS_ACCOUNT_NAME string = cosmosAccount.name
output COSMOS_DATABASE_NAME string = cosmosSqlDatabase.name
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalyticsWorkspace.name
output VNET_NAME string = vnet.outputs.vnetName
output ENTRA_TENANT_ID string = entraTenantId
output ENTRA_CLIENT_ID string = entraClientId
output ENTRA_AUDIENCE string = entraAudience
