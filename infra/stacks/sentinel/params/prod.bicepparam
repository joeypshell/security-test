using '../main.bicep'

param location = 'centralus'
param workloadName = 'sentinel'
param environmentName = 'prod'
param tags = {
  owner: 'security'
  dataClassification: 'confidential'
}
