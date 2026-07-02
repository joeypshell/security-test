using '../../main.bicep'

param location = 'centralus'
param workloadName = 'deptshared'
param environmentName = 'keys-shared'
param tags = {
  owner: 'security'
  dataClassification: 'restricted'
  boundary: 'keys'
  deploymentClass: 'keys-only'
}
param roleAssignments = []
