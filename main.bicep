type Env='dev'|'test'|'prod'
 type Region='eastus'|'westeurope'|'westus'
 type AppTier='basic'|'standard'|'premium'
 type TagPolicy={env:'dev'|'test'|'prod' owner:string costCenter?:string}
 type PublicIpIngress={kind:'publicIp' sku:'Basic'|'Standard' dnsLabel?:string}
 type PrivateLinkIngress={kind:'privateLink' vnetId:string subnetName:string}
 type AppGwIngress={kind:'appGateway' appGatewayId:string listenerName:string}
 type Ingress=PublicIpIngress|PrivateLinkIngress|AppGwIngress
 type Diagnostics={workspaceId?:string retentionDays?:int}
 type AppConfig={name:string location:Region tier:AppTier ingress:Ingress diagnostics?:Diagnostics}
 type VnetInput={name:string addressSpaces:string[] subnets:{name:string prefix:string nsgId?:string}[]}
 param env Env
 param project string
 param tags TagPolicy
 param app AppConfig
 param vnet VnetInput
 var commonTags = union(tags, {'project': project})
 module net './modules/network/vnet.bicep' = {name:'net' params:{input:vnet}}
 module web './modules/app/appservice.bicep' = {name:'web' params:{app: union(app,{tags: commonTags})}}
 output appId string = web.outputs.appId
 output planId string = web.outputs.planId
 output subnetIds array = net.outputs.subnetIds