using 'main.bicep'
param env = 'prod'
param project = 'typedapp'
param tags = { env: 'prod', owner: 'team-security', costCenter: 'SEC-002' }
param app = {
  name: 'typedapp-private'
  tier: 'premium'
  location: 'eastus'
  capacity: 2
  ingress: {
    kind: 'privateLink'
    vnetId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/networking/providers/Microsoft.Network/virtualNetworks/vnet-hub'
    subnetName: 'private-endpoints'
  }
  diagnostics: { workspaceId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/monitoring/providers/Microsoft.OperationalInsights/workspaces/prod-logs', retentionDays: 90 }
  enableDeleteLock: true
}
param vnet = { name: 'vnet-typedapp-private', location: 'eastus', addressSpaces: ['10.30.0.0/16'], subnets: [{ name: 'app', prefix: '10.30.1.0/24' }, { name: 'data', prefix: '10.30.2.0/24' }, { name: 'private-endpoints', prefix: '10.30.3.0/24' }] }
