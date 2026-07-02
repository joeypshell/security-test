targetScope = 'resourceGroup'

@description('Diagnostic setting name.')
param name string = 'send-to-log-analytics'

@description('Key Vault name to attach diagnostic settings to.')
param keyVaultName string

@description('Log Analytics workspace resource ID.')
param workspaceId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: name
  scope: keyVault
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output diagnosticSettingId string = diagnostics.id
