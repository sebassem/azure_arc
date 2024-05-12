targetScope = 'subscription'

param clientVMPrincipalId string

param clientVMId string

// Add role assignment for the VM: Azure Key Vault Secret Officer role
resource vmRoleAssignment_KeyVaultSecretOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(clientVMId, 'Microsoft.Authorization/roleAssignments', 'Owner')
  scope: subscription()
  properties: {
    principalId: clientVMPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  }
}
