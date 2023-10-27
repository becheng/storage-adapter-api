#!/bin/sh

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
az login --service-principal -u $DEPLOY_SP_CLIENT_ID -p $DEPLOY_SP_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# # Add the table entities
echo ""
echo "Adding table entities."
echo ""

# set the AZURE_STORAGE_KEY environment variable programmatically 
# requires the 'Storage Account Key Operator Service Role' rbac role to be set on the service principal
export AZURE_STORAGE_KEY="$(az storage account keys list --account-name $AZURE_STORAGE_ACCOUNT --resource-group "rg-$AZURE_ENV_NAME" --query "[0].value" -o tsv)"

partitionKey1="storageAdapterTenants"

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=1 \
StorageIdentifier="stsboxstorageadapter6kvs" \
StorageAccessKeySecretRef="2b6623da-38e1-445b-80f1-5edd52f3fb7e:storageAccessKey" \
ConnectionType="AzStorageSharedKey" \
ContainerName="tenant1" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="2b6623da-38e1-445b-80f1-5edd52f3fb7e" \
CxTenantName="AdventureWorks" \
IsAzCrossTenant@odata.type="Edm.Boolean" IsAzCrossTenant=false \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=2 \
StorageIdentifier="stsboxstorageadapter6kvs" \
StorageAccessKeySecretRef="not-applicable" \
ConnectionType="AzOauth" \
ContainerName="tenant2" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="27000a0c-8b2f-43dc-b1d2-7235ba13e0ed" \
CxTenantName="Awesome Computers" \
IsAzCrossTenant@odata.type="Edm.Boolean" IsAzCrossTenant=false \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=3 \
StorageIdentifier="sademo2t35" \
StorageAccessKeySecretRef="not-applicable" \
ConnectionType="AzOauth" \
ContainerName="feb27container" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="7f302d31-e058-4160-920b-76857bc2e284" \
CxTenantName="Fabrikam" \
IsAzCrossTenant@odata.type="Edm.Boolean" IsAzCrossTenant=true \
StorageRegion="CanadaCentral" \
StorageType="AzStorage" \
AzCrossTenantDomain="benchenggmail.onmicrosoft.com" \
AzCrossTenantId="9e54649d-2ff3-4f06-9561-d81f12cfcfa6" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME 

az storage entity insert \
--entity PartitionKey=$partitionKey1 RowKey=4 \
StorageIdentifier="AKIAVYRZSLZIHY4J3H5Q" \
StorageAccessKeySecretRef="5e0a2a1f-0376-4453-875c-3d727087d607:storageAccessKey" \
ConnectionType="AwsCredentials" \
ContainerName="storageadapterhack" \
CxTenantId@odata.type="Edm.Guid" CxTenantId="5e0a2a1f-0376-4453-875c-3d727087d607" \
CxTenantName="adatum.com" \
IsAzCrossTenant@odata.type="Edm.Boolean" IsAzCrossTenant=false \
StorageRegion="ca-central-1" \
StorageType="AwsS3" \
AzCrossTenantDomain="" \
AzCrossTenantId="" \
--if-exists replace \
--table-name $AZURE_STORAGE_TABLE_NAME