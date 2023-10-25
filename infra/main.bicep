targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string 

@description('Name of resource group')
param resourceGroupName string = ''

@description('Name of the storage account')
param storageAccountName string = ''

@description('Name of the storage table')
param storageTableName string = 'tenantToStorageMapping'

@description('An array of storage container names')
param storageContainerNames array = [
  {
    name:'tenant1' 
    publicAccess:'Blob'
  }
  {
    name:'tenant2' 
    publicAccess:'Blob'
  }
  {
    name:'tenant3' 
    publicAccess:'Blob'
  }
]

@description('Name of the Azure Key Vault')
param keyVaultName string = ''

@description('Name of the container apps environment')
param containerAppsEnvironmentName string = ''

@description('Name of the Azure container registry')
param containerRegistryName string = ''

@description('Name of the Azure Log Analytics workspace')
param logAnalyticsName string = ''

@description('Name of the Azure Application Insights dashboard')
param applicationInsightsDashboardName string = ''

@description('Name of the Azure Application Insights resource')
param applicationInsightsName string = ''

@description('The name of the image')
param imageName string = ''

@description('Indicates if the container app exists')
param containerAppExists bool = false

@description('Object Id of the Service Principal to run table scripts')
param deployScriptsServicePrincipalObjectId string = ''

@description('Client ID of the multitenant service principal used for cross tenant storage access')
param multitenantSPClientId string = ''

// the following 'secret' params are used only for demo purposes
// for a real deployment, look at using the 'getSecret' function to retrieve the secret from the key vault
// https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/azure-resource-manager/bicep/scenarios-secrets.md#use-a-key-vault-with-modules
@description('Client secret of the multitenant service principal used for cross tenant storage access')
@secure()
param multitenantSPClientSecret string = ''

@description('Storage account access key for tenant1 - an azure storeage acct user')
@secure()
param storageAccountAccessKey string = ''

@description('Storage account access key for tenant2 - an aws s3 user')
@secure()
param awsS3AccessKey string = ''

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var normalizedEnvironmentName = concat(toLower(replace(environmentName, '-', '')), resourceToken)

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// storage account that holds the table and blob containers
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${substring('${abbrs.storageStorageAccounts}${normalizedEnvironmentName}', 0, 24)}'
    location: rg.location
    tags: tags
    publicNetworkAccess: 'Enabled'
    sku: {
      name: 'Standard_LRS'
    }
    containers: storageContainerNames
    tables: [
      {
        name: storageTableName
      }
    ]
  }
}

// key vault to store secrets
module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${substring('${abbrs.keyVaultVaults}${normalizedEnvironmentName}', 0, 24)}'
    location: rg.location
    tags: tags
  }
}

// populate key vault with multiple secrets
module keyVaultSecrets 'core/security/keyvault-secrets.bicep' = {
  scope: rg
  name: 'keyvault-secrets'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    secrets: [
      {
        name: 'multitenantSP--clientId'
        value: multitenantSPClientId
      }
      {
        name: 'multitenantSP--clientSecret'
        value: multitenantSPClientSecret
      }
    ]
  }
}

// set a single secret in key vault so we get its uri as an output
module cust1StorageKVSecret 'core/security/keyvault-secret.bicep' = {
  scope: rg
  name: 'cust1-storage-kvSecret'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    name: '2b6623da-38e1-445b-80f1-5edd52f3fb7e--storageAccessKey'
    secretValue: storageAccountAccessKey
  }
}

module cust2StorageKVSecret 'core/security/keyvault-secret.bicep' = {
  scope: rg
  name: 'cust2-storage-kvSecret'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    name: '5e0a2a1f-0376-4453-875c-3d727087d607--storageAccessKey'
    secretValue: awsS3AccessKey
  }
}

// provisions container app environment and registry
module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: rg
  params: {
    name: 'app'
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${normalizedEnvironmentName}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${normalizedEnvironmentName}'
    containerRegistryResourceGroupName: rg.name
    location: rg.location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
}

// conatiner app - important to call the upsert module since it contains a check if the container app already exists which is needed for to populate the imageName
module app './core/host/container-app-upsert.bicep' = {
  name: 'conatiner-app'
  scope: rg
  dependsOn: [ containerApps, cust1StorageKVSecret, cust2StorageKVSecret ]
  params: {
    name: 'storageadapterapi-container-app'
    location: rg.location
    tags: union(tags, { 'azd-service-name': 'storage-adapter-api' })
    identityName: 'storageAdapterApiUserIdentity'
    imageName: imageName
    exists: containerAppExists
    containerAppsEnvironmentName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${normalizedEnvironmentName}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${normalizedEnvironmentName}'
    env: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: monitoring.outputs.applicationInsightsConnectionString
      }
      {
        name: 'STORAGE_TABLE_URI'
        value: storage.outputs.tableUri
      }
      {
        name: 'STORAGE_TABLE_NAME'
        value: 'tenantToStorageMapping'
      }            
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Development'
      }
      // example of the env variable that references a secret stored in the container app
      // {
      //   name: 'secret-from-containerapp'
      //   secretRef: 'secret-from-containerapp'
      // }
      // {
      //   name: 'secret-from-kv-linked-containerapp'
      //   secretRef: 'secret-from-kv-linked-containerapp'
      // }
    ]
    // secrets: [
      // example of a secret that is stored in the container app
      // {
      //   name: 'secret-from-containerapp'
      //   value: 'hello from container app'
      // }
      // example of a secret that is stored in the key vault and referenced in the container app
    //   {
    //     name: 'secret-from-kv-linked-containerapp'
    //     keyVaultUrl: cust1StorageKVSecret.outputs.secretUri
    //     identity: 'System'
    //   }
    // ]
    targetPort: 80
  }
}

// deploy monitoring resources
module monitoring 'core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: rg.location
    tags: tags
    includeDashboard: false
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${normalizedEnvironmentName}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${normalizedEnvironmentName}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${normalizedEnvironmentName}'
  }
}

// set the rbac to the storage table and containers using the app's MSI
module storageAccess 'core/security/storage-access.bicep' = {
  scope: rg
  name: 'storage-access'
  params: {
    storageAccountName: storage.outputs.name
    principalId: app.outputs.managedSystemIdentity
  }
}

// set the rbac to the key vault using the app's MSI
module kvAccess 'core/security/keyvault-access.bicep' = {
  scope: rg
  name: 'keyvault-access'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: app.outputs.managedSystemIdentity
  }
}

// set the rbac to the storage table and containers using the app's MSI
module storageScriptAccess 'core/security/storage-access.bicep' = {
  scope: rg
  name: 'storage-script-access'
  params: {
    storageAccountName: storage.outputs.name
    principalId: deployScriptsServicePrincipalObjectId  //objectId of the SP used to run table scripts
    tableRoleDefinitionId: '81a9662b-bebf-436f-a333-f67b29880f12' // set to the Storage Account Key Operator Service Role
    mode: 'tableOnly'
  }
}

// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_TABLE_NAME string = storage.outputs.tableName
