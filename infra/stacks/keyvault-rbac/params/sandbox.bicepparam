using '../main.bicep'

param location = 'centralus'
param workloadName = 'sectest'
param environmentName = 'sandbox'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
}
param roleAssignments = []
