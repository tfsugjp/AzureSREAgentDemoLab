using NotificationService.Endpoints;
using NotificationService.HealthChecks;
using NotificationService.Services;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using SharedLibrary.Auth;
using SharedLibrary.Cosmos;
using SharedLibrary.Telemetry;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceTelemetry("NotificationService");
builder.Services.AddCosmosDb(builder.Configuration);

var disableAuth = builder.Configuration.GetValue<bool>("Authentication:DisableAuth");
if (!disableAuth)
{
    builder.Services.AddEntraAuth(builder.Configuration);
}

builder.Services.AddSingleton<StartupHealthCheck>();
builder.Services
    .AddHealthChecks()
    .AddCheck<CosmosDbHealthCheck>("cosmosdb", tags: ["ready"])
    .AddCheck<StartupHealthCheck>("startup", tags: ["ready"]);

builder.Services.AddHostedService<StartupInitializationService>();
builder.Services.AddScoped<INotificationService, NotificationServiceImpl>();

var app = builder.Build();

app.UseServiceTelemetry();

if (!disableAuth)
{
    app.UseEntraAuth();
}

app.MapNotificationEndpoints();

app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = _ => false,
    ResponseWriter = WriteJsonResponse
}).AllowAnonymous();

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = WriteJsonResponse
}).AllowAnonymous();

app.Run();

static Task WriteJsonResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json";

    var result = new
    {
        status = report.Status.ToString(),
        checks = report.Entries.Select(entry => new
        {
            name = entry.Key,
            status = entry.Value.Status.ToString(),
            description = entry.Value.Description,
            duration = entry.Value.Duration.TotalMilliseconds
        })
    };

    return context.Response.WriteAsync(
        JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
}
