import {AppGatewayConfig, AppGatewayBackendTarget} from '../../types/common.bicep'

@description('Azure Application Gateway configuration')
param gateway AppGatewayConfig

var subnetId = '${gateway.vnetId}/subnets/${gateway.subnetName}'

var frontendPortMap = toObject(
  gateway.listeners,
  listener => string(listener.port),
  listener => {
    name: 'port-${listener.port}'
    properties: {
      port: listener.port
    }
  }
)

var frontendPorts = values(frontendPortMap)

var backendPools = [
  for pool in gateway.backendPools: {
    name: pool.name
    properties: {
      backendAddresses: [
        for target in pool.targets: target.kind == 'ip'
          ? {
              ipAddress: target.ipAddress
            }
          : {
              fqdn: target.fqdn
            }
      ]
    }
  }
]

var httpSettings = [
  for setting in gateway.httpSettings: {
    name: setting.name
    properties: {
      protocol: setting.protocol
      port: setting.port
      cookieBasedAffinity: setting.cookieBasedAffinity
      pickHostNameFromBackendAddress: setting.pickHostNameFromBackendAddress ?? false
      requestTimeout: 30
    }
  }
]

var probes = [
  for probe in gateway.probes ?? []: {
    name: probe.name
    properties: {
      protocol: probe.protocol
      path: probe.path
      host: probe.host
      interval: probe.intervalInSeconds ?? 30
      timeout: probe.timeoutInSeconds ?? 30
      unhealthyThreshold: 3
      pickHostNameFromBackendHttpSettings: false
      minServers: 0
      match: {
        statusCodes: ['200-399']
      }
    }
  }
]

var httpListeners = [
  for listener in gateway.listeners: {
    name: listener.name
    properties: {
      frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', gateway.name, gateway.frontendIpConfiguration.name)
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', gateway.name, frontendPortMap[string(listener.port)].name)
      }
      protocol: listener.protocol
      hostName: listener.hostName
      requireServerNameIndication: listener.protocol == 'Https'
      sslCertificate: listener.certificateId == null ? null : {
        id: listener.certificateId!
      }
    }
  }
]

var routingRules = [
  for rule in gateway.routingRules: {
    name: rule.name
    properties: {
      priority: rule.priority
      ruleType: 'Basic'
      httpListener: {
        id: resourceId('Microsoft.Network/applicationGateways/httpListeners', gateway.name, rule.listenerName)
      }
      backendAddressPool: {
        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gateway.name, rule.backendPoolName)
      }
      backendHttpSettings: {
        id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', gateway.name, rule.httpSettingName)
      }
    }
  }
]

resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: gateway.name
  location: gateway.location
  tags: gateway.tags ?? {}
  sku: {
    name: gateway.sku
    tier: gateway.sku
    capacity: gateway.capacity ?? 2
  }
  properties: {
    gatewayIPConfigurations: [
      {
        name: 'gw-ipcfg'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      gateway.frontendIpConfiguration.publicIpResourceId != null
        ? {
            name: gateway.frontendIpConfiguration.name
            properties: {
              publicIPAddress: {
                id: gateway.frontendIpConfiguration.publicIpResourceId!
              }
            }
          }
        : {
            name: gateway.frontendIpConfiguration.name
            properties: {
              subnet: {
                id: subnetId
              }
            }
          }
    ]
    frontendPorts: frontendPorts
    backendAddressPools: backendPools
    backendHttpSettingsCollection: httpSettings
    httpListeners: httpListeners
    requestRoutingRules: routingRules
    probes: probes
    webApplicationFirewallConfiguration: gateway.firewallMode == null
      ? null
      : {
          enabled: true
          firewallMode: gateway.firewallMode
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
  }
}

@description('Application Gateway resource ID')
output gatewayId string = appGateway.id

@description('Frontend public IP resource ID if configured')
output frontendPublicIpId string = gateway.frontendIpConfiguration.publicIpResourceId ?? ''

@description('Backend pool resource IDs keyed by pool name')
output backendPoolIds object = {
  for pool in gateway.backendPools: pool.name: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gateway.name, pool.name)
}
