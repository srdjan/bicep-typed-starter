import {FrontDoorConfig, HttpProtocol} from '../../types/common.bicep'

@description('Azure Front Door Standard/Premium configuration')
param frontDoor FrontDoorConfig

var routeOriginMap = toObject(frontDoor.routes, route => route.name, route => route.originGroupName)

resource profile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoor.name
  location: 'global'
  sku: {
    name: frontDoor.sku
  }
  tags: frontDoor.tags ?? {}
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: profile
  name: frontDoor.endpointName
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroups 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = [for (group, idx) in frontDoor.originGroups: {
  parent: profile
  name: group.name
  properties: {
    loadBalancingSettings: {
      sampleSize: group.loadBalancingSampleSize ?? 4
      successfulSamplesRequired: ((group.loadBalancingSampleSize ?? 4) > 1)
        ? ((group.loadBalancingSampleSize ?? 4) - 1)
        : 1
      additionalLatencyInMilliseconds: 0
    }
    healthProbeSettings: {
      probeIntervalInSeconds: 120
      probeRequestType: group.probeRequestType ?? 'GET'
      probeProtocol: 'Https'
      probePath: group.healthProbePath ?? '/'
    }
    sessionAffinityState: 'Disabled'
  }
}]

resource origins 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = [for (group, idx) in frontDoor.originGroups: [for origin in group.origins: {
  parent: originGroups[idx]
  name: origin.name
  properties: {
    hostName: origin.hostName
    httpPort: origin.httpPort ?? 80
    httpsPort: origin.httpsPort ?? 443
    priority: origin.priority ?? 1
    weight: origin.weight ?? 1000
    enabledState: 'Enabled'
  }
}]]

resource routes 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = [for route in frontDoor.routes: {
  parent: endpoint
  name: route.name
  properties: {
    supportedProtocols: length(route.supportedProtocols) == 0 ? ['Https'] : route.supportedProtocols
    patternsToMatch: route.patternsToMatch
    httpsRedirect: route.httpsRedirect ?? true
    forwardingProtocol: route.forwardingProtocol
    originGroup: {
      id: '${profile.id}/originGroups/${route.originGroupName}'
    }
    dynamicCompression: 'Enabled'
    cachingEnabled: false
    linkToDefaultDomain: true
    ruleSets: []
    webApplicationFirewallPolicyLink: route.wafPolicyId == null ? null : {
      id: route.wafPolicyId!
    }
  }
}]

@description('Azure Front Door profile resource ID')
output profileId string = profile.id

@description('Azure Front Door endpoint hostname')
output endpointHostname string = endpoint.properties.hostName

@description('Map of route names to origin group resource IDs')
output routeOrigins object = {
  for route in frontDoor.routes: route.name: '${profile.id}/originGroups/${routeOriginMap[route.name]}'
}
