type Env = 'dev' | 'test' | 'prod'
type Region = 'eastus' | 'westeurope' | 'westus'
type AppTier = 'basic' | 'standard' | 'premium'

type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  @minLength(3)
  @maxLength(100)
  owner: string
  @minLength(3)
  @maxLength(50)
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
  ingress: Ingress
  diagnostics: Diagnostics?
  autoScale: AutoScaleSettings?
  enableDeleteLock: bool?
}

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
// Build base tags from required parameters
var baseTags = {
  env: env
  owner: tags.owner
  project: project
}

// Merge optional costCenter tag if provided
var commonTags = tags.costCenter != null ? union(baseTags, { costCenter: tags.costCenter! }) : baseTags

module net './modules/network/vnet.bicep' = { name: 'net', params: { input: vnet } }
module web './modules/app/appservice.bicep' = { name: 'web', params: { app: union(app, { tags: commonTags }) } }
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
