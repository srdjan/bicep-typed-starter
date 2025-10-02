type VnetInput={name:string addressSpaces:string[] subnets:{name:string prefix:string nsgId?:string}[]}
param input VnetInput
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {name: input.name location: resourceGroup().location properties:{addressSpace:{addressPrefixes: input.addressSpaces} subnets:[for s in input.subnets:{name:s.name properties:{addressPrefix:s.prefix networkSecurityGroup: empty(s.nsgId)? null: {id:s.nsgId}}}]}}
output subnetIds array = [for s in input.subnets: resourceId('Microsoft.Network/virtualNetworks/subnets', input.name, s.name)]