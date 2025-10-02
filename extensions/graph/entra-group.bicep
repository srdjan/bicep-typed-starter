targetScope = 'tenant'
extension microsoftGraph

@description('Display name for the Entra ID security group')
@minLength(1)
@maxLength(256)
param groupName string = 'typed-ext-sample-group'

resource group 'microsoftGraph:group@2024-10-01-preview' = {
  displayName: groupName
  mailEnabled: false
  mailNickname: replace(toLower(groupName), ' ', '-')
  securityEnabled: true
}

@description('Object ID of the created Entra ID group')
output groupId string = group.id