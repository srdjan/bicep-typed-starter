import {
  Env,
  Region,
  TagPolicy
} from '../types/common.bicep'
import {buildTags, generateResourceName, getRetentionDaysForEnv} from '../lib/helpers.bicep'

@description('Deployment environment identifier')
param env Env = 'dev'

@description('Primary Azure region for deployment')
param location Region = 'eastus'

@description('Project name used in resource naming')
@minLength(3)
@maxLength(20)
param projectName string

@description('Base tagging policy for all resources')
param tags TagPolicy

@description('Existing storage account name used by the Function App')
@minLength(3)
@maxLength(24)
param functionStorageAccountName string

@secure()
@description('Administrator password for the PostgreSQL flexible server')
param postgresAdminPassword string

var sharedTags = buildTags(env, tags.owner, projectName, tags.costCenter, null)
var vnetName = generateResourceName('vnet', projectName, env, location)
var appGatewayPublicIpName = generateResourceName('pip', projectName, env, location)
var appGatewayName = generateResourceName('agw', projectName, env, location)
var frontDoorName = '${projectName}-${env}-afd'
var functionAppName = generateResourceName('func', projectName, env, location)
var apimName = generateResourceName('apim', projectName, env, location)
var eventHubNamespaceName = generateResourceName('eh', projectName, env, location)
var postgresName = generateResourceName('pgflex', projectName, env, location)

// Virtual network with subnets for App Gateway, Function integration, and Postgres
module network '../modules/network/vnet.bicep' = {
  name: 'vnet'
  params: {
    input: {
      name: vnetName
      location: location
      addressSpaces: ['10.10.0.0/16']
      subnets: [
        {
          name: 'agw'
          prefix: '10.10.1.0/24'
          nsgId: null
          delegations: ['Microsoft.Network/applicationGateways']
        }
        {
          name: 'functions'
          prefix: '10.10.2.0/24'
          nsgId: null
          delegations: []
        }
        {
          name: 'postgres'
          prefix: '10.10.3.0/24'
          nsgId: null
          delegations: ['Microsoft.DBforPostgreSQL/flexibleServers']
        }
      ]
    }
  }
}

resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: appGatewayPublicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: substring(replace(toLower('${projectName}-${env}-agw'), '_', '-'), 0, 60)
    }
  }
  tags: sharedTags
}

module functionApp '../modules/serverless/functionapp.bicep' = {
  name: 'function-app'
  params: {
    func: {
      name: functionAppName
      location: location
      runtime: 'dotnet'
      runtimeVersion: '8'
      hosting: {
        tier: 'premium'
        sku: 'EP1'
        workerCount: 3
      }
      storageAccountName: functionStorageAccountName
      appInsightsName: generateResourceName('appi', projectName, env, location)
      alwaysOn: true
      vnetIntegration: {
        vnetId: network.outputs.vnetId
        subnetName: 'functions'
      }
      diagnostics: {
        workspaceId: ''
        retentionDays: getRetentionDaysForEnv(env)
      }
      tags: {
        ...sharedTags
        component: 'function'
      }
    }
  }
}

module apim '../modules/api/apim.bicep' = {
  name: 'apim'
  params: {
    apim: {
      name: apimName
      location: location
      publisherEmail: 'platform-team@${projectName}.contoso'
      publisherName: 'Platform Team'
      sku: {
        name: env == 'prod' ? 'Premium' : 'Developer'
        capacity: env == 'prod' ? 2 : 1
      }
      virtualNetworkType: 'None'
      subnetResourceId: null
      enableClientCertificate: false
      tags: {
        ...sharedTags
        component: 'apim'
      }
    }
  }
}

var apimHost = uriComponents(apim.outputs.gatewayUrl).host

module eventHub '../modules/messaging/eventhub.bicep' = {
  name: 'eventhub'
  params: {
    namespaceConfig: {
      name: eventHubNamespaceName
      location: location
      sku: env == 'prod' ? 'Standard' : 'Basic'
      capacity: env == 'prod' ? 2 : 1
      autoInflateEnabled: env == 'prod'
      maximumThroughputUnits: env == 'prod' ? 20 : 0
      tags: {
        ...sharedTags
        component: 'eventhub'
      }
      hubs: [
        {
          name: '${projectName}-events'
          partitionCount: env == 'prod' ? 4 : 2
          messageRetentionInDays: 3
          status: 'Active'
          consumerGroups: ['$Default', 'processor', 'analytics']
        }
      ]
    }
  }
}

