@description('Name for the Virtual Network.')
param name string

@description('Azure region for the VNet.')
param location string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Address space for the VNet.')
param addressPrefix string = '10.1.0.0/16'

@description('Address prefix for the AKS node subnet.')
param aksSubnetPrefix string = '10.1.0.0/20'

@description('Address prefix for the AGC association subnet. Must be at least /24.')
param agcSubnetPrefix string = '10.1.16.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: aksSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-agc'
        properties: {
          addressPrefix: agcSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.ServiceNetworking.trafficControllers'
              properties: {
                serviceName: 'Microsoft.ServiceNetworking/trafficControllers'
              }
            }
          ]
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output aksSubnetId string = vnet.properties.subnets[0].id
output agcSubnetId string = vnet.properties.subnets[1].id
