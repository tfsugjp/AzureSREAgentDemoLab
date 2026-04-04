using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace OrderService.HealthChecks;

/// <summary>
/// Tracks whether startup initialization (e.g., order container setup) has completed.
/// Registered as a singleton so the <see cref="IsReady"/> flag persists across requests.
/// </summary>
public class StartupHealthCheck : IHealthCheck
{
    private volatile bool _isReady;

    public bool IsReady
    {
        get => _isReady;
        set => _isReady = value;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(_isReady
            ? HealthCheckResult.Healthy("Startup initialization complete.")
            : HealthCheckResult.Unhealthy("Startup initialization is still in progress."));
    }
}
