@description('Container App resource name.')
param name string

@description('Azure region for the resource.')
param location string

@description('Container Apps managed environment resource ID.')
param environmentId string

@description('Container registry login server.')
param registryServer string

@description('Public placeholder image used during provisioning before azd deploy updates the image.')
param image string = 'mcr.microsoft.com/k8se/quickstart:latest'

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
    type: 'SystemAssigned'
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
          identity: 'system'
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
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health/ready'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 30
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
              }
              initialDelaySeconds: 15
              periodSeconds: 15
              timeoutSeconds: 5
              failureThreshold: 6
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
output principalId string = app.identity.principalId
output endpoint string = empty(app.properties.configuration.ingress.?fqdn ?? '')
  ? ''
  : 'https://${app.properties.configuration.ingress.?fqdn ?? ''}'
