using NotificationService.HealthChecks;

namespace NotificationService.Services;

/// <summary>
/// Performs notification service startup initialization (e.g., template loading) and signals readiness.
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
        _logger.LogInformation("NotificationService: Starting initialization...");

        try
        {
            // Simulate notification template loading / container initialization.
            // Replace with real Cosmos DB initialization logic as needed.
            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);

            _startupHealthCheck.MarkReady();
            _logger.LogInformation("NotificationService: Initialization complete. Service is ready.");
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("NotificationService: Initialization was cancelled.");
        }
        catch (Exception ex)
        {
            _startupHealthCheck.MarkFailed(ex);
            _logger.LogError(ex, "NotificationService: Initialization failed.");
        }
    }
}
