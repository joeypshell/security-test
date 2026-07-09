targetScope = 'subscription'

@description('Azure region used for the resource group and managed identities.')
param location string

@description('Resource group that hosts the GitHub deployment identities.')
param resourceGroupName string = 'rg-github-entra-identities'

@description('GitHub organization or account that owns the repository.')
param githubOwner string = 'joeypshell'

@description('GitHub repository name without the owner.')
param githubRepository string = 'security-test'

@description('Managed identity used by the entra-report-only environment.')
param reportOnlyIdentityName string = 'gh-secdept-entra-ca-reportonly'

@description('Managed identity used by the entra-prod environment.')
param productionIdentityName string = 'gh-secdept-entra-ca-prod'

@description('Resource tags.')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, {
    workload: 'github-entra-deployment'
  })
}

module reportOnlyIdentity '../../modules/github-federated-managed-identity/main.bicep' = {
  name: 'entra-report-only-identity'
  scope: resourceGroup
  params: {
    name: reportOnlyIdentityName
    location: location
    githubOwner: githubOwner
    githubRepository: githubRepository
    githubEnvironment: 'entra-report-only'
    tags: union(tags, {
      githubEnvironment: 'entra-report-only'
    })
  }
}

module productionIdentity '../../modules/github-federated-managed-identity/main.bicep' = {
  name: 'entra-production-identity'
  scope: resourceGroup
  params: {
    name: productionIdentityName
    location: location
    githubOwner: githubOwner
    githubRepository: githubRepository
    githubEnvironment: 'entra-prod'
    tags: union(tags, {
      githubEnvironment: 'entra-prod'
    })
  }
}

output reportOnlyIdentity object = {
  name: reportOnlyIdentity.outputs.managedIdentityName
  clientId: reportOnlyIdentity.outputs.clientId
  principalId: reportOnlyIdentity.outputs.principalId
  tenantId: reportOnlyIdentity.outputs.tenantId
  federatedSubject: reportOnlyIdentity.outputs.federatedSubject
}

output productionIdentity object = {
  name: productionIdentity.outputs.managedIdentityName
  clientId: productionIdentity.outputs.clientId
  principalId: productionIdentity.outputs.principalId
  tenantId: productionIdentity.outputs.tenantId
  federatedSubject: productionIdentity.outputs.federatedSubject
}
