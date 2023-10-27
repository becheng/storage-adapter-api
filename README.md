# Storage Adapter API Sample
A dotnet minimal api sample used to retrieve a tenant/customer storage identifier mappings.  

When used with its client (see [Storage Adapter Client](https://github.com/becheng/storage-adapter-client), the **Storage Adapter** provides an abstraction layer to access multiple Azure Storage accounts and third party storage providers.  In the sample, we demostrate access to an AWS S3 Bucket.

The sample demostrates the following :

1. Connection to an Azure storage account within your  Azure tenant using a storage access key and OAuth separately. 
2. Cross tenant access to an Azure storage account residing in a different Azure tenant using OAuth.
3. Connection to AWS S3 Bucket using an bucket access key.
4. Generation of signed Urls (a SAS Uri in Azure, a Presigned Url in AWS) to upload and download an image from their respective storage types.

## Prerequistes
1. An Azure subscription in a Azure org/tenant.
2. A second Azure subscription with a storage account provisioned in a second Azure org/tenant.
3. An AWS account with a S3 bucket and the appropriate IAM user/account access with an accessKey and accessKeySecret.
4. A multi-tenant Service Principal from the first Azure tenant with consent to the second Azure tenant already provided.  
    - Assign the SP the "Storage Blob Contributor" role to the target storage account in the first tenant.
    - Assign the SP the "Storage Blob Contributor" role to the target storage account in the second tenant.

## Getting Started

### Deploying Locally

1. Create an Entra ID app registration with a secret.  This service principal will be used to execute the `seedTenantToStorageTable.sh` script in order to seed the mapping table.  Record the client id, client secret and the associated Enterprise App object id.  

2. Add the following environment variables to your `.env` file for a given azd environment within the `.azure` folder.
    - $DEPLOY_SP_OBJID="[object id recorded above]"
    - $DEPLOY_SP_CLIENT_ID="[clientId recorded above]"
    - $DEPLOY_SP_CLIENT_SECRET="[client secret recorded above]"
    - $MULTITENANT_SP_CLIENT_ID="[multi-tenant SP clientId]"
    - $MULTITENANT_SP_CLIENT_SECRET="[multi-tenant SP client secret]"
    - $STORAGE_ACCOUNT_ACCESS_KEY="[storage access key to the Azure storage account in the first tenant]"
    - $AWSS3_ACCESS_KEY="[access key secret to the AWS S3 Bucket]"

3. Run `azd up` from the api project folder within bash terminal.

### Deploying uisng GitHub Actions

1. Run `azd pipeline` to setup your GitHub Action pipeline.

2. Use the service principal that was auto-generated and add a new client secret.  Record the client id, client secret and the associated Enterprise App object id.  

3. Add the following as *Secrets* within the repo's **Settings** > **Secrets and variables**:
    - $DEPLOY_SP_OBJID="[object id recorded above]"
    - $DEPLOY_SP_CLIENT_SECRET="[client secret recorded above]"
    - $MULTITENANT_SP_CLIENT_SECRET="[multi-tenant SP client secret]"
    - $STORAGE_ACCOUNT_ACCESS_KEY="[storage access key to the Azure storage account in the first tenant]"
    - $AWSS3_ACCESS_KEY="[access key secret to the AWS S3 Bucket]"

4. Add the following as *Variables* within the repo's **Settings** > **Secrets and variables** (in addition to the variable `azd` already added):
    - $DEPLOY_SP_CLIENT_ID="[clientId recorded above]"
    - $MULTITENANT_SP_CLIENT_ID="[multi-tenant SP clientId]"

5. Execute the Github Action manually or via a regular PR.

## Testing the Storage Adapter
The [Storage Adapter Client](https://github.com/becheng/storage-adapter-client) comes with a XUnit project and tests.
1. Clone the client repo.
2. Configure the test data in the project's `appsettings.Test.json` witin the test folder.
3. Configure the `appsettings.Development.json` to point to the deployed Storage Adapter API endpoint and key vault.  Note: if running locally, make sure the local Service Principal used has the RBAC (Azure Storage Blob Data Contributor, Azure Table Data Reader) to both the storage account that contains the blob containers and Azure Table that contains the customer mappings.     
4. Use VSCode with the C# Dev Kit extension to execute Tests withn the Test Explorer. 