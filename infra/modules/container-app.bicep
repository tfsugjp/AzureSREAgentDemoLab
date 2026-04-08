@description('Container App resource name.')
param name string

@description('Azure region for the resource.')
param location string

@description('Container Apps managed environment resource ID.')
param environmentId string

@description('Container registry login server.')
param registryServer string

@description('Resource ID of the user-assigned managed identity used for ACR image pulls.')
param registryIdentityResourceId string

@description('Public placeholder image used during provisioning before azd deploy updates the image. It must listen on port 8080 so the initial revision can become healthy.')
param image string = 'mcr.microsoft.com/dotnet/samples:aspnetapp'

@description('Container CPU allocation.')
param cpu int

@description('Container memory allocation, for example 0.5Gi.')
param memory string

@description('Minimum replica count for the service.')
param minReplicas int

@description('Maximum replica count for the service.')
param maxReplicas int

@secure()
@description('Cosmos DB connection string for the application.')
param cosmosConnectionString string

@description('Cosmos DB database name.')
param cosmosDatabaseName string

@description('Microsoft Entra tenant ID.')
param entraTenantId string

@description('Microsoft Entra application (client) ID.')
param entraClientId string

@description('Microsoft Entra audience / App ID URI.')
param entraAudience string

@description('Optional OTLP endpoint for app telemetry. Leave empty to disable app-side OTLP export.')
param openTelemetryEndpoint string = ''

@description('Set true only for simplified workshop scenarios that intentionally disable API auth.')
param disableAuthentication bool = false

@description('Whether the app should expose a public HTTPS endpoint.')
param externalIngress bool = true

@description('Additional tags to apply to the Container App.')
param tags object = {}

resource app 'Microsoft.App/containerApps@2026-01-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${registryIdentityResourceId}': {}
    }
  }
  tags: tags
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        allowInsecure: false
        external: externalIngress
        targetPort: 8080
        transport: 'http'
      }
      registries: [
        {
          server: registryServer
          identity: registryIdentityResourceId
        }
      ]
      secrets: [
        {
          name: 'cosmos-connection-string'
          value: cosmosConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: image
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'Authentication__DisableAuth'
              value: string(disableAuthentication)
            }
            {
              name: 'CosmosDb__ConnectionString'
              secretRef: 'cosmos-connection-string'
            }
            {
              name: 'CosmosDb__DatabaseName'
              value: cosmosDatabaseName
            }
            {
              name: 'AzureAd__TenantId'
              value: entraTenantId
            }
            {
              name: 'AzureAd__ClientId'
              value: entraClientId
            }
            {
              name: 'AzureAd__Audience'
              value: entraAudience
            }
            {
              name: 'OpenTelemetry__Endpoint'
              value: openTelemetryEndpoint
            }
          ]
          resources: {
            cpu: cpu
            memory: memory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output name string = app.name
output resourceId string = app.id
@description('Principal ID of the system-assigned managed identity. For ACR pull permissions, use the user-assigned identity referenced by registryIdentityResourceId.')
output systemAssignedPrincipalId string = app.identity.principalId
output endpoint string = empty(app.properties.configuration.ingress.?fqdn ?? '')
  ? ''
  : 'https://${app.properties.configuration.ingress.?fqdn ?? ''}'
