targetScope = 'resourceGroup'

@description('Globally unique Key Vault name.')
param name string

@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Tenant ID that owns the Key Vault.')
param tenantId string = subscription().tenantId

@description('Resource tags.')
param tags object = {}

@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@allowed([
  true
])
@description('Purge protection must stay enabled.')
param enablePurgeProtection bool = true

@allowed([
  'Disabled'
])
@description('Public network access must stay disabled unless a documented exception is added.')
param publicNetworkAccess string = 'Disabled'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: true
    enablePurgeProtection: enablePurgeProtection
    enableSoftDelete: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
