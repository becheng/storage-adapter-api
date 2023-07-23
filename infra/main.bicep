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
param storageTableName string = ''

// TODO: erroring on first time provisioning, error: PublicAccessNotPermitted: Public access is not permitted on this storage account.
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
  // dependsOn: [ app ]
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${substring('${abbrs.storageStorageAccounts}${normalizedEnvironmentName}', 0, 24)}'
    location: rg.location
    tags: tags
    publicNetworkAccess: 'Enabled'
    sku: {
      name: 'Standard_LRS'
    }
    // principalId: app.outputs.managedSystemIdentity
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
  // dependsOn: [ app ]
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${substring('${abbrs.keyVaultVaults}${normalizedEnvironmentName}', 0, 24)}'
    location: rg.location
    tags: tags
    // principalId: app.outputs.managedSystemIdentity
  }
}

// populate key vault with secrets
module keyVaultSecrets 'core/security/keyvault-secrets.bicep' = {
  scope: rg
  name: 'keyvault-secrets'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    secrets: [
      {
        name: 'secret-from-keyvault-direct'
        value: 'hello from keyvault'
      }
      {
        name: 'AwsS3--accessKey'
        value: 'awsAccessKey'
      }
      {
        name: 'AwsS3--accessSecret'
        value: 'asecret'
      }
    ]
  }
}

// set a single secret in key vault so we get its uri as an output
module linkedKVSecret 'core/security/keyvault-secret.bicep' = {
  scope: rg
  name: 'linked-kv-secret'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    name: 'secret-stored-in-kv-and-linked'
    secretValue: 'hello from kevault thru container app'
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
  dependsOn: [ containerApps, linkedKVSecret ]
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
        name: 'KEYVAULT_NAME'
        value: keyVault.outputs.name
      }
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Development'
      }
      {
        name: 'secret-from-containerapp'
        secretRef: 'secret-from-containerapp'
      }
      {
        name: 'secret-from-kv-linked-containerapp'
        secretRef: 'secret-from-kv-linked-containerapp'
      }
    ]
    secrets: [
      {
        name: 'secret-from-containerapp'
        value: 'hello from container app'
      }
      {
        name: 'secret-from-kv-linked-containerapp'
        keyVaultUrl: linkedKVSecret.outputs.secretUri
        identity: 'System'
      }
    ]
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

// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_AUTH_MODE string = 'key'

output AZURE_STORAGE_TABLE_URI_TMP string = storage.outputs.tableUri
output AZURE_KEYVAULT_NAME_TMP string = keyVault.outputs.name
output AZURE_SECRETURI_TMP string = linkedKVSecret.outputs.secretUri

