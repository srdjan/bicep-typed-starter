// Reusable helper functions with @export decorator
// Import these functions in other files using: import {functionName} from '../lib/helpers.bicep'

import {Env, Region, AppTier, TagPolicy} from '../types/common.bicep'

@export()
@description('Generate a standardized resource name following naming conventions')
func generateResourceName(resourceType string, projectName string, env Env, region Region) string =>
  toLower('${resourceType}-${projectName}-${env}-${region}')

@export()
@description('Build a complete tag set by merging required tags with optional custom tags')
func buildTags(env Env, owner string, project string, costCenter string?, customTags object?) object => {
  env: env
  owner: owner
  project: project
  ...((costCenter != null) ? {costCenter: costCenter} : {})
  ...((customTags != null) ? customTags : {})
}

@export()
@description('Map abstract application tier to Azure SKU configuration')
func getSkuForTier(tier AppTier) object =>
  tier == 'basic'
    ? {name: 'B1', tier: 'Basic'}
    : tier == 'standard'
      ? {name: 'S1', tier: 'Standard'}
      : {name: 'P1v3', tier: 'PremiumV3'}

@export()
@description('Validate CIDR notation format (basic check)')
func isValidCidr(cidr string) bool =>
  contains(cidr, '/') && length(split(cidr, '/')) == 2

@export()
@description('Extract subscription ID from a resource ID')
func getSubscriptionIdFromResourceId(resourceId string) string =>
  split(resourceId, '/')[2]

@export()
@description('Extract resource group name from a resource ID')
func getResourceGroupFromResourceId(resourceId string) string =>
  split(resourceId, '/')[4]

@export()
@description('Extract resource name from a resource ID')
func getResourceNameFromResourceId(resourceId string) string =>
  last(split(resourceId, '/'))

@export()
@description('Validate App Service name against naming rules (lowercase alphanumeric and hyphens, 3-60 chars)')
func isValidAppServiceName(name string) bool =>
  length(name) >= 3 && length(name) <= 60 && name == toLower(name)

@export()
@description('Generate a unique suffix using hash of input values')
func generateUniqueSuffix(seed string, length int) string =>
  substring(uniqueString(seed), 0, length)

@export()
@description('Determine if an environment is production')
func isProduction(env Env) bool =>
  env == 'prod'

@export()
@description('Get recommended retention days based on environment')
func getRetentionDaysForEnv(env Env) int =>
  env == 'prod' ? 90 : env == 'test' ? 30 : 7

@export()
@description('Get recommended capacity based on environment and tier')
func getCapacityForEnv(env Env, tier AppTier) int =>
  env == 'prod' && tier == 'premium'
    ? 3
    : env == 'prod'
      ? 2
      : 1

@export()
@description('Build auto-scale settings with intelligent defaults based on environment')
func buildAutoScaleSettings(env Env, minCapacity int?, maxCapacity int?) object =>
  env == 'prod'
    ? {
        minCapacity: minCapacity ?? 3
        maxCapacity: maxCapacity ?? 10
        defaultCapacity: minCapacity ?? 3
        scaleOutCpuThreshold: 75
        scaleInCpuThreshold: 25
      }
    : {
        minCapacity: minCapacity ?? 2
        maxCapacity: maxCapacity ?? 5
        defaultCapacity: minCapacity ?? 2
        scaleOutCpuThreshold: 80
        scaleInCpuThreshold: 20
      }

@export()
@description('Convert an array of strings to lowercase')
func toLowerArray(arr string[]) array =>
  map(arr, item => toLower(item))

@export()
@description('Create a map of subnet names to their IDs from a VNet resource ID and subnet names')
func buildSubnetIdMap(vnetId string, subnetNames string[]) object =>
  toObject(subnetNames, name => name, name => '${vnetId}/subnets/${name}')

@export()
@description('Merge two tag objects with right-side precedence')
func mergeTags(baseTags object, overrideTags object) object => {
  ...baseTags
  ...overrideTags
}
