# Storage Adapter API
A dotnet minimal api used to lookup a customer's aka tenant's storage account and its metadata.   

## Getting Started

### Deploying Locally

1. Create an Entra ID app registration with a secret.  This service principal will be used to execute the `seedTenantToStorageTable.sh` script in order to seed the mapping table.  Record the client id, client secret and the associated Enterprise App object id.  

2. Add the following environment variables to your `.env` file for a given azd environment within the `.azure` folder.
    - $DEPLOY_SP_OBJID="[object id recorded above]"
    - $DEPLOY_SP_CLIENT_ID="[clientId recorded above]"
    - $DEPLOY_SP_CLIENT_SECRET="[client secret recorded above]"


### Deploying uisng GitHub Actions

1. Run `azd pipeline` to setup your GitHub Action pipeline.

2. Use the service principal that was auto-generated and add a new client secret.  Record the client id, client secret and the associated Enterprise App object id.  

3. Add the following as *Secrets* within the repo's Settings > Secrets and variables:
    - $DEPLOY_SP_OBJID="[object id recorded above]"
    - $DEPLOY_SP_CLIENT_SECRET="[client secret recorded above]"

4. Add the following as *Variables* within the repo's Settings > Secrets and variables:
    - $DEPLOY_SP_CLIENT_ID="[clientId recorded above]"


## Additional Notes

1. Github Action Secrets and variables must be configured within an Action's Job as an environment variables in the `azure-dev.yml` file.  Example: 
```
    ...
    env:
        AZURE_ENV_NAME: ${{ vars.AZURE_ENV_NAME }}
        DEPLOY_SP_CLIENT_SECRET: ${{ secrets.DEPLOY_SP_CLIENT_SECRET }}
    ...
```

2. Environment variables that are outputted by main.bicep (see `output` section) will be accessible by the `azd provision` and `azd deploy` jobs.

3. While it was  possible to output the storage access key from the main.bicep so it was available in the .env file, it posed a security risk since bicep outputs may be logged.  To avoid this, a azcli command is used to retrieve the access key from the target storage account. 


