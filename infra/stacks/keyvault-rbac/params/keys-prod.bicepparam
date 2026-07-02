using '../main.bicep'

param location = 'centralus'
param workloadName = 'sectestkeys'
param environmentName = 'prod'
param tags = {
  owner: 'security'
  dataClassification: 'restricted'
  boundary: 'keys'
}
param roleAssignments = []
