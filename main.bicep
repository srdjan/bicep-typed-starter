// ============================================================================
// IMPORTS - Using @export/@import for shared types and functions
// ============================================================================

// Import shared types from central type library
import {
  Env
  Region
  AppTier
  TagPolicy
  Ingress
  Diagnostics
  AutoScaleSettings
  AppConfig
  VnetInput
} from './types/common.bicep'

// Import helper functions for tag management
import {mergeTags} from './lib/helpers.bicep'

@description('Environment identifier (dev, test, or prod)')
param env Env

@description('Project name used for resource naming and tagging')
@minLength(3)
@maxLength(24)
param project string

@description('Required tags policy for all resources')
param tags TagPolicy

@description('Application Service configuration')
param app AppConfig

@description('Virtual Network configuration')
param vnet VnetInput
// ============================================================================
// TAG COMPOSITION - Using spread operator for cleaner merging
// ============================================================================

// Build base tags from required parameters
var baseTags = {
  env: env
  owner: tags.owner
  project: project
}

// Use spread operator to merge optional costCenter tag (replaces union())
var commonTags = {
  ...baseTags
  ...((tags.costCenter != null) ? {costCenter: tags.costCenter} : {})
}

// ============================================================================
// MODULE DEPLOYMENTS
// ============================================================================

module net './modules/network/vnet.bicep' = { name: 'net', params: { input: vnet } }

// Use spread operator to merge app config with common tags
module web './modules/app/appservice.bicep' = {
  name: 'web'
  params: {
    app: {
      ...app
      tags: commonTags
    }
  }
}
// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the App Service')
output appId string = web.outputs.appId

@description('Resource ID of the App Service Plan')
output planId string = web.outputs.planId

@description('Principal ID of the App Service managed identity')
output appPrincipalId string = web.outputs.principalId

@description('Default hostname of the App Service')
output appHostname string = web.outputs.defaultHostname

@description('Array of subnet resource IDs')
output subnetIds array = net.outputs.subnetIds

@description('Resource ID of the Virtual Network')
output vnetId string = net.outputs.vnetId

@description('Name of the Virtual Network')
output vnetName string = net.outputs.vnetName
