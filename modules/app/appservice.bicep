type Region='eastus'|'westeurope'|'westus'
 type AppTier='basic'|'standard'|'premium'
 type TagPolicy={env:'dev'|'test'|'prod' owner:string costCenter?:string}
 type PublicIpIngress={kind:'publicIp' sku:'Basic'|'Standard' dnsLabel?:string}
 type PrivateLinkIngress={kind:'privateLink' vnetId:string subnetName:string}
 type AppGwIngress={kind:'appGateway' appGatewayId:string listenerName:string}
 type Ingress=PublicIpIngress|PrivateLinkIngress|AppGwIngress
 type Diagnostics={workspaceId?:string retentionDays?:int}
 type AppConfig={name:string location:Region tier:AppTier tags:TagPolicy ingress:Ingress diagnostics?:Diagnostics}
 param app AppConfig
 var planSku= app.tier=='basic'? 'B1':(app.tier=='standard'? 'S1':'P1v3')
 resource plan 'Microsoft.Web/serverfarms@2023-12-01'={name:'${app.name}-plan' location: app.location sku:{name:planSku capacity:1 tier: toUpper(app.tier)} tags: app.tags}
 resource site 'Microsoft.Web/sites@2023-12-01'={name: app.name location: app.location properties:{serverFarmId: plan.id httpsOnly:true siteConfig:{appSettings:[{name:'INGRESS_KIND' value: app.ingress.kind}{name:'PUBLIC_DNS' value: app.ingress.kind=='publicIp'? (app.ingress.dnsLabel ?? 'web') : 'n/a'}]}} tags: app.tags}
 module diag '../monitor/diagnostics.bicep' = if (app.diagnostics!=null){name:'diag-${uniqueString(site.id)}' params:{targetId: site.id diag: app.diagnostics}}
 output appId string = site.id
 output planId string = plan.id