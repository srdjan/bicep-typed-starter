import {ApiManagementConfig} from '../../types/common.bicep'

@description('Azure API Management instance configuration')
param apim ApiManagementConfig

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apim.name
  location: apim.location
  sku: {
    name: apim.sku.name
    capacity: apim.sku.capacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: apim.tags ?? {}
  properties: {
    publisherEmail: apim.publisherEmail
    publisherName: apim.publisherName
    virtualNetworkType: apim.virtualNetworkType
    virtualNetworkConfiguration: apim.virtualNetworkType == 'None' || apim.subnetResourceId == null
      ? null
      : {
          subnetResourceId: apim.subnetResourceId!
        }
    enableClientCertificate: apim.enableClientCertificate ?? false
    publicIPAddresses: []
  }
}

@description('API Management resource ID')
output apimId string = apiManagement.id

@description('API Management gateway URL')
output gatewayUrl string = apiManagement.properties.gatewayUrl

@description('API Management managed identity principal ID')
output principalId string = apiManagement.identity.principalId
