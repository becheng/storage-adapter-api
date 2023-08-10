#!/bin/sh
# Important note: this script uses the az storage table entity insert commands which requires the table authenication method to be set to allowed 'allowSharedKeyAccess'
# This requires the either AccountKey or SASKey to be set in the .env file
# If using the powershell version to create table entities, it may be using oauth instead.

echo ""
echo "Loading azd .env file from current environment"
echo ""

while IFS='=' read -r key value; do
    value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

echo "Environment variables set."
echo ""

echo "Logging with SP."
echo ""

# Login to Azure using a service principal uisng azcli
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# # Add the table entities
echo ""
echo "Adding table entities."
echo ""
# echo "Note: if this is the first time running azd deploy, you will need to manually set the AZURE_STORAGE_KEY environment variable with storage account key in the .env file"
# echo "While it is technically possible to set this value using the bicep outputs but exposing sensitive info such as an account key is considered a security risk and likewise it would be flagged by the bicep linter for the same."
# echo ""
# echo "Note2: if erroring out, check the table authentication method is set to 'access key' in the portal"
# echo ""

# set the AZURE_STORAGE_KEY environment variable programmatically 
# requires the 'Storage Account Key Operator Service Role' rbac role
export AZURE_STORAGE_KEY="$(az storage account keys list --account-name $AZURE_STORAGE_ACCOUNT --resource-group "rg-$AZURE_ENV_NAME" --query "[0].value" -o tsv)"
# echo "storage account key = $AZURE_STORAGE_KEY" 

partitionKey1="storageAdapterTenants"


az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=2 \
StorageIdentifier="storageadapterhack" \
StorageAccessKeySecretRef="https://storageadapterhack.blob.core.windows.net/cont4tenant2?sp=rawdl&st=2023-07-12T14:47:49Z&se=2023-09-09T22:47:49Z&spr=https&sv=2022-11-02&sr=c&sig=jwHiHeRdjm4aOkpt2YzbZ8dUbvePXI3uIFoVcy2iC9s%3D" \
ConnectionType="AzSasUri" \
ContainerName="cont4tenant2" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="95877230-9d77-4854-b8d0-b6c580ae8070" \
CxTenantName="Woodgrove" \
IsAzureCrossTenant@odata.type="Edm.Boolean" IsAzureCrossTenant=false \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=3 \
StorageIdentifier="storageadapterhack" \
StorageAccessKeySecretRef="not-applicable" \
ConnectionType="AzOauth" \
ContainerName="cont4tenant3" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="27000a0c-8b2f-43dc-b1d2-7235ba13e0ed" \
CxTenantName="Awesome Computers" \
IsAzureCrossTenant@odata.type="Edm.Boolean" IsAzureCrossTenant=false \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=4 \
StorageIdentifier="sademo2t35" \
StorageAccessKeySecretRef="not-applicable" \
ConnectionType="AzOauth" \
ContainerName="feb27container" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="7f302d31-e058-4160-920b-76857bc2e284" \
CxTenantName="Fabrikam" \
IsAzureCrossTenant@odata.type="Edm.Boolean" IsAzureCrossTenant=true \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
AzureCrossTenantDomain="benchenggmail.onmicrosoft.com" \
AzureCrossTenantId="9e54649d-2ff3-4f06-9561-d81f12cfcfa6" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=5 \
StorageIdentifier="AKIAVYRZSLZIHY4J3H5Q" \
StorageAccessKeySecretRef="1W5QJoxFOiA8mJyfojbRAnR2gZ6DYvilWV7BVqRk" \
ConnectionType="AwsCredentials" \
ContainerName="storageadapterhack" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="5e0a2a1f-0376-4453-875c-3d727087d607" \
CxTenantName="adatum.com" \
IsAzureCrossTenant@odata.type="Edm.Boolean" IsAzureCrossTenant=false \
StorageRegion="ca-central-1" \
StorageType="AwsS3" \
AzureCrossTenantDomain="" \
AzureCrossTenantId="" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=6 \
StorageIdentifier="storageadapterhack" \
StorageAccessKeySecretRef="4KO2FU7fBX7yYyRA4+FaMzvbJi/IDt1zw3XGqKKr8bfIxDGOOe1fP+JRae3guMF5+CA4hPYw/Sn4+AStL00c/A==" \
ConnectionType="AzStorageSharedKey" \
ContainerName="cont4tenant1" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="2b6623da-38e1-445b-80f1-5edd52f3fb7e" \
CxTenantName="AdventureWorks" \
IsAzureCrossTenant@odata.type="Edm.Boolean" IsAzureCrossTenant=false \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 
