using CatalogService.Data;
using CatalogService.Endpoints;
using CatalogService.Services;
using SharedLibrary.Auth;
using SharedLibrary.Cosmos;
using SharedLibrary.Telemetry;

var builder = WebApplication.CreateBuilder(args);

// Observability
builder.AddServiceTelemetry("CatalogService");

// Cosmos DB
builder.Services.AddCosmosDb(builder.Configuration);

// Authentication
var disableAuth = builder.Configuration.GetValue<bool>("Authentication:DisableAuth");
if (disableAuth)
{
    builder.Services.AddAuthentication().AddJwtBearer();
    builder.Services.AddAuthorization();
}
else
{
    builder.Services.AddEntraAuth(builder.Configuration);
}

// Health checks
builder.Services.AddHealthChecks();

// DI registrations
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddScoped<IProductSearchService, ProductSearchService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IInventoryService, InventoryService>();

var app = builder.Build();

// Middleware
app.UseServiceTelemetry();

if (!disableAuth)
{
    app.UseEntraAuth();
}

// Map endpoints
app.MapProductEndpoints();
app.MapCategoryEndpoints();
app.MapInventoryEndpoints();

// Health check endpoints
app.MapHealthChecks("/health").AllowAnonymous();
app.MapGet("/health/ready", () => Results.Ok(new { status = "ready" })).AllowAnonymous();

// Database initialization and seeding
var databaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";
await app.Services.EnsureCosmosDbCreatedAsync(databaseName,
[
    ("products", "/categoryId"),
    ("categories", "/id"),
    ("inventory", "/productId")
]);

await SeedData.SeedAsync(app.Services);

app.Run();
