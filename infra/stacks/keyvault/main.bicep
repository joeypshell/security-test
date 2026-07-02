targetScope = 'subscription'

@description('Azure region for resources.')
param location string

@description('Short workload name used in resource names.')
param workloadName string

@description('Deployment target label, such as kv-dev, kv-qa, keys-prod, or keys-shared.')
param environmentName string

@description('Resource tags.')
param tags object = {}

@description('Subscription-scope role assignments approved for this target.')
param roleAssignments array = []

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${workloadName}-${environmentName}'
  location: location
  tags: union(tags, {
    environment: environmentName
    workload: workloadName
  })
}

module keyVault '../../modules/keyvault/main.bicep' = {
  name: 'keyvault-${environmentName}'
  scope: resourceGroup
  params: {
    name: '${workloadName}-${environmentName}-kv'
    location: location
    tags: union(tags, {
      environment: environmentName
      workload: workloadName
    })
  }
}

module subscriptionRoleAssignments '../../modules/role-assignment/main.bicep' = {
  name: 'subscription-role-assignments-${environmentName}'
  params: {
    assignments: roleAssignments
  }
}

output resourceGroupName string = resourceGroup.name
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultId string = keyVault.outputs.keyVaultId
