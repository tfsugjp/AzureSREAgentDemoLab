// Bicep template for Microsoft Entra App Registration (API)
// Requires: Bicep v0.21.1+ with Microsoft Graph extension enabled
// Deploy: az deployment group create --resource-group <rg> --template-file entra-app.bicep --parameters appDisplayName='GlobalAzureDemo-API-Dev'

extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0'

@description('Display name for the API application registration')
param appDisplayName string

@description('Sign-in audience for the application. Use AzureADMyOrg for single-tenant.')
@allowed([
  'AzureADMyOrg'
  'AzureADMultipleOrgs'
  'AzureADandPersonalMicrosoftAccount'
  'PersonalMicrosoftAccount'
])
param signInAudience string = 'AzureADMyOrg'

@description('Tags for the application')
param tags array = [
  'GlobalAzureDemo2026'
  'ContainerApps'
  'API'
]

// Create the App Registration
resource apiAppRegistration 'Microsoft.Graph/applications@v1.0' = {
  displayName: appDisplayName
  uniqueName: toLower(replace(appDisplayName, ' ', '-'))
  signInAudience: signInAudience
  tags: tags

  // API identifier (audience) - this will be used for JWT validation
  identifierUris: [
    'api://${appDisplayName}'
  ]

  // API definition - expose scopes for client applications
  api: {
    // Version 2 tokens (recommended)
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: guid('access_as_user', appDisplayName)
        adminConsentDisplayName: 'Access API as user'
        adminConsentDescription: 'Allows the app to access the API on behalf of the signed-in user'
        userConsentDisplayName: 'Access API as you'
        userConsentDescription: 'Allows the app to access the API on your behalf'
        value: 'access_as_user'
        type: 'User'
        isEnabled: true
      }
    ]
  }

  // App roles for service-to-service authorization (optional)
  appRoles: [
    {
      id: guid('Catalog.Read', appDisplayName)
      displayName: 'Catalog.Read'
      description: 'Read access to catalog data'
      value: 'Catalog.Read'
      allowedMemberTypes: ['Application']
      isEnabled: true
    }
    {
      id: guid('Order.ReadWrite', appDisplayName)
      displayName: 'Order.ReadWrite'
      description: 'Read and write access to order data'
      value: 'Order.ReadWrite'
      allowedMemberTypes: ['Application']
      isEnabled: true
    }
    {
      id: guid('Notification.Send', appDisplayName)
      displayName: 'Notification.Send'
      description: 'Send notifications'
      value: 'Notification.Send'
      allowedMemberTypes: ['Application']
      isEnabled: true
    }
  ]

  // Optional claims for enhanced token information
  optionalClaims: {
    idToken: [
      {
        name: 'email'
        essential: false
      }
    ]
    accessToken: [
      {
        name: 'email'
        essential: false
      }
      {
        name: 'upn'
        essential: false
      }
    ]
  }
}

// Create Service Principal (Enterprise Application)
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: apiAppRegistration.appId
  displayName: appDisplayName
  tags: [
    'WindowsAzureActiveDirectoryIntegratedApp'
  ]
  // Set to true to require app role assignment for users/apps
  appRoleAssignmentRequired: false
  preferredSingleSignOnMode: 'oidc'
}

// Outputs - these values are needed for Container Apps configuration
@description('Application (Client) ID - use for ENTRA_CLIENT_ID')
output applicationId string = apiAppRegistration.appId

@description('Object ID of the application registration')
output objectId string = apiAppRegistration.id

@description('Service Principal Object ID')
output servicePrincipalId string = servicePrincipal.id

@description('API Identifier URI (Audience) - use for ENTRA_AUDIENCE')
output identifierUri string = apiAppRegistration.identifierUris[0]

@description('Tenant ID - get from current tenant context')
output tenantIdInstruction string = 'Run: az account show --query tenantId -o tsv'
