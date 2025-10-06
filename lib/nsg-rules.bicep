// Pre-built NSG rule sets for common scenarios
// Import these in your deployments using: import {ruleSetName} from '../lib/nsg-rules.bicep'

import {NsgRule} from '../types/common.bicep'

@export()
@description('Standard web tier rules allowing HTTPS and HTTP from internet')
var webTierRules NsgRule[] = [
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

@export()
@description('API tier rules allowing HTTPS from VNet only')
var apiTierRules NsgRule[] = [
  {
    name: 'AllowHttpsFromVNet'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
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

@export()
@description('Database tier rules allowing SQL from VNet only')
var databaseTierRules NsgRule[] = [
  {
    name: 'AllowSqlFromVNet'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '1433'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowPostgresFromVNet'
    priority: 110
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '5432'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowMySqlFromVNet'
    priority: 120
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '3306'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
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

@export()
@description('Management tier rules allowing RDP/SSH from bastion subnet only')
func managementTierRules(bastionSubnetPrefix string) NsgRule[] => [
  {
    name: 'AllowSshFromBastion'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: bastionSubnetPrefix
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowRdpFromBastion'
    priority: 110
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '3389'
    sourceAddressPrefix: bastionSubnetPrefix
    destinationAddressPrefix: '*'
  }
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

@export()
@description('Private endpoint subnet rules')
var privateEndpointRules NsgRule[] = [
  {
    name: 'AllowVnetInbound'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'VirtualNetwork'
  }
  {
    name: 'AllowAzureLoadBalancerInbound'
    priority: 110
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'AzureLoadBalancer'
    destinationAddressPrefix: '*'
  }
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

@export()
@description('Combine multiple rule sets into one array')
func combineRuleSets(ruleSets NsgRule[][]) NsgRule[] =>
  reduce(ruleSets, [], (acc, ruleSet) => concat(acc, ruleSet))

@export()
@description('Filter rules by direction')
func filterRulesByDirection(rules NsgRule[], direction string) NsgRule[] =>
  filter(rules, rule => rule.direction == direction)

@export()
@description('Create a custom rule with smart defaults')
func createRule(
  name string,
  priority int,
  destinationPort string,
  sourcePrefix string?,
  direction string?
) NsgRule => {
  name: name
  priority: priority
  direction: direction ?? 'Inbound'
  access: 'Allow'
  protocol: 'Tcp'
  sourcePortRange: '*'
  destinationPortRange: destinationPort
  sourceAddressPrefix: sourcePrefix ?? 'Internet'
  destinationAddressPrefix: '*'
}
