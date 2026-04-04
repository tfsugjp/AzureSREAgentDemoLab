using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace NotificationService.HealthChecks;

/// <summary>
/// Tracks startup initialization state (Pending → Ready or Failed).
/// Registered as a singleton so state persists across requests.
/// </summary>
public class StartupHealthCheck : IHealthCheck
{
    private enum InitState { Pending, Ready, Failed }

    private volatile int _state = (int)InitState.Pending;
    private string? _failureMessage;

    public void MarkReady()
    {
        Interlocked.Exchange(ref _state, (int)InitState.Ready);
    }

    public void MarkFailed(Exception? exception = null)
    {
        _failureMessage = exception?.Message;
        Interlocked.Exchange(ref _state, (int)InitState.Failed);
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var result = (InitState)_state switch
        {
            InitState.Ready   => HealthCheckResult.Healthy("Startup initialization complete."),
            InitState.Failed  => HealthCheckResult.Unhealthy($"Startup initialization failed. {_failureMessage}".TrimEnd()),
            _                 => HealthCheckResult.Unhealthy("Startup initialization is still in progress.")
        };

        return Task.FromResult(result);
    }
}
