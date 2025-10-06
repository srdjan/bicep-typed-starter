import {PostgresConfig} from '../../types/common.bicep'

@description('PostgreSQL flexible server configuration')
param config PostgresConfig

@secure()
@description('Administrator password for the PostgreSQL flexible server')
param administratorPassword string

var highAvailability = config.highAvailability == null
  ? {
      mode: 'Disabled'
    }
  : {
      mode: config.highAvailability.mode
      standbyAvailabilityZone: config.highAvailability.standbyAvailabilityZone
    }

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: config.name
  location: config.location
  sku: {
    name: config.sku.name
    tier: config.sku.tier
    capacity: config.sku.capacity
  }
  tags: config.tags ?? {}
  properties: {
    administratorLogin: config.administratorLogin
    administratorLoginPassword: administratorPassword
    version: config.version
    storage: {
      storageSizeGB: config.storageSizeGb
      autoGrow: config.storageAutoGrow
    }
    backup: {
      backupRetentionDays: config.backup.retentionDays
      geoRedundantBackup: config.backup.geoRedundantBackup
    }
    highAvailability: highAvailability
    network: config.network == null
      ? null
      : {
          delegatedSubnetResourceId: config.network.delegatedSubnetId
          privateDnsZoneArmResourceId: config.network.privateDnsZoneId
        }
    publicNetworkAccess: config.network == null ? 'Enabled' : 'Disabled'
    createMode: 'Default'
  }
}

resource databases 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = [
  for db in config.databases: {
    parent: server
    name: db.name
    properties: {
      charset: db.charset ?? 'UTF8'
      collation: db.collation ?? 'en_US.UTF-8'
    }
  }
]

@description('PostgreSQL flexible server resource ID')
output serverId string = server.id

@description('PostgreSQL fully qualified domain name')
output fqdn string = server.properties.fullyQualifiedDomainName

@description('Administrative connection string template')
output adminConnectionString string = 'host=${server.properties.fullyQualifiedDomainName};username=${config.administratorLogin}@${server.name};sslmode=Require'
