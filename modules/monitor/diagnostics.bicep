type Diagnostics = {
  workspaceId: string?
  retentionDays: int?
}

param targetId string
param diag Diagnostics

resource diagSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diag.workspaceId != null) {
  name: 'diag-${uniqueString(targetId)}'
  properties: {
    workspaceId: diag.workspaceId!
    logs: []
    metrics: []
  }
}

output created bool = diag.workspaceId != null
