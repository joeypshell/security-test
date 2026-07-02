targetScope = 'resourceGroup'

@description('Azure region for resources.')
param location string = resourceGroup().location

@description('Short workload name used in resource names.')
param workloadName string

@description('Deployment target name, such as dev or prod.')
param environmentName string

@description('Resource tags.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${workloadName}-${environmentName}'
  location: location
  tags: union(tags, {
    environment: environmentName
    workload: workloadName
  })
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
  }
}

resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2023-02-01' = {
  name: 'default'
  scope: workspace
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
