import {VnetInput} from '../../types/common.bicep'

@description('Virtual Network configuration including address spaces and subnets')
param input VnetInput

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: input.name
  location: input.location
  properties: {
    addressSpace: {
      addressPrefixes: input.addressSpaces
    }
    subnets: [
      for s in input.subnets: {
        name: s.name
        properties: {
          addressPrefix: s.prefix
          networkSecurityGroup: s.nsgId == null
            ? null
            : {
                id: s.nsgId!
              }
          delegations: s.delegations == null
            ? []
            : [
                for delegation in s.delegations!: {
                  name: '${s.name}-${last(split(delegation, '/'))}'
                  properties: {
                    serviceName: delegation
                  }
                }
              ]
        }
      }
    ]
  }
}

@description('Array of subnet resource IDs')
output subnetIds array = [
  for s in input.subnets: resourceId('Microsoft.Network/virtualNetworks/subnets', input.name, s.name)
]

@description('Resource ID of the Virtual Network')
output vnetId string = vnet.id

@description('Name of the Virtual Network')
output vnetName string = vnet.name
