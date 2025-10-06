// Shared type definitions with @export decorator for reusability across modules
// Import these types in other files using: import {TypeName} from '../types/common.bicep'

@export()
@description('Environment identifier')
type Env = 'dev' | 'test' | 'prod'

@export()
@description('Azure region for resource deployment')
type Region = 'eastus' | 'westeurope' | 'westus'

@export()
@description('Application tier selection')
type AppTier = 'basic' | 'standard' | 'premium'

@export()
@description('Required tagging policy for all resources')
type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  @minLength(3)
  @maxLength(100)
  owner: string
  @minLength(3)
  @maxLength(50)
  costCenter: string?
}

@export()
@description('Discriminated union for ingress configuration options')
@discriminator('kind')
type Ingress =
  | { kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string? }
  | { kind: 'privateLink', vnetId: string, subnetName: string }
  | { kind: 'appGateway', appGatewayId: string, listenerName: string }

@export()
@description('Diagnostic settings configuration')
type Diagnostics = {
  workspaceId: string?
  @minValue(1)
  @maxValue(365)
  retentionDays: int?
}

@export()
@description('Auto-scaling configuration for App Service Plans')
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

@export()
@description('Application Service configuration')
type AppConfig = {
  @minLength(3)
  @maxLength(60)
  name: string
  location: Region
  tier: AppTier
  @minValue(1)
  @maxValue(30)
  capacity: int?
  ingress: Ingress
  diagnostics: Diagnostics?
  autoScale: AutoScaleSettings?
  enableDeleteLock: bool?
  tags: TagPolicy?
}

@export()
@description('Virtual Network configuration')
type VnetInput = {
  @minLength(3)
  @maxLength(64)
  name: string
  location: Region
  @minLength(1)
  addressSpaces: string[]
  @minLength(1)
  subnets: {
    @minLength(1)
    @maxLength(80)
    name: string
    prefix: string
    nsgId: string?
    delegations: string[]?
  }[]
}

@export()
@description('Network Security Group rule definition')
type NsgRule = {
  @minLength(1)
  @maxLength(80)
  name: string
  @description('Priority between 100-4096')
  @minValue(100)
  @maxValue(4096)
  priority: int
  direction: 'Inbound' | 'Outbound'
  access: 'Allow' | 'Deny'
  protocol: 'Tcp' | 'Udp' | 'Icmp' | '*'
  sourcePortRange: string
  destinationPortRange: string
  sourceAddressPrefix: string
  destinationAddressPrefix: string
}

@export()
@description('Network Security Group input configuration')
type NsgInput = {
  @minLength(1)
  @maxLength(80)
  name: string
  location: string
  rules: NsgRule[]
  tags: object?
}

// ============================================================================
// EDGE & INGRESS SERVICES
// ============================================================================

@export()
@description('Azure Front Door SKU options')
type FrontDoorSku = 'Standard_AzureFrontDoor' | 'Premium_AzureFrontDoor'

@export()
@description('Supported HTTP protocol values')
type HttpProtocol = 'Http' | 'Https'

@export()
@description('Origin definition for Azure Front Door')
type FrontDoorOrigin = {
  @minLength(1)
  @maxLength(50)
  name: string
  hostName: string
  httpPort: int?
  httpsPort: int?
  weight: int?
  priority: int?
}

@export()
@description('Origin group definition for Azure Front Door')
type FrontDoorOriginGroup = {
  @minLength(1)
  @maxLength(50)
  name: string
  loadBalancingSampleSize: int?
  healthProbePath: string?
  probeRequestType: 'GET' | 'HEAD'?
  origins: FrontDoorOrigin[]
}

@export()
@description('Route configuration for Azure Front Door Standard/Premium')
type FrontDoorRoute = {
  @minLength(1)
  @maxLength(50)
  name: string
  originGroupName: string
  patternsToMatch: string[]
  supportedProtocols: HttpProtocol[]
  httpsRedirect: bool?
  forwardingProtocol: 'HttpOnly' | 'HttpsOnly' | 'MatchRequest'
  wafPolicyId: string?
}

@export()
@description('Azure Front Door configuration block')
type FrontDoorConfig = {
  @minLength(3)
  @maxLength(60)
  name: string
  sku: FrontDoorSku
  endpointName: string
  tags: object?
  originGroups: FrontDoorOriginGroup[]
  routes: FrontDoorRoute[]
}

// ============================================================================
// APPLICATION GATEWAY
// ============================================================================

@export()
@description('Application Gateway SKU tiers')
type AppGatewaySku = 'Standard_v2' | 'WAF_v2'

