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
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: app.tier != 'basic'
      appSettings: [
        {
          name: 'INGRESS_KIND'
          value: app.ingress.kind
        }
        {
          name: 'PUBLIC_DNS'
          value: app.ingress.kind == 'publicIp' ? (app.ingress.dnsLabel ?? 'web') : 'n/a'
        }
      ]
    }
  }
  tags: app.tags
}

module diag '../monitor/diagnostics.bicep' = if (app.diagnostics != null) {
  name: 'diag-${uniqueString(site.id)}'
  params: {
    targetId: site.id
    diag: app.diagnostics!
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
