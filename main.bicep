type Env = 'dev' | 'test' | 'prod'
type Region = 'eastus' | 'westeurope' | 'westus'
type AppTier = 'basic' | 'standard' | 'premium'
type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  owner: string
  costCenter: string?
}
@discriminator('kind')
type Ingress =
  | { kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string? }
  | { kind: 'privateLink', vnetId: string, subnetName: string }
  | { kind: 'appGateway', appGatewayId: string, listenerName: string }
type Diagnostics = { workspaceId: string?, retentionDays: int? }
type AppConfig = { name: string, location: Region, tier: AppTier, ingress: Ingress, diagnostics: Diagnostics? }
type VnetInput = { name: string, addressSpaces: string[], subnets: { name: string, prefix: string, nsgId: string? }[] }
param env Env
param project string
param tags TagPolicy
param app AppConfig
param vnet VnetInput
var baseTags = {
  env: env
  owner: tags.owner
  project: project
}
var commonTags = tags.costCenter != null ? union(baseTags, { costCenter: tags.costCenter! }) : baseTags
module net './modules/network/vnet.bicep' = { name: 'net', params: { input: vnet } }
module web './modules/app/appservice.bicep' = { name: 'web', params: { app: union(app, { tags: commonTags }) } }
output appId string = web.outputs.appId
output planId string = web.outputs.planId
output subnetIds array = net.outputs.subnetIds
