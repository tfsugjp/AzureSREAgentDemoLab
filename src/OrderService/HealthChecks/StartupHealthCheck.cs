using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace OrderService.HealthChecks;

/// <summary>
/// Tracks startup initialization state (Pending → Ready or Failed).
/// Registered as a singleton so state persists across requests.
/// </summary>
public class StartupHealthCheck : IHealthCheck
{
    private enum InitState { Pending, Ready, Failed }

    private volatile int _state = (int)InitState.Pending;

    public void MarkReady()
    {
        Interlocked.Exchange(ref _state, (int)InitState.Ready);
    }

    public void MarkFailed(Exception? exception = null)
    {
        Interlocked.Exchange(ref _state, (int)InitState.Failed);
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var result = (InitState)_state switch
        {
            InitState.Ready   => HealthCheckResult.Healthy("Startup initialization complete."),
            InitState.Failed  => HealthCheckResult.Unhealthy("Startup initialization failed."),
            _                 => HealthCheckResult.Unhealthy("Startup initialization is still in progress.")
        };

        return Task.FromResult(result);
    }
}
