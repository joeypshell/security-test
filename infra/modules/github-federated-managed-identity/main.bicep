targetScope = 'resourceGroup'

// This module owns one deployment identity and one exact GitHub Environment
// trust relationship. Call it once per blast radius instead of sharing identity.
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

// The federated credential stores no GitHub secret. It tells Entra which issuer,
// audience, repository, and environment claims may act as this managed identity.
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

// Deployment operators use these outputs to grant Graph app roles and configure
// each matching GitHub Environment after the one-time bootstrap deployment.
output clientId string = managedIdentity.properties.clientId
output principalId string = managedIdentity.properties.principalId
output tenantId string = managedIdentity.properties.tenantId
output managedIdentityName string = managedIdentity.name
output federatedSubject string = githubFederatedCredential.properties.subject
