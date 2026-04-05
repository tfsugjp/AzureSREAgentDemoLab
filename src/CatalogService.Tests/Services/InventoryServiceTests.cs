using CatalogService.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SharedLibrary.Models;

namespace CatalogService.Tests.Services;

[TestClass]
public sealed class InventoryServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly InventoryService _service;

    public InventoryServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("inventory")).Returns(_mockContainer.Object);
        _service = new InventoryService(_mockDatabase.Object, NullLogger<InventoryService>.Instance);
    }

    [TestMethod]
    public async Task GetByProductIdAsync_ItemExists_ReturnsInventoryItem()
    {
        // Arrange
        var item = new InventoryItem { ProductId = "prod-1", Quantity = 50, ReservedQuantity = 5 };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { item });
        _mockContainer.Setup(c => c.GetItemQueryIterator<InventoryItem>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetByProductIdAsync("prod-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("prod-1", result.ProductId);
        Assert.AreEqual(50, result.Quantity);
        Assert.AreEqual(45, result.AvailableQuantity);
    }

    [TestMethod]
    public async Task GetByProductIdAsync_ItemNotFound_ReturnsNull()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateMockIterator(Array.Empty<InventoryItem>());
        _mockContainer.Setup(c => c.GetItemQueryIterator<InventoryItem>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetByProductIdAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task UpdateAsync_ExistingItem_UpdatesAndReturns()
    {
        // Arrange
        var existing = new InventoryItem { Id = "inv-1", ProductId = "prod-1", Quantity = 100 };
        var updateData = new InventoryItem { Quantity = 200, ReorderThreshold = 20 };
        var updatedItem = new InventoryItem { Id = "inv-1", ProductId = "prod-1", Quantity = 200 };

        // GetByProductIdAsync
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { existing });
        _mockContainer.Setup(c => c.GetItemQueryIterator<InventoryItem>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(updatedItem);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<InventoryItem>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.UpdateAsync("prod-1", updateData);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("inv-1", result.Id);
        Assert.AreEqual("inv-1", updateData.Id); // preserved from existing
        Assert.AreEqual("prod-1", updateData.ProductId); // preserved from existing
    }

    [TestMethod]
    public async Task UpdateAsync_ItemNotFound_ReturnsNull()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateMockIterator(Array.Empty<InventoryItem>());
        _mockContainer.Setup(c => c.GetItemQueryIterator<InventoryItem>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.UpdateAsync("nonexistent", new InventoryItem());

        // Assert
        Assert.IsNull(result);
    }
}
