// ============================================================================
// MULTI-TIER SERVERLESS APPLICATION EXAMPLE
// ============================================================================
// This example demonstrates a complete serverless architecture using:
// - Azure Functions (API layer)
// - App Service (Web UI layer)
// - Storage Account (Data layer)
// - Application Insights (Monitoring)
// - VNet integration (Security)
// - All with advanced type safety, imports, spread operator, and lambda functions
//
// Architecture:
//   Internet → App Service (Web UI) → Azure Functions (API) → Storage (Data)
//                    ↓                        ↓                    ↓
//               Application Insights (Centralized Monitoring)
// ============================================================================

// Import shared types
import {Env, Region} from '../types/common.bicep'

// Import helper functions
import {
  generateResourceName
  buildTags
  isProduction
  getRetentionDaysForEnv
  getCapacityForEnv
  mergeTags
} from '../lib/helpers.bicep'

// Import NSG rules
import {webTierRules, apiTierRules} from '../lib/nsg-rules.bicep'

// Import transformations
import {enrichSubnets, calculateTotalIpCount} from '../lib/transformations.bicep'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Environment identifier')
param environment Env

@description('Azure region for all resources')
param location Region = 'eastus'

@description('Project name (used for resource naming)')
@minLength(3)
@maxLength(15)
param projectName string

@description('Log Analytics workspace ID for diagnostics')
param logAnalyticsWorkspaceId string?

@description('Allowed IP ranges for storage account (optional)')
param allowedStorageIpRanges string[] = []

// ============================================================================
// VARIABLES - Using spread operator and helper functions
// ============================================================================

// Build tags using helper function
var baseTags = buildTags(
  environment,
  'platform-team',
  projectName,
  isProduction(environment) ? 'PROD-SERVERLESS' : null,
  null
)

// Add architecture-specific tags with spread operator
var tags = {
  ...baseTags
  architecture: 'serverless-multitier'
  components: 'webapp-functions-storage'
}

// Generate resource names using helper function
var storageAccountName = toLower(replace(generateResourceName('st', projectName, environment, location), '-', ''))
var appServiceName = generateResourceName('app', projectName, environment, location)
var functionAppName = generateResourceName('func', projectName, environment, location)
var vnetName = generateResourceName('vnet', projectName, environment, location)
var appInsightsName = generateResourceName('ai', projectName, environment, location)

// Network configuration
var addressSpace = '10.0.0.0/16'
var subnetConfig = [
  {name: 'webapp', prefix: '10.0.1.0/24', nsgId: null}
  {name: 'functions', prefix: '10.0.2.0/24', nsgId: null}
  {name: 'storage', prefix: '10.0.3.0/24', nsgId: null}
]

// Use lambda functions to calculate network metrics
var enrichedSubnets = enrichSubnets(subnetConfig, vnetName)
var totalIpAddresses = calculateTotalIpCount(map(subnetConfig, s => s.prefix))

// Diagnostics configuration
var diagnosticsConfig = logAnalyticsWorkspaceId != null
  ? {
      workspaceId: logAnalyticsWorkspaceId
      retentionDays: getRetentionDaysForEnv(environment)
    }
  : null

// ============================================================================
// NETWORKING - VNet with subnets for each tier
// ============================================================================

module nsgWeb '../modules/network/nsg.bicep' = {
  name: 'nsg-web'
  params: {
    input: {
      name: '${vnetName}-web-nsg'
      location: location
      rules: webTierRules
      tags: tags
    }
  }
}

module nsgApi '../modules/network/nsg.bicep' = {
  name: 'nsg-api'
  params: {
    input: {
      name: '${vnetName}-api-nsg'
      location: location
      rules: apiTierRules
      tags: tags
    }
  }
}

module vnet '../modules/network/vnet.bicep' = {
  name: 'vnet'
  params: {
    input: {
      name: vnetName
      location: location
      addressSpaces: [addressSpace]
      subnets: [
        {
          name: 'webapp'
          prefix: '10.0.1.0/24'
          nsgId: nsgWeb.outputs.nsgId
        }
        {
          name: 'functions'
          prefix: '10.0.2.0/24'
          nsgId: nsgApi.outputs.nsgId
        }
        {
          name: 'storage'
          prefix: '10.0.3.0/24'
          nsgId: null
        }
      ]
    }
  }
}

// ============================================================================
// MONITORING - Application Insights
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

// ============================================================================
// DATA LAYER - Storage Account
// ============================================================================

