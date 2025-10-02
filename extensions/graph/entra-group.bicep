targetScope='tenant'
extension microsoftGraph
param groupName string='typed-ext-sample-group'
resource group 'microsoftGraph:group@2024-10-01-preview'={displayName: groupName mailEnabled:false mailNickname: replace(toLower(groupName),' ','-') securityEnabled:true}
output groupId string = group.id