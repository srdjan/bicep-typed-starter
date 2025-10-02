using 'main.bicep'
param env = 'prod'
param project = 'typedapp'
param tags = { env: 'prod', owner: 'team-infra', costCenter: 'RND-001' }
param app = {
  name: 'typedapp-prod'
  tier: 'premium'
  location: 'eastus'
  capacity: 3
  ingress: { kind: 'publicIp', sku: 'Standard', dnsLabel: 'typedapp-prod' }
  diagnostics: { workspaceId: '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/monitoring/providers/Microsoft.OperationalInsights/workspaces/prod-logs', retentionDays: 90 }
  autoScale: {
    minCapacity: 3
    maxCapacity: 10
    defaultCapacity: 3
    scaleOutCpuThreshold: 75
    scaleInCpuThreshold: 25
  }
  enableDeleteLock: true
}
param vnet = { name: 'vnet-typedapp-prod', location: 'eastus', addressSpaces: ['10.20.0.0/16'], subnets: [{ name: 'app', prefix: '10.20.1.0/24' }, { name: 'data', prefix: '10.20.2.0/24' }] }
