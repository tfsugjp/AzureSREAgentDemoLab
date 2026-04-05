using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using OrderService.Services;
using SharedLibrary.Models;

namespace OrderService.Tests.Services;

[TestClass]
public sealed class OrderServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly OrderServiceImpl _service;

    public OrderServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("orders")).Returns(_mockContainer.Object);
        _service = new OrderServiceImpl(_mockDatabase.Object, NullLogger<OrderServiceImpl>.Instance);
    }

    private void SetupQueryIterator(IEnumerable<Order> orders)
    {
        var mockIterator = CosmosTestHelpers.CreateMockIterator(orders);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Order>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);
    }

    private void SetupStringQueryIterator(IEnumerable<Order> orders)
    {
        var mockIterator = CosmosTestHelpers.CreateMockIterator(orders);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Order>(
            It.IsAny<string>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);
    }

    // ─── GetAllAsync ───────────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetAllAsync_HasOrders_ReturnsAllOrders()
    {
        // Arrange
        var orders = new List<Order>
        {
            new() { Id = "order-1", UserId = "user-1" },
            new() { Id = "order-2", UserId = "user-2" },
        };
        SetupStringQueryIterator(orders);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetAllAsync_NoOrders_ReturnsEmptyList()
    {
        // Arrange
        SetupStringQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    // ─── GetByIdAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetByIdAsync_OrderExists_ReturnsOrder()
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Pending };
        SetupQueryIterator(new[] { order });

        // Act
        var result = await _service.GetByIdAsync("order-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("order-1", result.Id);
    }

    [TestMethod]
    public async Task GetByIdAsync_OrderNotFound_ReturnsNull()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.GetByIdAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    // ─── CreateAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task CreateAsync_NoIdProvided_GeneratesIdAndSetsPendingStatus()
    {
        // Arrange
        var order = new Order
        {
            Id = "",
            UserId = "user-1",
            Items = [new OrderItem { Quantity = 2, UnitPrice = 10m }]
        };
        var createdOrder = new Order { Id = "new-guid", UserId = "user-1", Status = OrderStatus.Pending, TotalAmount = 20m };
        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(createdOrder);
        _mockContainer.Setup(c => c.CreateItemAsync(
            It.IsAny<Order>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.CreateAsync(order);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(OrderStatus.Pending, order.Status);
        Assert.AreEqual(20m, order.TotalAmount);
        Assert.IsFalse(string.IsNullOrWhiteSpace(order.Id));
    }

    [TestMethod]
    public async Task CreateAsync_WithExistingId_PreservesId()
    {
        // Arrange
        var order = new Order
        {
            Id = "existing-id",
            UserId = "user-1",
            Items = [new OrderItem { Quantity = 1, UnitPrice = 5m }]
        };
        var createdOrder = new Order { Id = "existing-id", Status = OrderStatus.Pending };
        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(createdOrder);
        _mockContainer.Setup(c => c.CreateItemAsync(
            It.IsAny<Order>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        await _service.CreateAsync(order);

        // Assert
        Assert.AreEqual("existing-id", order.Id);
    }

    [TestMethod]
    public async Task CreateAsync_ValidOrder_SetsTimestampsAndUsesUserPartitionKey()
    {
        // Arrange
        var order = new Order
        {
            UserId = "user-1",
            Items =
            [
                new OrderItem { Quantity = 2, UnitPrice = 10m },
                new OrderItem { Quantity = 1, UnitPrice = 5m }
            ]
        };
        var createdOrder = new Order { Id = "created-order", UserId = "user-1", TotalAmount = 25m };
        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(createdOrder);
        _mockContainer.Setup(c => c.CreateItemAsync(
            order,
            It.Is<PartitionKey>(key => key.Equals(new PartitionKey(order.UserId))),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var before = DateTime.UtcNow.AddSeconds(-1);
        var result = await _service.CreateAsync(order);
        var after = DateTime.UtcNow.AddSeconds(1);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(25m, order.TotalAmount);
        Assert.IsTrue(order.CreatedAt >= before && order.CreatedAt <= after);
        Assert.IsTrue(order.UpdatedAt >= before && order.UpdatedAt <= after);
    }

    // ─── UpdateStatusAsync ────────────────────────────────────────────────────

    [TestMethod]
    public async Task UpdateStatusAsync_InvalidStatusName_ReturnsNull()
    {
        // Act
        var result = await _service.UpdateStatusAsync("order-1", "InvalidStatus");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task UpdateStatusAsync_OrderNotFound_ReturnsNull()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.UpdateStatusAsync("nonexistent", OrderStatus.Confirmed);

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task UpdateStatusAsync_InvalidTransition_ReturnsNull()
    {
        // Arrange - Shipped → Pending is not allowed
        var order = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Shipped };
        SetupQueryIterator(new[] { order });

        // Act
        var result = await _service.UpdateStatusAsync("order-1", OrderStatus.Pending);

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task UpdateStatusAsync_ValidTransition_UpdatesStatusAndReturns()
    {
        // Arrange - Pending → Confirmed is a valid transition
        var order = new Order
        {
            Id = "order-1",
            UserId = "user-1",
            Status = OrderStatus.Pending,
            UpdatedAt = DateTime.UtcNow.AddDays(-1)
        };
        var updatedOrder = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Confirmed };

        SetupQueryIterator(new[] { order });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(updatedOrder);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Order>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.UpdateStatusAsync("order-1", OrderStatus.Confirmed);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(OrderStatus.Confirmed, result.Status);
    }

    [TestMethod]
    public async Task UpdateStatusAsync_ValidTransition_RefreshesUpdatedAtAndUsesUserPartitionKey()
    {
        // Arrange
        var order = new Order
        {
            Id = "order-1",
            UserId = "user-1",
            Status = OrderStatus.Pending,
            UpdatedAt = DateTime.UtcNow.AddDays(-1)
        };
        var originalUpdatedAt = order.UpdatedAt;
        var updatedOrder = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Confirmed };

        SetupQueryIterator(new[] { order });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(updatedOrder);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            order,
            order.Id,
            It.Is<PartitionKey>(key => key.Equals(new PartitionKey(order.UserId))),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var before = DateTime.UtcNow.AddSeconds(-1);
        await _service.UpdateStatusAsync(order.Id, OrderStatus.Confirmed);
        var after = DateTime.UtcNow.AddSeconds(1);

        // Assert
        Assert.AreEqual(OrderStatus.Confirmed, order.Status);
        Assert.IsTrue(order.UpdatedAt > originalUpdatedAt);
        Assert.IsTrue(order.UpdatedAt >= before && order.UpdatedAt <= after);
    }

    [TestMethod]
    [DataRow(OrderStatus.Pending, OrderStatus.Confirmed, DisplayName = "Pending→Confirmed")]
    [DataRow(OrderStatus.Pending, OrderStatus.Cancelled, DisplayName = "Pending→Cancelled")]
    [DataRow(OrderStatus.Confirmed, OrderStatus.Processing, DisplayName = "Confirmed→Processing")]
    [DataRow(OrderStatus.Confirmed, OrderStatus.Cancelled, DisplayName = "Confirmed→Cancelled")]
    [DataRow(OrderStatus.Processing, OrderStatus.Shipped, DisplayName = "Processing→Shipped")]
    [DataRow(OrderStatus.Shipped, OrderStatus.Delivered, DisplayName = "Shipped→Delivered")]
    public async Task UpdateStatusAsync_AllValidTransitions_Succeed(string currentStatus, string newStatus)
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1", Status = currentStatus };
        var updatedOrder = new Order { Id = "order-1", Status = newStatus };

        SetupQueryIterator(new[] { order });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(updatedOrder);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Order>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.UpdateStatusAsync("order-1", newStatus);

        // Assert
        Assert.IsNotNull(result);
    }

    // ─── DeleteAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task DeleteAsync_OrderExists_DeletesAndReturnsTrue()
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1" };
        SetupQueryIterator(new[] { order });

        var mockDeleteResponse = CosmosTestHelpers.CreateMockItemResponse(order);
        _mockContainer.Setup(c => c.DeleteItemAsync<Order>(
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockDeleteResponse.Object);

        // Act
        var result = await _service.DeleteAsync("order-1");

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteAsync_OrderNotFound_ReturnsFalse()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.DeleteAsync("nonexistent");

        // Assert
        Assert.IsFalse(result);
    }

    // ─── GetByUserIdAsync ─────────────────────────────────────────────────────

    [TestMethod]
    public async Task GetByUserIdAsync_HasOrders_ReturnsUserOrders()
    {
        // Arrange
        var orders = new List<Order>
        {
            new() { Id = "order-1", UserId = "user-42" },
            new() { Id = "order-2", UserId = "user-42" },
        };
        SetupQueryIterator(orders);

        // Act
        var result = await _service.GetByUserIdAsync("user-42");

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetByUserIdAsync_NoOrders_ReturnsEmptyList()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.GetByUserIdAsync("user-99");

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    // ─── CancelAsync ──────────────────────────────────────────────────────────

    [TestMethod]
    public async Task CancelAsync_OrderNotFound_ReturnsNull()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.CancelAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task CancelAsync_PendingOrder_CancelsAndReturns()
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Pending };
        var cancelledOrder = new Order { Id = "order-1", Status = OrderStatus.Cancelled };
        SetupQueryIterator(new[] { order });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(cancelledOrder);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Order>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.CancelAsync("order-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(OrderStatus.Cancelled, result.Status);
    }

    [TestMethod]
    public async Task CancelAsync_ConfirmedOrder_CancelsAndReturns()
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1", Status = OrderStatus.Confirmed };
        var cancelledOrder = new Order { Id = "order-1", Status = OrderStatus.Cancelled };
        SetupQueryIterator(new[] { order });

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(cancelledOrder);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Order>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.CancelAsync("order-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(OrderStatus.Cancelled, result.Status);
    }

    [TestMethod]
    [DataRow(OrderStatus.Processing, DisplayName = "Cannot cancel Processing order")]
    [DataRow(OrderStatus.Shipped, DisplayName = "Cannot cancel Shipped order")]
    [DataRow(OrderStatus.Delivered, DisplayName = "Cannot cancel Delivered order")]
    [DataRow(OrderStatus.Cancelled, DisplayName = "Cannot cancel already Cancelled order")]
    public async Task CancelAsync_NonCancellableStatus_ReturnsNull(string status)
    {
        // Arrange
        var order = new Order { Id = "order-1", UserId = "user-1", Status = status };
        SetupQueryIterator(new[] { order });

        // Act
        var result = await _service.CancelAsync("order-1");

        // Assert
        Assert.IsNull(result);
    }

    // ─── CalculateTotalAsync ─────────────────────────────────────────────────

    [TestMethod]
    public async Task CalculateTotalAsync_OrderExists_ReturnsTotalAmount()
    {
        // Arrange
        var order = new Order { Id = "order-1", TotalAmount = 123.45m };
        SetupQueryIterator(new[] { order });

        // Act
        var result = await _service.CalculateTotalAsync("order-1");

        // Assert
        Assert.AreEqual(123.45m, result);
    }

    [TestMethod]
    public async Task CalculateTotalAsync_OrderNotFound_ReturnsZero()
    {
        // Arrange
        SetupQueryIterator(Array.Empty<Order>());

        // Act
        var result = await _service.CalculateTotalAsync("nonexistent");

        // Assert
        Assert.AreEqual(0m, result);
    }
}
