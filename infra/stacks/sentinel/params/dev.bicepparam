using '../main.bicep'

param location = 'centralus'
param workloadName = 'sentinel'
param environmentName = 'dev'
param tags = {
  owner: 'security'
  dataClassification: 'internal'
}
