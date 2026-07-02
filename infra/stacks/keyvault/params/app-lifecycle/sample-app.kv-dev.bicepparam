using '../../main.bicep'

param location = 'centralus'
param workloadName = 'sampleapp'
param environmentName = 'kv-dev'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
  deploymentClass: 'app-lifecycle'
}
param roleAssignments = []
