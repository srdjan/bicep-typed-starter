// ============================================================================
// ADVANCED BICEP FEATURES SHOWCASE
// ============================================================================
// This example demonstrates:
// - Import/Export system with @export decorator
// - Spread operator for object/array composition
// - Lambda functions (filter, map, reduce, groupBy, sort)
// - User-defined functions
// - Type-safe discriminated unions
// - Advanced nullability operators (.?, ??, !)
// ============================================================================

// Import shared types
import {Env, Region, TagPolicy, NsgRule} from '../types/common.bicep'

// Import helper functions
import {
  generateResourceName
  buildTags
  getCapacityForEnv
  getRetentionDaysForEnv
  isProduction
  mergeTags
} from '../lib/helpers.bicep'

// Import pre-built NSG rule sets
import {webTierRules, apiTierRules, combineRuleSets} from '../lib/nsg-rules.bicep'

// Import transformation functions (lambda examples)
import {
  sortRulesByPriority
  getOnlyAllowRules
  filterSubnetsByPattern
  enrichSubnets
  calculateTotalIpCount
} from '../lib/transformations.bicep'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Environment identifier')
param environment Env = 'dev'

@description('Azure region for deployment')
param location Region = 'eastus'

@description('Project name for resource naming')
@minLength(3)
@maxLength(20)
param projectName string = 'advanced'

@description('Additional custom tags to merge with required tags')
param customTags object = {}

// ============================================================================
// VARIABLES - Demonstrating spread operator and functions
// ============================================================================

// Use user-defined function to build tags
var requiredTags = buildTags(environment, 'platform-team', projectName, isProduction(environment) ? 'PROD-001' : 'DEV-001', null)

// Use spread operator to merge custom tags
var allTags = {
  ...requiredTags
  ...customTags
  deployedBy: 'advanced-features-example'
}

// Define subnets with various configurations
var rawSubnets = [
  {name: 'app-web', prefix: '10.0.1.0/24', nsgId: null}
  {name: 'app-api', prefix: '10.0.2.0/24', nsgId: null}
  {name: 'data-sql', prefix: '10.0.3.0/24', nsgId: null}
  {name: 'mgmt-bastion', prefix: '10.0.4.0/24', nsgId: null}
]

// Use lambda functions to filter and transform subnets
var vnetName = generateResourceName('vnet', projectName, environment, location)
var appSubnets = filterSubnetsByPattern(rawSubnets, 'app')
var enrichedSubnets = enrichSubnets(rawSubnets, vnetName)
var totalIpCount = calculateTotalIpCount(map(rawSubnets, subnet => subnet.prefix))

// Combine NSG rule sets using spread operator and lambda functions
var baseRules = [
  ...webTierRules
  ...apiTierRules
]

// Use lambda to filter and sort rules
var allowRulesOnly = getOnlyAllowRules(baseRules)
var sortedRules = sortRulesByPriority(baseRules)

// Use reduce to find the highest priority number used
var highestPriorityUsed = reduce(
  map(baseRules, rule => rule.priority),
  0,
  (acc, priority) => priority > acc ? priority : acc
)

// ============================================================================
// OUTPUTS - Demonstrating computed values
// ============================================================================

@description('All computed tags')
output tags object = allTags

@description('Is this a production environment')
output isProductionEnv bool = isProduction(environment)

@description('Recommended capacity for this environment')
output recommendedCapacity int = getCapacityForEnv(environment, 'premium')

@description('Recommended retention days')
output recommendedRetention int = getRetentionDaysForEnv(environment)

@description('Total IP addresses available across all subnets')
output totalAvailableIps int = totalIpCount

@description('Number of application subnets (filtered by pattern)')
output appSubnetCount int = length(appSubnets)

@description('Enriched subnet details with calculated properties')
output subnetDetails array = enrichedSubnets

@description('Total NSG rules in combined set')
output totalRules int = length(baseRules)

@description('Number of Allow rules')
output allowRuleCount int = length(allowRulesOnly)

@description('Highest priority number used in rule set')
output highestPriority int = highestPriorityUsed

@description('First rule by priority (sorted)')
output firstRule object = sortedRules[0]

// ============================================================================
// ADVANCED PATTERN: Conditional resource deployment with discriminated union
// ============================================================================

@description('Deployment mode configuration (discriminated union example)')
param deploymentMode {kind: 'simple'} | {kind: 'advanced', features: string[]} = {kind: 'simple'}

// Type-safe access to union variant properties
var isAdvancedMode = deploymentMode.kind == 'advanced'
var features = isAdvancedMode ? deploymentMode.features : []

@description('Deployment mode')
output mode string = deploymentMode.kind

@description('Enabled features (only for advanced mode)')
output enabledFeatures array = features

// ============================================================================
// ADVANCED PATTERN: Object transformation with mapValues simulation
// ============================================================================

// Create a configuration map
var tierConfig = {
  basic: {sku: 'B1', capacity: 1}
  standard: {sku: 'S1', capacity: 2}
  premium: {sku: 'P1v3', capacity: 3}
}

// Transform to array and use lambda
var tierConfigArray = map(
  items(tierConfig),
  item => {
    tier: item.key
    sku: item.value.sku
    capacity: item.value.capacity
    recommended: item.key == 'premium'
  }
)

@description('Tier configuration transformed to array')
output tierConfigurations array = tierConfigArray

// ============================================================================
// ADVANCED PATTERN: Safe navigation with nullability operators
// ============================================================================

@description('Optional diagnostics workspace ID')
param diagnosticsWorkspaceId string?

@description('Optional retention days override')
param retentionDaysOverride int?

// Use safe navigation (.?) and coalesce (??) operators
var workspaceIdToUse = diagnosticsWorkspaceId ?? null
var retentionToUse = retentionDaysOverride ?? getRetentionDaysForEnv(environment)
var diagnosticsEnabled = workspaceIdToUse != null

@description('Diagnostics configuration status')
output diagnosticsConfig object = {
  enabled: diagnosticsEnabled
  workspaceId: workspaceIdToUse
  retentionDays: retentionToUse
}

// ============================================================================
// ADVANCED PATTERN: Array composition with spread operator
// ============================================================================

var baseAppSettings = [
  {name: 'ENVIRONMENT', value: environment}
  {name: 'PROJECT_NAME', value: projectName}
  {name: 'LOCATION', value: location}
]

var conditionalSettings = isProduction(environment)
  ? [{name: 'PRODUCTION_MODE', value: 'true'}, {name: 'DEBUG', value: 'false'}]
  : [{name: 'PRODUCTION_MODE', value: 'false'}, {name: 'DEBUG', value: 'true'}]

// Use spread to combine arrays
var allAppSettings = [
  ...baseAppSettings
  ...conditionalSettings
]

@description('Combined application settings')
output appSettings array = allAppSettings

// ============================================================================
// ADVANCED PATTERN: GroupBy and aggregation
// ============================================================================

var resources = [
  {name: 'web-1', type: 'web', env: 'prod'}
  {name: 'web-2', type: 'web', env: 'dev'}
  {name: 'api-1', type: 'api', env: 'prod'}
  {name: 'db-1', type: 'database', env: 'prod'}
]

// Group resources by type using groupBy lambda
var resourcesByType = groupBy(resources, resource => resource.type)

@description('Resources grouped by type')
output groupedResources object = resourcesByType

// Count resources by type using reduce
var resourceCounts = toObject(
  items(resourcesByType),
  item => item.key,
  item => length(item.value)
)

@description('Resource counts by type')
output resourceCountByType object = resourceCounts
