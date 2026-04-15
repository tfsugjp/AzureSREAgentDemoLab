using System.Net;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Moq;
using CatalogService.HealthChecks;

namespace CatalogService.Tests.HealthChecks;

[TestClass]
public class CosmosDbHealthCheckTests
{
    private Mock<CosmosClient> _mockCosmosClient = null!;
    private CosmosDbHealthCheck _healthCheck = null!;
    private HealthCheckContext _context = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockCosmosClient = new Mock<CosmosClient>();
        _healthCheck = new CosmosDbHealthCheck(_mockCosmosClient.Object);
        _context = new HealthCheckContext
        {
            Registration = new HealthCheckRegistration("test", _healthCheck, HealthStatus.Unhealthy, null)
        };
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenCosmosDbReachable_ReturnsHealthy()
    {
        _mockCosmosClient
            .Setup(c => c.ReadAccountAsync())
            .ReturnsAsync((AccountProperties)null!);

        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Healthy, result.Status);
        Assert.AreEqual("Cosmos DB is reachable.", result.Description);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenCosmosDbUnreachable_ReturnsUnhealthy()
    {
        var exception = new CosmosException("Connection failed", HttpStatusCode.ServiceUnavailable, 0, "", 0);
        _mockCosmosClient
            .Setup(c => c.ReadAccountAsync())
            .ThrowsAsync(exception);

        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Cosmos DB is unreachable.", result.Description);
        Assert.IsNotNull(result.Exception);
    }

    [TestMethod]
    public async Task CheckHealthAsync_WhenGenericExceptionThrown_ReturnsUnhealthy()
    {
        var exception = new HttpRequestException("Network error");
        _mockCosmosClient
            .Setup(c => c.ReadAccountAsync())
            .ThrowsAsync(exception);

        var result = await _healthCheck.CheckHealthAsync(_context);

        Assert.AreEqual(HealthStatus.Unhealthy, result.Status);
        Assert.AreEqual("Cosmos DB is unreachable.", result.Description);
        Assert.AreSame(exception, result.Exception);
    }
}
