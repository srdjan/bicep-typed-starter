// ============================================================================
// AZURE FUNCTIONS MODULE - Serverless compute with type-safe configuration
// ============================================================================

import {Region, Diagnostics} from '../../types/common.bicep'

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

@description('Functions hosting plan tier')
type FunctionHostingTier = 'consumption' | 'elastic' | 'premium'

@description('Function runtime stack')
type RuntimeStack = 'dotnet' | 'node' | 'python' | 'java' | 'powershell'

@description('Runtime version mapping')
type RuntimeVersion = {
  dotnet: '6' | '8'
  node: '16' | '18' | '20'
  python: '3.9' | '3.10' | '3.11'
  java: '11' | '17'
  powershell: '7.2' | '7.4'
}

@discriminator('tier')
@description('Function hosting plan configuration')
type HostingPlan =
  | {tier: 'consumption'}
  | {tier: 'elastic', maximumElasticWorkerCount: int}
  | {tier: 'premium', sku: 'EP1' | 'EP2' | 'EP3', workerCount: int?}

@description('Function App configuration')
type FunctionAppConfig = {
  @minLength(2)
  @maxLength(60)
  name: string
  location: Region
  runtime: RuntimeStack
  runtimeVersion: string
  hosting: HostingPlan
  storageAccountName: string
  appInsightsName: string?
  alwaysOn: bool?
  vnetIntegration: {vnetId: string, subnetName: string}?
  diagnostics: Diagnostics?
  tags: object
}

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Function App configuration')
param func FunctionAppConfig

// ============================================================================
// RESOURCES
// ============================================================================

// App Service Plan for Functions
resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${func.name}-plan'
  location: func.location
  tags: func.tags
  sku: func.hosting.tier == 'consumption'
    ? {name: 'Y1', tier: 'Dynamic'}
    : func.hosting.tier == 'elastic'
      ? {name: 'EP1', tier: 'ElasticPremium'}
      : {name: func.hosting.sku, tier: 'ElasticPremium'}
  properties: {
    reserved: contains(['python', 'node', 'dotnet'], func.runtime)
    maximumElasticWorkerCount: func.hosting.tier == 'elastic' ? func.hosting.maximumElasticWorkerCount : null
  }
  kind: 'functionapp'
}

// Application Insights (optional)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (func.appInsightsName != null) {
  name: func.appInsightsName!
  location: func.location
  tags: func.tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: func.name
  location: func.location
  tags: func.tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    virtualNetworkSubnetId: func.vnetIntegration != null
      ? '${func.vnetIntegration.vnetId}/subnets/${func.vnetIntegration.subnetName}'
      : null
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      alwaysOn: func.hosting.tier != 'consumption' ? (func.alwaysOn ?? true) : false
      vnetRouteAllEnabled: func.vnetIntegration != null
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${func.storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', func.storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${func.storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', func.storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(func.name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: func.runtime
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        ...((func.appInsightsName != null)
          ? [
              {
                name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
                value: appInsights.properties.InstrumentationKey
              }
              {
                name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
                value: appInsights.properties.ConnectionString
              }
            ]
          : [])
      ]
    }
  }
}

// Diagnostic settings
module diagnostics '../monitor/diagnostics.bicep' = if (func.diagnostics != null) {
  name: 'diag-${uniqueString(functionApp.id)}'
  params: {
    targetId: functionApp.id
    diag: func.diagnostics!
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Function App resource ID')
output functionAppId string = functionApp.id

@description('Function App name')
output functionAppName string = functionApp.name

@description('Function App hostname')
output hostname string = functionApp.properties.defaultHostName

@description('Function App managed identity principal ID')
output principalId string = functionApp.identity.principalId

@description('Hosting plan ID')
output hostingPlanId string = hostingPlan.id

@description('Application Insights instrumentation key')
output appInsightsKey string = func.appInsightsName != null ? appInsights.properties.InstrumentationKey : ''

@description('Application Insights connection string')
output appInsightsConnectionString string = func.appInsightsName != null ? appInsights.properties.ConnectionString : ''
