using '../main.bicep'

param location = 'centralus'
param workloadName = 'sectest'
param environmentName = 'prod'
param tags = {
  owner: 'security'
  dataClassification: 'confidential'
}
param roleAssignments = []
