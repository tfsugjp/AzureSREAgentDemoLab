@description('Name of the Azure AI Search service.')
param name string

@description('Azure region for the resource.')
param location string

@description('SKU for the Azure AI Search service. Use free for dev/workshop, basic or standard for production.')
@allowed([
  'free'
  'basic'
  'standard'
])
param sku string = 'free'

@description('Tags to apply to the resource.')
param tags object = {}

resource searchService 'Microsoft.Search/searchServices@2024-06-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    publicNetworkAccess: 'enabled'
  }
}

@description('The name of the deployed AI Search service.')
output name string = searchService.name

@description('The endpoint URL of the AI Search service.')
output endpoint string = 'https://${searchService.name}.search.windows.net'