@export()
@description('Backend target definition for Application Gateway')
@discriminator('kind')
type AppGatewayBackendTarget =
  | { kind: 'ip', ipAddress: string }
  | { kind: 'fqdn', fqdn: string }

@export()
@description('HTTP settings configuration for Application Gateway')
type AppGatewayHttpSetting = {
  name: string
  protocol: HttpProtocol
  port: int
  cookieBasedAffinity: 'Enabled' | 'Disabled'
  pickHostNameFromBackendAddress: bool?
}

@export()
@description('Listener configuration for Application Gateway')
type AppGatewayListener = {
  name: string
  protocol: HttpProtocol
  hostName: string?
  port: int
  frontendIpConfigurationName: string
  certificateId: string?
}

@export()
@description('Routing rule configuration for Application Gateway')
type AppGatewayRoutingRule = {
  name: string
  listenerName: string
  backendPoolName: string
  httpSettingName: string
  priority: int
}

@export()
@description('Application Gateway configuration')
type AppGatewayConfig = {
  name: string
  location: Region
  sku: AppGatewaySku
  capacity: int?
  vnetId: string
  subnetName: string
  frontendIpConfiguration: {
    name: string
    publicIpResourceId: string?
  }
  probes: {
    name: string
    host: string?
    path: string
    protocol: HttpProtocol
    intervalInSeconds: int?
    timeoutInSeconds: int?
  }[]?
  backendPools: {
    name: string
    targets: AppGatewayBackendTarget[]
  }[]
  httpSettings: AppGatewayHttpSetting[]
  listeners: AppGatewayListener[]
  routingRules: AppGatewayRoutingRule[]
  firewallMode: 'Detection' | 'Prevention'?
  tags: object?
}

// ============================================================================
// API MANAGEMENT
// ============================================================================

@export()
@description('API Management SKU definition')
type ApiManagementSku = {
  name: 'Developer' | 'Basic' | 'Standard' | 'Premium'
  capacity: int
}

@export()
@description('API Management configuration block')
type ApiManagementConfig = {
  name: string
  location: Region
  publisherEmail: string
  publisherName: string
  sku: ApiManagementSku
  virtualNetworkType: 'None' | 'External' | 'Internal'
  subnetResourceId: string?
  enableClientCertificate: bool?
  tags: object?
}

// ============================================================================
// DATA LAYER - POSTGRES FLEXIBLE SERVER
// ============================================================================

@export()
@description('PostgreSQL flexible server compute tiers')
type PostgresTier = 'Burstable' | 'GeneralPurpose' | 'MemoryOptimized'

@export()
@description('PostgreSQL flexible server SKU')
type PostgresSku = {
  tier: PostgresTier
  name: 'Standard_B1ms' | 'Standard_B2ms' | 'Standard_D2ads_v5' | 'Standard_E4ads_v5'
  capacity: int
}

@export()
@description('High availability configuration for Postgres flexible server')
type PostgresHighAvailability = {
  mode: 'SameZone' | 'ZoneRedundant'
  standbyAvailabilityZone: string?
}

@export()
@description('Backup configuration for Postgres flexible server')
type PostgresBackup = {
  retentionDays: int
  geoRedundantBackup: 'Disabled' | 'Enabled'
}

@export()
@description('Database definition to be created on the Postgres server')
type PostgresDatabase = {
  name: string
  charset: string?
  collation: string?
}

@export()
@description('Postgres flexible server configuration')
type PostgresConfig = {
  name: string
  location: Region
  administratorLogin: string
  version: '15' | '16'
  sku: PostgresSku
  storageSizeGb: int
  storageAutoGrow: 'Enabled' | 'Disabled'
  backup: PostgresBackup
  highAvailability: PostgresHighAvailability?
  network: {
    delegatedSubnetId: string
    privateDnsZoneId: string?
  }?
  databases: PostgresDatabase[]
  tags: object?
}

// ============================================================================
// MESSAGING - EVENT HUB
// ============================================================================

@export()
@description('Event Hubs SKU tiers')
type EventHubSku = 'Basic' | 'Standard' | 'Premium'

@export()
@description('Event Hub definition including consumer groups')
type EventHubEntity = {
  name: string
  partitionCount: int
  messageRetentionInDays: int
  status: 'Active' | 'Disabled'
  consumerGroups: string[]
}

@export()
@description('Event Hub namespace configuration')
type EventHubNamespaceConfig = {
  name: string
  location: Region
  sku: EventHubSku
  capacity: int?
  autoInflateEnabled: bool?
  maximumThroughputUnits: int?
  tags: object?
  hubs: EventHubEntity[]
}