module postgres '../modules/data/postgres-flexible.bicep' = {
  name: 'postgres'
  params: {
    config: {
      name: postgresName
      location: location
      administratorLogin: 'pgadmin'
      version: '16'
      sku: {
        tier: env == 'prod' ? 'GeneralPurpose' : 'Burstable'
        name: env == 'prod' ? 'Standard_D2ads_v5' : 'Standard_B1ms'
        capacity: env == 'prod' ? 2 : 1
      }
      storageSizeGb: env == 'prod' ? 256 : 128
      storageAutoGrow: 'Enabled'
      backup: {
        retentionDays: env == 'prod' ? 14 : 7
        geoRedundantBackup: env == 'prod' ? 'Enabled' : 'Disabled'
      }
      highAvailability: env == 'prod' ? {
        mode: 'ZoneRedundant'
        standbyAvailabilityZone: null
      } : null
      network: {
        delegatedSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'postgres')
        privateDnsZoneId: null
      }
      databases: [
        {
          name: '${projectName}_app'
          charset: 'UTF8'
          collation: 'en_US.UTF-8'
        }
      ]
      tags: {
        ...sharedTags
        component: 'postgres'
      }
    }
    administratorPassword: postgresAdminPassword
  }
}

var appGatewayConfig = {
  name: appGatewayName
  location: location
  sku: 'WAF_v2'
  capacity: env == 'prod' ? 3 : 2
  vnetId: network.outputs.vnetId
  subnetName: 'agw'
  frontendIpConfiguration: {
    name: 'public-frontend'
    publicIpResourceId: appGatewayPublicIp.id
  }
  probes: [
    {
      name: 'apim-health'
      host: apimHost
      path: '/status-0123456789abcdef'
      protocol: 'Https'
      intervalInSeconds: 30
      timeoutInSeconds: 10
    }
  ]
  backendPools: [
    {
      name: 'apim-backend'
      targets: [
        {
          kind: 'fqdn'
          fqdn: apimHost
        }
      ]
    }
  ]
  httpSettings: [
    {
      name: 'https-settings'
      protocol: 'Https'
      port: 443
      cookieBasedAffinity: 'Disabled'
      pickHostNameFromBackendAddress: true
    }
  ]
  listeners: [
    {
      name: 'http-listener'
      protocol: 'Http'
      hostName: null
      port: 80
      frontendIpConfigurationName: 'public-frontend'
      certificateId: null
    }
  ]
  routingRules: [
    {
      name: 'default-route'
      listenerName: 'http-listener'
      backendPoolName: 'apim-backend'
      httpSettingName: 'https-settings'
      priority: 1
    }
  ]
  firewallMode: env == 'prod' ? 'Prevention' : 'Detection'
  tags: {
    ...sharedTags
    component: 'app-gateway'
  }
}

module appGateway '../modules/network/appgateway.bicep' = {
  name: 'app-gateway'
  dependsOn: [appGatewayPublicIp]
  params: {
    gateway: appGatewayConfig
  }
}

var appGatewayHost = reference(appGatewayPublicIp.id, '2023-04-01').dnsSettings.fqdn

module frontDoor '../modules/edge/frontdoor.bicep' = {
  name: 'frontdoor'
  params: {
    frontDoor: {
      name: frontDoorName
      sku: env == 'prod' ? 'Premium_AzureFrontDoor' : 'Standard_AzureFrontDoor'
      endpointName: '${frontDoorName}-ep'
      tags: {
        ...sharedTags
        component: 'frontdoor'
      }
      originGroups: [
        {
          name: 'app-gateway-origins'
          loadBalancingSampleSize: 4
          healthProbePath: '/'
          probeRequestType: 'GET'
          origins: [
            {
              name: 'app-gateway-origin'
              hostName: appGatewayHost
              httpsPort: 443
              httpPort: 80
              priority: 1
              weight: 1000
            }
          ]
        }
      ]
      routes: [
        {
          name: 'root'
          originGroupName: 'app-gateway-origins'
          patternsToMatch: ['/*']
          supportedProtocols: ['Https']
          httpsRedirect: true
          forwardingProtocol: 'HttpsOnly'
          wafPolicyId: null
        }
      ]
    }
  }
}

@description('Endpoints across the application hosting stack')
output endpoints object = {
  frontDoor: frontDoor.outputs.endpointHostname
  appGateway: appGatewayHost
  apiManagement: apim.outputs.gatewayUrl
  functionApp: 'https://${functionApp.outputs.hostname}'
  eventHubNamespace: eventHub.outputs.namespaceId
  postgresFqdn: postgres.outputs.fqdn
}

@description('Shared resource identifiers')
output resourceIds object = {
  vnet: network.outputs.vnetId
  appGateway: appGateway.outputs.gatewayId
  frontDoor: frontDoor.outputs.profileId
  apim: apim.outputs.apimId
  functionApp: functionApp.outputs.functionAppId
  eventHubNamespace: eventHub.outputs.namespaceId
  postgres: postgres.outputs.serverId
}
