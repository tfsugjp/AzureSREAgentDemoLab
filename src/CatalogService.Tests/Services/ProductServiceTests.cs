using CatalogService.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SharedLibrary.Models;

namespace CatalogService.Tests.Services;

[TestClass]
public sealed class ProductServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly ProductService _service;

    public ProductServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("products")).Returns(_mockContainer.Object);
        _service = new ProductService(_mockDatabase.Object, NullLogger<ProductService>.Instance);
    }

    [TestMethod]
    public async Task GetAllAsync_HasProducts_ReturnsAllActiveProducts()
    {
        // Arrange
        var products = new List<Product>
        {
            new() { Id = "1", Name = "Product A", IsActive = true },
            new() { Id = "2", Name = "Product B", IsActive = true },
        };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(products);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        var list = result.ToList();
        Assert.AreEqual(2, list.Count);
    }

    [TestMethod]
    public async Task GetAllAsync_NoProducts_ReturnsEmptyList()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateEmptyIterator<Product>();
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetByIdAsync_ProductExists_ReturnsProduct()
    {
        // Arrange
        var product = new Product { Id = "prod-1", Name = "Widget" };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { product });
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetByIdAsync("prod-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("prod-1", result.Id);
        Assert.AreEqual("Widget", result.Name);
    }

    [TestMethod]
    public async Task GetByIdAsync_ProductNotFound_ReturnsNull()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateMockIterator(Array.Empty<Product>());
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetByIdAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task CreateAsync_ValidProduct_SetsTimestampsAndReturnsCreated()
    {
        // Arrange
        var product = new Product { Name = "New Product", CategoryId = "cat-1" };
        var createdProduct = new Product { Id = "new-id", Name = "New Product", CategoryId = "cat-1" };
        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(createdProduct);
        _mockContainer.Setup(c => c.CreateItemAsync(
            It.IsAny<Product>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var before = DateTime.UtcNow.AddSeconds(-1);
        var result = await _service.CreateAsync(product);
        var after = DateTime.UtcNow.AddSeconds(1);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("new-id", result.Id);
        Assert.IsTrue(product.CreatedAt >= before && product.CreatedAt <= after);
        Assert.IsTrue(product.UpdatedAt >= before && product.UpdatedAt <= after);
    }

    [TestMethod]
    public async Task UpdateAsync_ProductExists_UpdatesFieldsAndReturns()
    {
        // Arrange
        var existing = new Product { Id = "prod-1", CategoryId = "cat-1", Name = "Old Name" };
        var updateData = new Product { Name = "New Name", CategoryId = "ignored" };
        var updatedProduct = new Product { Id = "prod-1", CategoryId = "cat-1", Name = "New Name" };

        // GetByIdAsync returns existing product
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { existing });
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(updatedProduct);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Product>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.UpdateAsync("prod-1", updateData);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("prod-1", result.Id);
        Assert.AreEqual("cat-1", updateData.CategoryId); // preserved from existing
    }

    [TestMethod]
    public async Task UpdateAsync_ProductNotFound_ReturnsNull()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateMockIterator(Array.Empty<Product>());
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.UpdateAsync("nonexistent", new Product());

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task DeleteAsync_ProductExists_SoftDeletesAndReturnsTrue()
    {
        // Arrange
        var existing = new Product
        {
            Id = "prod-1",
            CategoryId = "cat-1",
            IsActive = true,
            UpdatedAt = DateTime.UtcNow.AddDays(-1)
        };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { existing });
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(existing);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            It.IsAny<Product>(),
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var result = await _service.DeleteAsync("prod-1");

        // Assert
        Assert.IsTrue(result);
        Assert.IsFalse(existing.IsActive);
    }

    [TestMethod]
    public async Task DeleteAsync_ProductExists_RefreshesUpdatedAt()
    {
        // Arrange
        var existing = new Product
        {
            Id = "prod-1",
            CategoryId = "cat-1",
            IsActive = true,
            UpdatedAt = DateTime.UtcNow.AddDays(-1)
        };
        var originalUpdatedAt = existing.UpdatedAt;
        var mockIterator = CosmosTestHelpers.CreateMockIterator(new[] { existing });
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        var mockResponse = CosmosTestHelpers.CreateMockItemResponse(existing);
        _mockContainer.Setup(c => c.ReplaceItemAsync(
            existing,
            existing.Id,
            It.Is<PartitionKey>(key => key.Equals(new PartitionKey(existing.CategoryId))),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        // Act
        var before = DateTime.UtcNow.AddSeconds(-1);
        await _service.DeleteAsync(existing.Id);
        var after = DateTime.UtcNow.AddSeconds(1);

        // Assert
        Assert.IsTrue(existing.UpdatedAt > originalUpdatedAt);
        Assert.IsTrue(existing.UpdatedAt >= before && existing.UpdatedAt <= after);
    }

    [TestMethod]
    public async Task DeleteAsync_ProductNotFound_ReturnsFalse()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateMockIterator(Array.Empty<Product>());
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.DeleteAsync("nonexistent");

        // Assert
        Assert.IsFalse(result);
    }
}
