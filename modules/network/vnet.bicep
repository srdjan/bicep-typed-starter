type Region = 'eastus' | 'westeurope' | 'westus'

type VnetInput = {
  @minLength(3)
  @maxLength(64)
  name: string
  location: Region
  @minLength(1)
  addressSpaces: string[]
  @minLength(1)
  subnets: {
    @minLength(1)
    @maxLength(80)
    name: string
    prefix: string
    nsgId: string?
  }[]
}

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
