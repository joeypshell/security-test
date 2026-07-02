using '../../main.bicep'

param location = 'centralus'
param workloadName = 'sampleapp'
param environmentName = 'kv-qa'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
  deploymentClass: 'app-lifecycle'
}
param roleAssignments = []
