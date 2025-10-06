// Diagnostic settings for Storage Account
import {Diagnostics} from '../../types/common.bicep'

@description('Storage Account resource ID')
param storageAccountId string

@description('Diagnostic settings configuration')
param diag Diagnostics

// Reference the existing storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageAccountId, '/'))
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diag.workspaceId != null) {
  scope: storageAccount::blobServices::default
  name: 'blob-diagnostics'
  properties: {
    workspaceId: diag.workspaceId!
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: diag.retentionDays != null
          days: diag.retentionDays ?? 0
        }
      }
    ]
    metrics: [
      {
        category: 'Transaction'
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
