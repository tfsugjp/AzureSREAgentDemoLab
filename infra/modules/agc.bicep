@description('Name for the Application Gateway for Containers resource.')
param name string

@description('Azure region.')
param location string

@description('Tags to apply.')
param tags object = {}

@description('Name for the AGC frontend.')
param frontendName string

@description('Resource ID of the delegated subnet for AGC association.')
param agcSubnetId string

@description('Name for the user-assigned managed identity used by ALB Controller.')
param albIdentityName string

@description('OIDC issuer URL of the AKS cluster used for the federated identity credential issuer.')
param aksOidcIssuerUrl string

// User-assigned managed identity for ALB Controller workload identity
resource albIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: albIdentityName
  location: location
  tags: tags
}

// Federated identity credential for ALB Controller workload identity
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: 'alb-controller-federated-credential'
  parent: albIdentity
  properties: {
    issuer: aksOidcIssuerUrl
    subject: 'system:serviceaccount:azure-alb-system:alb-controller-sa'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

var agcVnetName = split(agcSubnetId, '/')[8]
var agcSubnetName = split(agcSubnetId, '/')[10]

resource agcVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: agcVnetName
}

resource agcSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: agcSubnetName
  parent: agcVnet
}

// Application Gateway for Containers (traffic controller)
resource agc 'Microsoft.ServiceNetworking/trafficControllers@2025-01-01' = {
  name: name
  location: location
  tags: tags
}

// AGC Frontend
resource frontend 'Microsoft.ServiceNetworking/trafficControllers/frontends@2025-01-01' = {
  name: frontendName
  parent: agc
  location: location
  properties: {}
}

// AGC Association (links AGC to the delegated subnet)
resource association 'Microsoft.ServiceNetworking/trafficControllers/associations@2025-01-01' = {
  name: '${name}-association'
  parent: agc
  location: location
  properties: {
    associationType: 'subnets'
    subnet: {
      id: agcSubnetId
    }
  }
}

// RBAC: AppGw for Containers Configuration Manager on resource group
// Role ID: fbc52c3f-28ad-4303-a892-8a056630b8f1
var agcConfigManagerRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'fbc52c3f-28ad-4303-a892-8a056630b8f1'
)

resource agcConfigManagerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, albIdentity.id, 'agc-config-manager')
  properties: {
    roleDefinitionId: agcConfigManagerRoleId
    principalId: albIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC: Network Contributor on AGC subnet for join permission
// Role ID: 4d97b98b-1d4f-4787-a291-c67834d212e7
var networkContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4d97b98b-1d4f-4787-a291-c67834d212e7'
)

resource subnetJoinRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agcSubnetId, albIdentity.id, 'subnet-join')
  scope: agcSubnet
  properties: {
    roleDefinitionId: networkContributorRoleId
    principalId: albIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output agcId string = agc.id
output agcName string = agc.name
output frontendName string = frontend.name
output frontendFqdn string = frontend.properties.fqdn
output albIdentityClientId string = albIdentity.properties.clientId
output albIdentityPrincipalId string = albIdentity.properties.principalId
