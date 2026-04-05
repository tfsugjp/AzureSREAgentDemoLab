@description('Name for the AKS cluster.')
param name string

@description('Azure region for the cluster.')
param location string

@description('Tags to apply.')
param tags object = {}

@description('Resource ID of the subnet for AKS nodes.')
param aksSubnetId string

@description('Kubernetes version. Empty string uses the latest stable version.')
param kubernetesVersion string = ''

@description('VM size for the system node pool.')
param systemNodeVmSize string = 'Standard_D2s_v5'

@description('Number of nodes in the system node pool.')
param systemNodeCount int = 2

@description('Log Analytics workspace resource ID for monitoring.')
param logAnalyticsWorkspaceId string

@description('Whether to enable the ALB Controller add-on for Application Gateway for Containers.')
param enableAlbController bool = true

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-01-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: name
    kubernetesVersion: kubernetesVersion != '' ? kubernetesVersion : null
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
      podCidr: '192.168.0.0/16'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        count: systemNodeCount
        vmSize: systemNodeVmSize
        osType: 'Linux'
        osSKU: 'AzureLinux'
        mode: 'System'
        vnetSubnetID: aksSubnetId
        enableAutoScaling: true
        minCount: 1
        maxCount: systemNodeCount
      }
    ]
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    serviceMeshProfile: enableAlbController
      ? null
      : null
  }
}

output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output clusterIdentityPrincipalId string = aksCluster.identity.principalId
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
