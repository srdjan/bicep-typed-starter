// Example: Creating an NSG with common web application rules
param location string = 'eastus'
param environment string = 'dev'

module webNsg '../modules/network/nsg.bicep' = {
  name: 'web-nsg'
  params: {
    input: {
      name: 'nsg-web-${environment}'
      location: location
      rules: [
        // Allow HTTPS inbound
        {
          name: 'AllowHttpsInbound'
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
        // Allow HTTP inbound (for redirect to HTTPS)
        {
          name: 'AllowHttpInbound'
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
        // Deny all other inbound traffic
        {
          name: 'DenyAllInbound'
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      ]
      tags: {
        environment: environment
        purpose: 'web-tier'
      }
    }
  }
}

output nsgId string = webNsg.outputs.nsgId
