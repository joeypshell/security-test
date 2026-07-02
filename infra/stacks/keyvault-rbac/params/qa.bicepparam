using '../main.bicep'

param location = 'centralus'
param workloadName = 'sectest'
param environmentName = 'qa'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
}
param roleAssignments = []
