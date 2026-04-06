using System.Diagnostics.CodeAnalysis;
using CatalogService.Data;
using CatalogService.HealthChecks;
using SharedLibrary.Cosmos;

namespace CatalogService.Services;

[ExcludeFromCodeCoverage]
public class StartupInitializationService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IConfiguration _configuration;
    private readonly StartupHealthCheck _startupHealthCheck;
    private readonly ILogger<StartupInitializationService> _logger;

    public StartupInitializationService(
        IServiceProvider serviceProvider,
        IConfiguration configuration,
        StartupHealthCheck startupHealthCheck,
        ILogger<StartupInitializationService> logger)
    {
        _serviceProvider = serviceProvider;
        _configuration = configuration;
        _startupHealthCheck = startupHealthCheck;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("CatalogService: Starting initialization...");

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var databaseName = _configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";

            await scope.ServiceProvider.EnsureCosmosDbCreatedAsync(databaseName,
            [
                ("products", "/categoryId"),
                ("categories", "/id"),
                ("inventory", "/productId")
            ]);

            await SeedData.SeedAsync(scope.ServiceProvider);

            _startupHealthCheck.MarkReady();
            _logger.LogInformation("CatalogService: Initialization complete. Service is ready.");
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("CatalogService: Initialization was cancelled.");
        }
        catch (Exception ex)
        {
            _startupHealthCheck.MarkFailed();
            _logger.LogError(ex, "CatalogService: Initialization failed.");
        }
    }
}
