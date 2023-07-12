extern alias StorageAdapterClientModels;

using Azure;
using Azure.Identity;
using Azure.Data.Tables;
using StorageAdapterClientModels::StorageAdapter.Models;

var builder = WebApplication.CreateBuilder(args);

// add the storage TableServiceClient
builder.Services.AddSingleton<TableClient>(
    new TableClient(
        new Uri( builder.Configuration["StorageTableUri"] ),
        builder.Configuration["StorageTableName"],
        new DefaultAzureCredential())
);

// add the key vault 
// builder.Configuration.AddAzureKeyVault(
//     new Uri($"https://{builder.Configuration["KeyVaultName"]}.vault.azure.net/"),
//     new DefaultAzureCredential()
// );

var app = builder.Build();

// disable for now for local development
if (builder.Environment.IsProduction()){
    app.UseHttpsRedirection();
}

// root
app.MapGet("/", () => "Welcome to the Storage Adapter!");

// storageMapping route
app.MapGet("/storageMapping/{tenantId}", async (TableClient tableClient, string tenantId) => 
{
    try 
    {
        AsyncPageable<TenantToStorageMapping> queryResults = tableClient.QueryAsync<TenantToStorageMapping>(ent => ent.CxTenantId == tenantId);
        List<TenantToStorageMapping> aList = await queryResults.ToListAsync();
        IResult aResult = Results.NotFound();
        if (aList.Count == 0) 
        {
            // do nothing
        } 
        else if (aList.Count > 1) 
        {
            aResult = Results.BadRequest("More than one storage mapping found for tenant id (Check mapping table!): " + tenantId);
        } 
        else 
        {
            TenantToStorageMapping tenantToStorageMapping = aList.ElementAt(0);
            aResult = Results.Ok(tenantToStorageMapping);
        }
        return aResult;
    } 
    catch (RequestFailedException ex) 
    {
        return Results.Problem($"Unexpected Error {ex.Message}");
    }

}).WithName("GetStorageMappingByTenantId");

// dev only endpoints
if (builder.Environment.IsDevelopment()) {
    // // usage: 'dotnet user-secrets set "secretKeyTest" "secretValueTest_dev"'
    // app.MapGet("/kvTest", (IConfiguration config) => "Not so secret pulled from key vault: " + config["secretKeyTest"]);

    // // table rbac test
    app.MapGet("/storageTest", async (TableClient tableClient) => {
        AsyncPageable<TableEntity> queryResults = tableClient.QueryAsync<TableEntity>(filter: $"PartitionKey eq 'storageadapter'");
        return "Table query results: " + (await queryResults.ToListAsync()).Count;
    });

    // table query test
    app.MapGet("/storageTest/{tenantId}", async (TableClient tableClient, string tenantId) => 
    {
        AsyncPageable<TenantToStorageMapping> queryResults = 
            tableClient.QueryAsync<TenantToStorageMapping>(ent => ent.CxTenantId == tenantId);
        TenantToStorageMapping tenantToStorageMapping = (await queryResults.ToListAsync()).ElementAt(0);
        return "Cx Name: " + tenantToStorageMapping.CxTenantName + " CxTenantId: " + tenantToStorageMapping.CxTenantId;
    });
}

app.Run();