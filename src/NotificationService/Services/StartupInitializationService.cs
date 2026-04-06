using System.Diagnostics.CodeAnalysis;
using NotificationService.Data;
using NotificationService.HealthChecks;
using SharedLibrary.Cosmos;

namespace NotificationService.Services;

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
        _logger.LogInformation("NotificationService: Starting initialization...");

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var databaseName = _configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";

            await scope.ServiceProvider.EnsureCosmosDbCreatedAsync(databaseName,
            [
                ("notifications", "/userId")
            ]);

            await SeedData.SeedAsync(scope.ServiceProvider);

            _startupHealthCheck.MarkReady();
            _logger.LogInformation("NotificationService: Initialization complete. Service is ready.");
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("NotificationService: Initialization was cancelled.");
        }
        catch (Exception ex)
        {
            _startupHealthCheck.MarkFailed();
            _logger.LogError(ex, "NotificationService: Initialization failed.");
        }
    }
}
