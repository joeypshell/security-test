using '../../main.bicep'

param location = 'centralus'
param workloadName = 'sampleapp'
param environmentName = 'keys-prod'
param tags = {
  owner: 'security'
  dataClassification: 'confidential'
  deploymentClass: 'app-lifecycle'
  boundary: 'keys'
}
param roleAssignments = []
