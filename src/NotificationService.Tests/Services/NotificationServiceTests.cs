using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using NotificationService.Services;
using SharedLibrary.Models;

namespace NotificationService.Tests.Services;

[TestClass]
public sealed class NotificationServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly NotificationServiceImpl _service;

    public NotificationServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("notifications")).Returns(_mockContainer.Object);
        _service = new NotificationServiceImpl(_mockDatabase.Object, NullLogger<NotificationServiceImpl>.Instance);
    }

    private void SetupQueryIterator(IEnumerable<Notification> items)
    {
        var mockIterator = CosmosTestHelpers.CreateMockIterator(items);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Notification>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);
    }

    // ─── GetAllAsync ───────────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetAllAsync_HasNotifications_ReturnsAll()
    {
        // Arrange
        var notifications = new List<Notification>
        {
            new() { Id = "n-1", UserId = "user-1", Title = "Alert" },
            new() { Id = "n-2", UserId = "user-2", Title = "Info" },
        };
        SetupQueryIterator(notifications);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetAllAsync_NoNotifications_ReturnsEmptyList()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Notification>());

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    // ─── GetByIdAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetByIdAsync_NotificationExists_ReturnsNotification()
    {
        // Arrange
        var notification = new Notification { Id = "n-1", UserId = "user-1", Title = "Test" };
        SetupQueryIterator(new[] { notification });

        // Act
        var result = await _service.GetByIdAsync("n-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("n-1", result.Id);
        Assert.AreEqual("Test", result.Title);
    }

    [TestMethod]
    public async Task GetByIdAsync_NotificationNotFound_ReturnsNull()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Notification>());

        // Act
        var result = await _service.GetByIdAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    // ─── CreateAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task CreateAsync_ValidNotification_SetsCreatedAtAndReturns()
    {
        // Arrange
        var notification = new Notification { UserId = "user-1", Title = "Order Confirmed" };
        var created = new Notification { Id = "n-new", UserId = "user-1", Title = "Order Confirmed" };
        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(created);
        _mockContainer.Setup(c => c.CreateItemAsync(
            It.IsAny<Notification>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var before = DateTime.UtcNow.AddSeconds(-1);
        var result = await _service.CreateAsync(notification);
        var after = DateTime.UtcNow.AddSeconds(1);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("n-new", result.Id);
        Assert.IsTrue(notification.CreatedAt >= before && notification.CreatedAt <= after);
    }

    // ─── MarkAsReadAsync ──────────────────────────────────────────────────────

    [TestMethod]
    public async Task MarkAsReadAsync_NotificationExists_MarksAsReadAndReturns()
    {
        // Arrange
        var notification = new Notification { Id = "n-1", UserId = "user-1", IsRead = false };
        var readNotification = new Notification { Id = "n-1", UserId = "user-1", IsRead = true };
        SetupQueryIterator(new[] { notification });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(readNotification);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Notification>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.MarkAsReadAsync("n-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.IsTrue(result.IsRead);
        Assert.IsTrue(notification.IsRead); // mutated before replace
    }

    [TestMethod]
    public async Task MarkAsReadAsync_NotificationNotFound_ReturnsNull()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Notification>());

        // Act
        var result = await _service.MarkAsReadAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    // ─── GetByUserIdAsync ─────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetByUserIdAsync_HasNotifications_ReturnsUserNotifications()
    {
        // Arrange
        var notifications = new List<Notification>
        {
            new() { Id = "n-1", UserId = "user-5" },
            new() { Id = "n-2", UserId = "user-5" },
        };
        SetupQueryIterator(notifications);

        // Act
        var result = await _service.GetByUserIdAsync("user-5");

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetByUserIdAsync_NoNotifications_ReturnsEmptyList()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Notification>());

        // Act
        var result = await _service.GetByUserIdAsync("user-99");

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    // ─── DeleteAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task DeleteAsync_NotificationExists_DeletesAndReturnsTrue()
    {
        // Arrange
        var notification = new Notification { Id = "n-1", UserId = "user-1" };
        SetupQueryIterator(new[] { notification });

        var mockDeleteResponse = CosmosTestHelpers.CreateMockItemResponse(notification);
        _mockContainer.Setup(c => c.DeleteItemAsync<Notification>(
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockDeleteResponse.Object);

        // Act
        var result = await _service.DeleteAsync("n-1");

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteAsync_NotificationNotFound_ReturnsFalse()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Notification>());

        // Act
        var result = await _service.DeleteAsync("nonexistent");

        // Assert
        Assert.IsFalse(result);
    }
}
