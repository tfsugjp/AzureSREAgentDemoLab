using CatalogService.HealthChecks;
using CatalogService.Services;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// ── Cosmos DB client ──────────────────────────────────────────────────────────
var cosmosConnectionString = builder.Configuration["CosmosDb:ConnectionString"]
    ?? throw new InvalidOperationException(
        "CosmosDb:ConnectionString is required. Set it via appsettings.json or an environment variable.");

builder.Services.AddSingleton(_ => new CosmosClient(cosmosConnectionString,
    new CosmosClientOptions { ApplicationName = "CatalogService" }));

// ── Health checks ─────────────────────────────────────────────────────────────
// StartupHealthCheck must be singleton so its IsReady flag is shared.
builder.Services.AddSingleton<StartupHealthCheck>();

builder.Services
    .AddHealthChecks()
    .AddCheck<CosmosDbHealthCheck>("cosmosdb", tags: ["ready"])
    .AddCheck<StartupHealthCheck> ("startup",  tags: ["ready"]);

// ── Startup initialization ────────────────────────────────────────────────────
builder.Services.AddHostedService<StartupInitializationService>();

var app = builder.Build();

// ── Liveness: is the process alive? (no dependency checks) ───────────────────
app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = _ => false,
    ResponseWriter = WriteJsonResponse
});

// ── Readiness: are all dependencies up and initialization done? ───────────────
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = WriteJsonResponse
});

app.MapGet("/", () => "CatalogService is running.");

app.Run();

// ── Helper ────────────────────────────────────────────────────────────────────
static Task WriteJsonResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json";

    var result = new
    {
        status = report.Status.ToString(),
        checks = report.Entries.Select(e => new
        {
            name        = e.Key,
            status      = e.Value.Status.ToString(),
            description = e.Value.Description,
            duration    = e.Value.Duration.TotalMilliseconds
        })
    };

    return context.Response.WriteAsync(
        JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
}
