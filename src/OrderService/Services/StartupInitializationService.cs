using OrderService.HealthChecks;

namespace OrderService.Services;

/// <summary>
/// Performs order service startup initialization (e.g., container setup) and signals readiness.
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
        _logger.LogInformation("OrderService: Starting initialization...");

        try
        {
            // Simulate order container setup / schema initialization.
            // Replace with real Cosmos DB initialization logic as needed.
            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);

            _startupHealthCheck.MarkReady();
            _logger.LogInformation("OrderService: Initialization complete. Service is ready.");
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("OrderService: Initialization was cancelled.");
        }
        catch (Exception ex)
        {
            _startupHealthCheck.MarkFailed(ex);
            _logger.LogError(ex, "OrderService: Initialization failed.");
        }
    }
}
