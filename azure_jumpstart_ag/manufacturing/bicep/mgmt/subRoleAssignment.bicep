targetScope = 'subscription'

param clientVMPrincipalId string

// Add role assignment for the VM: Azure Key Vault Secret Officer role
resource vmRoleAssignment_pwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, clientVMPrincipalId,'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: subscription()
  properties: {
    principalId: clientVMPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
    principalType: 'ServicePrincipal'
  }
}
