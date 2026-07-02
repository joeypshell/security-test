targetScope = 'subscription'

@description('Role assignments to apply at subscription scope.')
param assignments array = []

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for assignment in assignments: {
  name: guid(subscription().id, assignment.principalId, assignment.roleDefinitionGuid)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleDefinitionGuid)
    principalId: assignment.principalId
    principalType: assignment.principalType
  }
}]

output roleAssignmentIds array = [for (assignment, index) in assignments: roleAssignments[index].id]
