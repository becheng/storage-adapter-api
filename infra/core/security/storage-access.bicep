param storageAccountName string = ''
param principalId string = ''
// default to the storage blob contributor role
param blobRoleDefinitionId string = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
// default to the storage table contributor role
param tableRoleDefinitionId string = '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
// mode
@allowed([
  'both'
  'tableOnly'
  'blobOnly'
])
param mode string = 'both'


resource blobContainerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (mode != 'tableOnly') {
  name: guid(subscription().id, resourceGroup().id, principalId, blobRoleDefinitionId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', blobRoleDefinitionId)
  }
  scope: storage
}

resource tableRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (mode != 'blobOnly') {
  name: guid(subscription().id, resourceGroup().id, principalId, tableRoleDefinitionId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', tableRoleDefinitionId)
  }
  scope: storage
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}
