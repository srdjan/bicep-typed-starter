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
