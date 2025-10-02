targetScope='tenant'
extension microsoftGraph
param appName string='typed-ext-sample-app'
resource app 'microsoftGraph:application@2024-10-01-preview'={displayName: appName}
resource sp 'microsoftGraph:servicePrincipal@2024-10-01-preview'={appId: app.appId}
output appId string = app.appId
output spId string = sp.id