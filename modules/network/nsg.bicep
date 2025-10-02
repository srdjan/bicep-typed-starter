type NsgRule = {
  @minLength(1)
  @maxLength(80)
  name: string
  @description('Priority between 100-4096')
  @minValue(100)
  @maxValue(4096)
  priority: int
  direction: 'Inbound' | 'Outbound'
  access: 'Allow' | 'Deny'
  protocol: 'Tcp' | 'Udp' | 'Icmp' | '*'
  sourcePortRange: string
  destinationPortRange: string
  sourceAddressPrefix: string
  destinationAddressPrefix: string
}

type NsgInput = {
  @minLength(1)
  @maxLength(80)
  name: string
  location: string
  rules: NsgRule[]
  tags: object?
}

@description('Network Security Group configuration including rules')
param input NsgInput

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: input.name
  location: input.location
  tags: input.tags ?? {}
  properties: {
    securityRules: [
      for rule in input.rules: {
        name: rule.name
        properties: {
          priority: rule.priority
          direction: rule.direction
          access: rule.access
          protocol: rule.protocol
          sourcePortRange: rule.sourcePortRange
          destinationPortRange: rule.destinationPortRange
          sourceAddressPrefix: rule.sourceAddressPrefix
          destinationAddressPrefix: rule.destinationAddressPrefix
        }
      }
    ]
  }
}

@description('Resource ID of the Network Security Group')
output nsgId string = nsg.id

@description('Name of the Network Security Group')
output nsgName string = nsg.name
