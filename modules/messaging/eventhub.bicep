import {EventHubNamespaceConfig} from '../../types/common.bicep'

@description('Event Hubs namespace configuration')
param namespaceConfig EventHubNamespaceConfig

var authorizationRuleId = resourceId('Microsoft.EventHub/namespaces/AuthorizationRules', namespaceConfig.name, 'RootManageSharedAccessKey')

resource namespaceResource 'Microsoft.EventHub/namespaces@2022-10-01' = {
  name: namespaceConfig.name
  location: namespaceConfig.location
  sku: {
    name: namespaceConfig.sku
    tier: namespaceConfig.sku
    capacity: namespaceConfig.capacity ?? 1
  }
  tags: namespaceConfig.tags ?? {}
  properties: {
    isAutoInflateEnabled: namespaceConfig.autoInflateEnabled ?? false
    maximumThroughputUnits: namespaceConfig.maximumThroughputUnits ?? 0
    zoneRedundant: false
  }
}

resource eventHubs 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01' = [
  for (hub, hubIndex) in namespaceConfig.hubs: {
    parent: namespaceResource
    name: hub.name
    properties: {
      partitionCount: hub.partitionCount
      messageRetentionInDays: hub.messageRetentionInDays
      status: hub.status
    }
  }
]

resource consumerGroups 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01' = [
  for (hub, hubIndex) in namespaceConfig.hubs: [
    for consumerGroupName in hub.consumerGroups: {
      parent: eventHubs[hubIndex]
      name: consumerGroupName
      properties: {}
    }
  ]
]

var rootKeys = listKeys(authorizationRuleId, '2017-04-01')

@description('Event Hubs namespace resource ID')
output namespaceId string = namespaceResource.id

@description('Primary Event Hubs connection string (RootManageSharedAccessKey)')
output primaryConnectionString string = rootKeys.primaryConnectionString

@description('Event Hub resource IDs keyed by hub name')
output hubIds object = {
  for hub in namespaceConfig.hubs: hub.name: resourceId('Microsoft.EventHub/namespaces/eventhubs', namespaceConfig.name, hub.name)
}
