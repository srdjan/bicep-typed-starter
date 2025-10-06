import {Diagnostics} from '../../types/common.bicep'

@description('Resource ID of the target resource to attach diagnostics to')
param targetId string

@description('Diagnostic settings configuration')
param diag Diagnostics

// Reference the existing target resource to scope diagnostics correctly
resource targetResource 'Microsoft.Web/sites@2023-12-01' existing = {
  name: last(split(targetId, '/'))
}

resource diagSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diag.workspaceId != null) {
  scope: targetResource
  name: 'diagnostics'
  properties: {
    workspaceId: diag.workspaceId!
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'AppServiceIPSecAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
    ]
  }
}

output created bool = diag.workspaceId != null
