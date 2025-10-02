targetScope = 'tenant'
extension microsoftGraph

@description('Display name for the Entra ID application registration')
@minLength(1)
@maxLength(256)
param appName string = 'typed-ext-sample-app'

resource app 'microsoftGraph:application@2024-10-01-preview' = {
  displayName: appName
}

resource sp 'microsoftGraph:servicePrincipal@2024-10-01-preview' = {
  appId: app.appId
}

@description('Application (client) ID of the registered application')
output appId string = app.appId

@description('Object ID of the service principal')
output spId string = sp.id