using OrderService.Data;
using OrderService.HealthChecks;
using SharedLibrary.Cosmos;

namespace OrderService.Services;

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
        _logger.LogInformation("OrderService: Starting initialization...");

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var databaseName = _configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";

            await scope.ServiceProvider.EnsureCosmosDbCreatedAsync(databaseName,
            [
                ("orders", "/userId")
            ]);

            await SeedData.SeedAsync(scope.ServiceProvider);

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
