targetScope = 'resourceGroup'

@description('Name of the user-assigned managed identity.')
param name string

@description('Azure region for the managed identity.')
param location string = resourceGroup().location

@description('GitHub organization or account that owns the repository.')
param githubOwner string

@description('GitHub repository name without the owner.')
param githubRepository string

@description('GitHub Environment trusted by this managed identity.')
param githubEnvironment string

@description('Resource tags.')
param tags object = {}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

resource githubFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: managedIdentity
  name: 'github-${githubEnvironment}'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubOwner}/${githubRepository}:environment:${githubEnvironment}'
  }
}

output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
output tenantId string = managedIdentity.properties.tenantId
output managedIdentityName string = managedIdentity.name
output federatedSubject string = githubFederatedCredential.properties.subject
