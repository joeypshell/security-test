using '../main.bicep'

param location = 'centralus'
param workloadName = 'sectest'
param environmentName = 'dev'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
}
param roleAssignments = []
