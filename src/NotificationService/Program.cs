using NotificationService.Data;
using NotificationService.Endpoints;
using NotificationService.Services;
using SharedLibrary.Auth;
using SharedLibrary.Cosmos;
using SharedLibrary.Telemetry;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceTelemetry("NotificationService");
builder.Services.AddCosmosDb(builder.Configuration);

var disableAuth = builder.Configuration.GetValue<bool>("Authentication:DisableAuth");
if (!disableAuth)
{
    builder.Services.AddEntraAuth(builder.Configuration);
}

builder.Services.AddHealthChecks();
builder.Services.AddScoped<INotificationService, NotificationServiceImpl>();

var app = builder.Build();

app.UseServiceTelemetry();

if (!disableAuth)
{
    app.UseEntraAuth();
}

app.MapNotificationEndpoints();

app.MapHealthChecks("/health").AllowAnonymous();
app.MapGet("/health/ready", () => Results.Ok(new { status = "ready" })).AllowAnonymous();

var databaseName = builder.Configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";
await app.Services.EnsureCosmosDbCreatedAsync(
    databaseName,
    [("notifications", "/userId")]);

await SeedData.SeedAsync(app.Services);

app.Run();
