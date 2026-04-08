using Microsoft.Extensions.Diagnostics.HealthChecks;
using OrderService.HealthChecks;

namespace OrderService.Tests.HealthChecks;

[TestClass]
public class StartupHealthCheckTests
{
    private StartupHealthCheck _healthCheck = null!;
    private HealthCheckContext _context = null!;

    [TestInitialize]
    public void Setup()
    {
        _healthCheck = new StartupHealthCheck();
        _context = new HealthCheckContext
        {
            Registration = new HealthCheckRegistration("startup", _healthCheck, HealthStatus.Unhealthy, null)
        };
    }

    [TestMethod]
    public async Task CheckHealthAsync_InitialState_ReturnsUnhealthyPending()
    {
        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsTrue(result.Description!.Contains("in progress"));
    }

    [TestMethod]
    public async Task CheckHealthAsync_AfterMarkReady_ReturnsHealthy()
    {
        _healthCheck.MarkReady();

        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.IsTrue(result.Description!.Contains("complete"));
    }

    [TestMethod]
    public async Task CheckHealthAsync_AfterMarkFailed_ReturnsUnhealthy()
    {
        _healthCheck.MarkFailed();

        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.IsTrue(result.Description!.Contains("failed"));
    }
}
