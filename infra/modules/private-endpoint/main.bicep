targetScope = 'resourceGroup'

@description('Private endpoint name.')
param name string

@description('Azure region for the private endpoint.')
param location string = resourceGroup().location

@description('Resource ID of the target private link service.')
param privateLinkResourceId string

@description('Private link group IDs, such as vault for Key Vault.')
param groupIds array

@description('Subnet resource ID for the private endpoint.')
param subnetId string

@description('Resource tags.')
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: privateLinkResourceId
          groupIds: groupIds
        }
      }
    ]
  }
}

output privateEndpointId string = privateEndpoint.id
