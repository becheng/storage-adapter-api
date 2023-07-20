param keyVaultName string
param principalId string
// default to the 'Key Vault Secrets User' role
param kvRoleDefinitionId string = '4633458b-17de-408a-b874-0445c86b69e6'

// param permissions object = { secrets: [ 'get', 'list' ] }
// resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
//   parent: keyVault
//   name: name
//   properties: {
//     accessPolicies: [ {
//         objectId: principalId
//         tenantId: subscription().tenantId
//         permissions: permissions
//       } ]
//   }
// }

resource kvRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, principalId, kvRoleDefinitionId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', kvRoleDefinitionId)
  }
  scope: keyVault
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}
