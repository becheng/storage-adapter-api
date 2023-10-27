extern alias StorageAdapterClientModels;

using Azure;
using Azure.Identity;
using Azure.Data.Tables;
using StorageAdapterClientModels::StorageAdapter.Models;

var builder = WebApplication.CreateBuilder(args);

// add the storage TableServiceClient
builder.Services.AddSingleton<TableClient>(
    new TableClient(
        new Uri( builder.Configuration["STORAGE_TABLE_URI"] ),
        builder.Configuration["STORAGE_TABLE_NAME"],
        new DefaultAzureCredential())
);

var app = builder.Build();

// disable for local 
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
        AsyncPageable<TenantToStorageMapping> queryResults = tableClient.QueryAsync<TenantToStorageMapping>(ent => ent.CxTenantId == Guid.Parse(tenantId));
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

    // // table rbac test
    app.MapGet("/storageTest", async (TableClient tableClient) => {
        AsyncPageable<TableEntity> queryResults = tableClient.QueryAsync<TableEntity>(filter: $"PartitionKey eq 'storageAdapterTenants'");
        return "Table query results: " + (await queryResults.ToListAsync()).Count;
    });

    // table query test
    app.MapGet("/storageTest/{tenantId}", async (TableClient tableClient, string tenantId) => 
    {
        AsyncPageable<TenantToStorageMapping> queryResults = 
            tableClient.QueryAsync<TenantToStorageMapping>(ent => ent.CxTenantId == Guid.Parse(tenantId));
        TenantToStorageMapping tenantToStorageMapping = (await queryResults.ToListAsync()).ElementAt(0);
        
        return "Cx Name: " + tenantToStorageMapping.CxTenantName + " CxTenantId: " + tenantToStorageMapping.CxTenantId;
    });
}

app.Run();