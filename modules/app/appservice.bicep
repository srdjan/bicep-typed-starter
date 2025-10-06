import {TagPolicy, AppConfig} from '../../types/common.bicep'

@description('Application Service configuration including name, location, tier, and ingress settings')
param config AppConfig

@description('Required tags applied to App Service resources')
param tags TagPolicy

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
  name: '${config.name}-plan'
  location: config.location
  sku: {
    name: skuMap[config.tier].name
    capacity: config.capacity ?? 1
    tier: skuMap[config.tier].tier
  }
  tags: tags
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: config.name
  location: config.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: false
    // Public network access controlled by ingress type
    publicNetworkAccess: config.ingress.kind == 'publicIp' ? 'Enabled' : 'Disabled'
    // VNet integration for private link
    virtualNetworkSubnetId: config.ingress.kind == 'privateLink' ? '${config.ingress.vnetId}/subnets/${config.ingress.subnetName}' : null
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: config.tier != 'basic'
      // VNet route all traffic when using private link
      vnetRouteAllEnabled: config.ingress.kind == 'privateLink'
      appSettings: [
        {
          name: 'INGRESS_KIND'
          value: config.ingress.kind
        }
        {
          name: 'PUBLIC_DNS'
          value: config.ingress.kind == 'publicIp' ? (config.ingress.dnsLabel ?? 'web') : 'n/a'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: config.ingress.kind == 'privateLink' ? '1' : '0'
        }
      ]
    }
  }
  tags: tags
}

// Private endpoint for private link ingress
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (config.ingress.kind == 'privateLink') {
  name: '${config.name}-pe'
  location: config.location
  properties: {
    subnet: {
      id: config.ingress.kind == 'privateLink' ? '${config.ingress.vnetId}/subnets/${config.ingress.subnetName}' : ''
    }
    privateLinkServiceConnections: [
      {
        name: '${config.name}-plsc'
        properties: {
          privateLinkServiceId: site.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
  tags: tags
}

// Auto-scaling rules for App Service Plan
resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (config.autoScale != null) {
  name: '${config.name}-autoscale'
  location: config.location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: plan.id
    profiles: [
      {
        name: 'Auto scale based on CPU percentage'
        capacity: {
          minimum: string(config.autoScale!.minCapacity)
          maximum: string(config.autoScale!.maxCapacity)
          default: string(config.autoScale!.defaultCapacity)
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
              threshold: config.autoScale!.scaleOutCpuThreshold ?? 70
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
              threshold: config.autoScale!.scaleInCpuThreshold ?? 30
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

module diag '../monitor/diagnostics.bicep' = if (config.diagnostics != null) {
  name: 'diag-${uniqueString(site.id)}'
  params: {
    targetId: site.id
    diag: config.diagnostics!
  }
}

// Resource locks to prevent accidental deletion
resource planLock 'Microsoft.Authorization/locks@2020-05-01' = if (config.enableDeleteLock ?? false) {
  scope: plan
  name: 'delete-lock'
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevents accidental deletion of App Service Plan'
  }
}

resource siteLock 'Microsoft.Authorization/locks@2020-05-01' = if (config.enableDeleteLock ?? false) {
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
output privateEndpointId string = config.ingress.kind == 'privateLink' ? privateEndpoint.id : ''

@description('Private IP address of the private endpoint (if using privateLink ingress)')
output privateIpAddress string = config.ingress.kind == 'privateLink' ? privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''