module storage '../modules/storage/storageaccount.bicep' = {
  name: 'storage'
  params: {
    storage: {
      name: storageAccountName
      location: location
      sku: isProduction(environment) ? 'Standard_GRS' : 'Standard_LRS'
      storageKind: {
        kind: 'StorageV2'
        accessTier: 'Hot'
      }
      networkAccess: length(allowedStorageIpRanges) > 0
        ? {mode: 'public', allowedIpRanges: allowedStorageIpRanges}
        : {
            mode: 'private'
            vnetId: vnet.outputs.vnetId
            subnetName: 'storage'
          }
      enableHttpsOnly: true
      minimumTlsVersion: 'TLS1_2'
      enableBlobVersioning: isProduction(environment)
      enableContainerSoftDelete: true
      containerSoftDeleteRetentionDays: isProduction(environment) ? 30 : 7
      diagnostics: diagnosticsConfig
      tags: {
        ...tags
        tier: 'data'
      }
    }
  }
}

// ============================================================================
// API LAYER - Azure Functions
// ============================================================================

module functions '../modules/serverless/functionapp.bicep' = {
  name: 'functions'
  params: {
    func: {
      name: functionAppName
      location: location
      runtime: 'node'
      runtimeVersion: '20'
      hosting: isProduction(environment)
        ? {tier: 'premium', sku: 'EP1', workerCount: 2}
        : {tier: 'consumption'}
      storageAccountName: storage.outputs.storageName
      appInsightsName: appInsights.name
      alwaysOn: isProduction(environment)
      vnetIntegration: {
        vnetId: vnet.outputs.vnetId
        subnetName: 'functions'
      }
      diagnostics: diagnosticsConfig
      tags: {
        ...tags
        tier: 'api'
        runtime: 'node-20'
      }
    }
  }
  dependsOn: [
    appInsights
  ]
}

// ============================================================================
// WEB LAYER - App Service
// ============================================================================

module webapp '../modules/app/appservice.bicep' = {
  name: 'webapp'
  params: {
    app: {
      name: appServiceName
      location: location
      tier: isProduction(environment) ? 'premium' : 'basic'
      capacity: getCapacityForEnv(environment, isProduction(environment) ? 'premium' : 'basic')
      tags: {
        ...tags
        tier: 'web'
      }
      ingress: {
        kind: 'publicIp'
        sku: 'Standard'
        dnsLabel: '${projectName}-${environment}'
      }
      diagnostics: diagnosticsConfig
      autoScale: isProduction(environment)
        ? {
            minCapacity: 2
            maxCapacity: 10
            defaultCapacity: 2
            scaleOutCpuThreshold: 75
            scaleInCpuThreshold: 25
          }
        : null
      enableDeleteLock: isProduction(environment)
    }
  }
}

// ============================================================================
// OUTPUTS - Using lambda functions for aggregation
// ============================================================================

@description('Application URLs')
output applicationUrls object = {
  webApp: 'https://${webapp.outputs.defaultHostname}'
  functions: 'https://${functions.outputs.hostname}'
}

@description('Resource IDs for all deployed components')
output resourceIds object = {
  vnet: vnet.outputs.vnetId
  storage: storage.outputs.storageId
  functions: functions.outputs.functionAppId
  webapp: webapp.outputs.appId
  appInsights: appInsights.id
}

@description('Managed identities for RBAC assignments')
output managedIdentities object = {
  functionsAppPrincipalId: functions.outputs.principalId
  webAppPrincipalId: webapp.outputs.appPrincipalId
}

@description('Monitoring endpoints')
output monitoring object = {
  appInsightsInstrumentationKey: functions.outputs.appInsightsKey
  appInsightsConnectionString: functions.outputs.appInsightsConnectionString
}

@description('Storage endpoints')
output storageEndpoints object = {
  blob: storage.outputs.blobEndpoint
  table: storage.outputs.tableEndpoint
  queue: storage.outputs.queueEndpoint
}

@description('Network information')
output networkInfo object = {
  vnetId: vnet.outputs.vnetId
  vnetName: vnet.outputs.vnetName
  subnetIds: vnet.outputs.subnetIds
  totalIpAddresses: totalIpAddresses
  subnetsCount: length(enrichedSubnets)
}

@description('Deployment summary with computed metrics')
output deploymentSummary object = {
  environment: environment
  location: location
  projectName: projectName
  isProduction: isProduction(environment)
  architecture: 'serverless-multitier'
  tierCount: 3
  resourceCount: reduce([1, 1, 1, 1, 1, 3], 0, (acc, val) => acc + val) // vnet, storage, functions, webapp, appInsights, 3 NSGs
  monitoring: diagnosticsConfig != null
  vnetIntegration: true
  highAvailability: isProduction(environment)
}

// Lambda function example: Group all resource IDs by type
var allResourceIds = [
  {type: 'networking', id: vnet.outputs.vnetId}
  {type: 'storage', id: storage.outputs.storageId}
  {type: 'compute', id: functions.outputs.functionAppId}
  {type: 'compute', id: webapp.outputs.appId}
  {type: 'monitoring', id: appInsights.id}
]

@description('Resources grouped by type')
output resourcesByType object = groupBy(allResourceIds, r => r.type)

@description('Resource count by type')
output resourceCountByType object = toObject(
  items(groupBy(allResourceIds, r => r.type)),
  item => item.key,
  item => length(item.value)
)
