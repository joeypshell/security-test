using '../main.bicep'

// This file binds the reusable identity stack to the security-test repository.
// Identity names retain stack defaults; only location, repository, and tags vary.
param location = 'centralus'
param githubOwner = 'joeypshell'
param githubRepository = 'security-test'
param tags = {
  owner: 'security'
  purpose: 'github-entra-oidc'
}
