using CatalogService.HealthChecks;

namespace CatalogService.Services;

/// <summary>
/// Performs catalog startup initialization (e.g., seeding data) and signals readiness.
/// </summary>
public class StartupInitializationService : BackgroundService
{
    private readonly StartupHealthCheck _startupHealthCheck;
    private readonly ILogger<StartupInitializationService> _logger;

    public StartupInitializationService(
        StartupHealthCheck startupHealthCheck,
        ILogger<StartupInitializationService> logger)
    {
        _startupHealthCheck = startupHealthCheck;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("CatalogService: Starting initialization...");

        try
        {
            // Simulate catalog data seeding / container initialization.
            // Replace with real Cosmos DB seeding logic as needed.
            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);

            _startupHealthCheck.MarkReady();
            _logger.LogInformation("CatalogService: Initialization complete. Service is ready.");
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("CatalogService: Initialization was cancelled.");
        }
        catch (Exception ex)
        {
            _startupHealthCheck.MarkFailed(ex);
            _logger.LogError(ex, "CatalogService: Initialization failed.");
        }
    }
}
