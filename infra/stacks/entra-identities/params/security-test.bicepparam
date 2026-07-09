using '../main.bicep'

param location = 'centralus'
param githubOwner = 'joeypshell'
param githubRepository = 'security-test'
param tags = {
  owner: 'security'
  purpose: 'github-entra-oidc'
}
