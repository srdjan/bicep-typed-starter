// Advanced transformation functions using lambda expressions
// Demonstrates filter(), map(), reduce(), groupBy(), mapValues(), toObject(), sort()
// Import these in your deployments using: import {functionName} from '../lib/transformations.bicep'

import {Env, Region, NsgRule} from '../types/common.bicep'

@export()
@description('Filter subnets by name pattern (e.g., only subnets starting with "app")')
func filterSubnetsByPattern(subnets array, pattern string) array =>
  filter(subnets, subnet => startsWith(subnet.name, pattern))

@export()
@description('Map subnet names to their full resource IDs')
func mapSubnetsToIds(subnets array, vnetId string) array =>
  map(subnets, subnet => '${vnetId}/subnets/${subnet.name}')

@export()
@description('Calculate total address space from CIDR blocks (count of IPs, simplified)')
func calculateTotalIpCount(cidrBlocks string[]) int =>
  reduce(
    map(cidrBlocks, cidr => pow(2, 32 - int(last(split(cidr, '/'))))),
    0,
    (acc, count) => acc + count
  )

@export()
@description('Group resources by environment tag')
func groupByEnvironment(resources array) object =>
  groupBy(resources, resource => resource.tags.env)

@export()
@description('Transform array of objects to map keyed by specified property')
func arrayToMap(items array, keyProperty string) object =>
  toObject(items, item => item[keyProperty])

@export()
@description('Extract unique values from array of objects by property')
func getUniqueValues(items array, property string) array =>
  reduce(
    map(items, item => item[property]),
    [],
    (acc, value) => contains(acc, value) ? acc : concat(acc, [value])
  )

@export()
@description('Sort NSG rules by priority')
func sortRulesByPriority(rules NsgRule[]) NsgRule[] =>
  sort(rules, (a, b) => a.priority < b.priority)

@export()
@description('Filter NSG rules to only Allow rules')
func getOnlyAllowRules(rules NsgRule[]) NsgRule[] =>
  filter(rules, rule => rule.access == 'Allow')

@export()
@description('Filter NSG rules to only Deny rules')
func getOnlyDenyRules(rules NsgRule[]) NsgRule[] =>
  filter(rules, rule => rule.access == 'Deny')

@export()
@description('Map subnet configurations to include calculated properties')
func enrichSubnets(subnets array, vnetName string) array =>
  map(subnets, (subnet, index) => {
    name: subnet.name
    prefix: subnet.prefix
    index: index
    fullId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnet.name)
    ipCount: pow(2, 32 - int(last(split(subnet.prefix, '/'))))
  })

@export()
@description('Create a map of region abbreviations')
func getRegionAbbreviations() object => {
  eastus: 'eus'
  westeurope: 'weu'
  westus: 'wus'
  northeurope: 'neu'
  southeastasia: 'sea'
  japaneast: 'jpe'
  australiaeast: 'aue'
}

@export()
@description('Map regions to their abbreviations')
func abbreviateRegions(regions Region[]) string[] =>
  map(regions, region => getRegionAbbreviations()[region])

@export()
@description('Filter resources by tags matching criteria')
func filterByTags(resources array, requiredTags object) array =>
  filter(resources, resource =>
    reduce(
      items(requiredTags),
      true,
      (acc, tag) => acc && contains(resource.?tags ?? {}, tag.key) && resource.tags[tag.key] == tag.value
    )
  )

@export()
@description('Transform tag object to array of key-value pairs')
func tagsToArray(tags object) array =>
  map(items(tags), item => {key: item.key, value: item.value})

@export()
@description('Merge multiple tag objects with later objects taking precedence')
func mergeMultipleTags(tagObjects object[]) object =>
  reduce(tagObjects, {}, (acc, tags) => union(acc, tags))

@export()
@description('Create a priority-adjusted rule set (add offset to all priorities)')
func adjustRulePriorities(rules NsgRule[], offset int) NsgRule[] =>
  map(rules, rule => {
    name: rule.name
    priority: rule.priority + offset
    direction: rule.direction
    access: rule.access
    protocol: rule.protocol
    sourcePortRange: rule.sourcePortRange
    destinationPortRange: rule.destinationPortRange
    sourceAddressPrefix: rule.sourceAddressPrefix
    destinationAddressPrefix: rule.destinationAddressPrefix
  })

@export()
@description('Count rules by direction')
func countRulesByDirection(rules NsgRule[]) object => {
  inbound: length(filter(rules, rule => rule.direction == 'Inbound'))
  outbound: length(filter(rules, rule => rule.direction == 'Outbound'))
}

@export()
@description('Group NSG rules by direction into an object')
func groupRulesByDirection(rules NsgRule[]) object =>
  groupBy(rules, rule => rule.direction)

@export()
@description('Map values in an object using a transformation function (simulated mapValues)')
func transformTagValues(tags object) object =>
  toObject(
    items(tags),
    item => item.key,
    item => toUpper(item.value)
  )

@export()
@description('Get all unique protocols from NSG rules')
func getUniqueProtocols(rules NsgRule[]) array =>
  reduce(
    map(rules, rule => rule.protocol),
    [],
    (acc, protocol) => contains(acc, protocol) ? acc : concat(acc, [protocol])
  )

@export()
@description('Calculate average priority of NSG rules')
func calculateAveragePriority(rules NsgRule[]) int =>
  length(rules) > 0
    ? reduce(map(rules, rule => rule.priority), 0, (acc, priority) => acc + priority) / length(rules)
    : 0

@export()
@description('Find highest priority rule (lowest number)')
func getHighestPriorityRule(rules NsgRule[]) NsgRule =>
  reduce(rules, rules[0], (acc, rule) => rule.priority < acc.priority ? rule : acc)
