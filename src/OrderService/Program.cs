using OrderService.Data;
using OrderService.Endpoints;
using OrderService.Services;
using SharedLibrary.Auth;
using SharedLibrary.Cosmos;
using SharedLibrary.Telemetry;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceTelemetry("OrderService");
builder.Services.AddCosmosDb(builder.Configuration);

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

builder.Services.AddHealthChecks();
builder.Services.AddScoped<IOrderService, OrderServiceImpl>();

var app = builder.Build();

app.UseServiceTelemetry();

if (!disableAuth)
{
    app.UseEntraAuth();
}

app.MapOrderEndpoints();
app.MapHealthChecks("/health").AllowAnonymous();
app.MapGet("/health/ready", () => Results.Ok(new { status = "ready" })).AllowAnonymous();

var databaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";
await app.Services.EnsureCosmosDbCreatedAsync(databaseName, [("orders", "/userId")]);
await SeedData.SeedAsync(app.Services);

app.Run();
