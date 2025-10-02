type Region = 'eastus' | 'westeurope' | 'westus'
type AppTier = 'basic' | 'standard' | 'premium'

type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  owner: string
  project: string
  costCenter: string?
}

@discriminator('kind')
type Ingress =
  | { kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string? }
  | { kind: 'privateLink', vnetId: string, subnetName: string }
  | { kind: 'appGateway', appGatewayId: string, listenerName: string }

type Diagnostics = {
  workspaceId: string?
  @minValue(1)
  @maxValue(365)
  retentionDays: int?
}

type AutoScaleSettings = {
  @minValue(1)
  @maxValue(30)
  minCapacity: int
  @minValue(1)
  @maxValue(30)
  maxCapacity: int
  @minValue(1)
  @maxValue(30)
  defaultCapacity: int
  @minValue(1)
  @maxValue(100)
  scaleOutCpuThreshold: int?
  @minValue(1)
  @maxValue(100)
  scaleInCpuThreshold: int?
}

type AppConfig = {
  @minLength(3)
  @maxLength(60)
  name: string
  location: Region
  tier: AppTier
  @minValue(1)
  @maxValue(30)
  capacity: int?
  tags: TagPolicy
  ingress: Ingress
  diagnostics: Diagnostics?
  autoScale: AutoScaleSettings?
  enableDeleteLock: bool?
}

@description('Application Service configuration including name, location, tier, and ingress settings')
param app AppConfig

// Map abstract tier names to actual Azure SKU names and tiers
var skuMap = {
  basic: {
    name: 'B1'
    tier: 'Basic'
  }
  standard: {
    name: 'S1'
    tier: 'Standard'
  }
  premium: {
    name: 'P1v3'
    tier: 'PremiumV3'
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${app.name}-plan'
  location: app.location
  sku: {
    name: skuMap[app.tier].name
    capacity: app.capacity ?? 1
    tier: skuMap[app.tier].tier
  }
  tags: app.tags
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: app.name
  location: app.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    // Public network access controlled by ingress type
    publicNetworkAccess: app.ingress.kind == 'publicIp' ? 'Enabled' : 'Disabled'
    // VNet integration for private link
    virtualNetworkSubnetId: app.ingress.kind == 'privateLink' ? '${app.ingress.vnetId}/subnets/${app.ingress.subnetName}' : null
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: app.tier != 'basic'
      // VNet route all traffic when using private link
      vnetRouteAllEnabled: app.ingress.kind == 'privateLink'
      appSettings: [
        {
          name: 'INGRESS_KIND'
          value: app.ingress.kind
        }
        {
          name: 'PUBLIC_DNS'
          value: app.ingress.kind == 'publicIp' ? (app.ingress.dnsLabel ?? 'web') : 'n/a'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: app.ingress.kind == 'privateLink' ? '1' : '0'
        }
      ]
    }
  }
  tags: app.tags
}

// Private endpoint for private link ingress
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (app.ingress.kind == 'privateLink') {
  name: '${app.name}-pe'
  location: app.location
  properties: {
    subnet: {
      id: app.ingress.kind == 'privateLink' ? '${app.ingress.vnetId}/subnets/${app.ingress.subnetName}' : ''
    }
    privateLinkServiceConnections: [
      {
        name: '${app.name}-plsc'
        properties: {
          privateLinkServiceId: site.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
  tags: app.tags
}

// Auto-scaling rules for App Service Plan
resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (app.autoScale != null) {
  name: '${app.name}-autoscale'
  location: app.location
  tags: app.tags
  properties: {
    enabled: true
    targetResourceUri: plan.id
    profiles: [
      {
        name: 'Auto scale based on CPU percentage'
        capacity: {
          minimum: string(app.autoScale!.minCapacity)
          maximum: string(app.autoScale!.maxCapacity)
          default: string(app.autoScale!.defaultCapacity)
        }
        rules: [
          // Scale out rule
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: app.autoScale!.scaleOutCpuThreshold ?? 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          // Scale in rule
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: app.autoScale!.scaleInCpuThreshold ?? 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

module diag '../monitor/diagnostics.bicep' = if (app.diagnostics != null) {
  name: 'diag-${uniqueString(site.id)}'
  params: {
    targetId: site.id
    diag: app.diagnostics!
  }
}

// Resource locks to prevent accidental deletion
resource planLock 'Microsoft.Authorization/locks@2020-05-01' = if (app.enableDeleteLock ?? false) {
  scope: plan
  name: 'delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of App Service Plan'
  }
}

resource siteLock 'Microsoft.Authorization/locks@2020-05-01' = if (app.enableDeleteLock ?? false) {
  scope: site
  name: 'delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of App Service'
  }
}

@description('Resource ID of the App Service')
output appId string = site.id

@description('Resource ID of the App Service Plan')
output planId string = plan.id

@description('Principal ID of the system-assigned managed identity')
output principalId string = site.identity.principalId

@description('Default hostname of the App Service')
output defaultHostname string = site.properties.defaultHostName

@description('Resource ID of the private endpoint (if using privateLink ingress)')
output privateEndpointId string = app.ingress.kind == 'privateLink' ? privateEndpoint.id : ''

@description('Private IP address of the private endpoint (if using privateLink ingress)')
output privateIpAddress string = app.ingress.kind == 'privateLink' ? privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''
