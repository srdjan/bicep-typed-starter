// Example: Complete deployment with all features enabled
param location string = 'eastus'
param environment string = 'prod'
param projectName string = 'myapp'

// Deploy NSG for app subnet
module appNsg '../modules/network/nsg.bicep' = {
  name: 'app-nsg'
  params: {
    input: {
      name: 'nsg-${projectName}-app-${environment}'
      location: location
      rules: [
        {
          name: 'AllowHttpsInbound'
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
        {
          name: 'AllowHttpInbound'
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      ]
      tags: {
        environment: environment
        project: projectName
      }
    }
  }
}

// Deploy VNet with NSG attached
module vnet '../modules/network/vnet.bicep' = {
  name: 'vnet'
  params: {
    input: {
      name: 'vnet-${projectName}-${environment}'
      location: location
      addressSpaces: ['10.0.0.0/16']
      subnets: [
        {
          name: 'app'
          prefix: '10.0.1.0/24'
          nsgId: appNsg.outputs.nsgId
        }
        {
          name: 'data'
          prefix: '10.0.2.0/24'
          nsgId: null
        }
      ]
    }
  }
}

// Deploy App Service with all features
module app '../modules/app/appservice.bicep' = {
  name: 'app'
  params: {
    app: {
      name: '${projectName}-${environment}'
      location: location
      tier: 'premium'
      capacity: 3
      tags: {
        env: environment
        owner: 'platform-team'
        project: projectName
        costCenter: 'ENG-001'
      }
      ingress: {
        kind: 'publicIp'
        sku: 'Standard'
        dnsLabel: '${projectName}-${environment}'
      }
      diagnostics: {
        workspaceId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/monitoring/providers/Microsoft.OperationalInsights/workspaces/${environment}-logs'
        retentionDays: 90
      }
      autoScale: {
        minCapacity: 3
        maxCapacity: 10
        defaultCapacity: 3
        scaleOutCpuThreshold: 75
        scaleInCpuThreshold: 25
      }
      enableDeleteLock: true
    }
  }
}

// Outputs
output appId string = app.outputs.appId
output appPrincipalId string = app.outputs.principalId
output appHostname string = app.outputs.defaultHostname
output vnetId string = vnet.outputs.vnetId
output subnetIds array = vnet.outputs.subnetIds
