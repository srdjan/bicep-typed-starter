using 'main.bicep'
param env='dev'
param project='typedapp'
param tags={env:'dev' owner:'team-infra' costCenter:'RND-001'}
param app={name:'typedapp-dev' tier:'basic' location:'eastus' ingress:{kind:'publicIp' sku:'Standard' dnsLabel:'typedapp-dev'} diagnostics:{workspaceId:null retentionDays:30}}
param vnet={name:'vnet-typedapp-dev' addressSpaces:['10.10.0.0/16'] subnets:[{name:'app' prefix:'10.10.1.0/24'},{name:'data' prefix:'10.10.2.0/24'}]}