targetScope = 'subscription'

@description('Azure region for resources.')
param location string

@description('Short workload name used in resource names.')
param workloadName string

@description('Deployment target name, such as dev or prod.')
param environmentName string

@description('Resource tags.')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${workloadName}-${environmentName}'
  location: location
  tags: union(tags, {
    environment: environmentName
    workload: workloadName
  })
}

module sentinel '../../modules/sentinel/main.bicep' = {
  name: 'sentinel-${environmentName}'
  scope: resourceGroup
  params: {
    location: location
    workloadName: workloadName
    environmentName: environmentName
    tags: tags
  }
}

output workspaceId string = sentinel.outputs.workspaceId
output workspaceName string = sentinel.outputs.workspaceName
