using CatalogService.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SharedLibrary.Models;

namespace CatalogService.Tests.Services;

[TestClass]
public sealed class CategoryServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly CategoryService _service;

    public CategoryServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("categories")).Returns(_mockContainer.Object);
        _service = new CategoryService(_mockDatabase.Object, NullLogger<CategoryService>.Instance);
    }

    [TestMethod]
    public async Task GetAllAsync_HasCategories_ReturnsAllActive()
    {
        // Arrange
        var categories = new List<Category>
        {
            new() { Id = "cat-1", Name = "Electronics", IsActive = true },
            new() { Id = "cat-2", Name = "Clothing", IsActive = true },
        };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(categories);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Category>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.GetAllAsync();

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task GetAllAsync_NoCategories_ReturnsEmptyList()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateEmptyIterator<Category>();
        _mockContainer.Setup(c => c.GetItemQueryIterator<Category>(
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
    public async Task GetByIdAsync_CategoryExists_ReturnsCategory()
    {
        // Arrange
        var category = new Category { Id = "cat-1", Name = "Electronics" };
        var mockItemResponse = CosmosTestHelpers.CreateMockItemResponse(category);
        _mockContainer.Setup(c => c.ReadItemAsync<Category>(
            "cat-1",
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockItemResponse.Object);

        // Act
        var result = await _service.GetByIdAsync("cat-1");

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual("cat-1", result.Id);
        Assert.AreEqual("Electronics", result.Name);
    }

    [TestMethod]
    public async Task GetByIdAsync_CategoryNotFound_ReturnsNull()
    {
        // Arrange
        _mockContainer.Setup(c => c.ReadItemAsync<Category>(
            It.IsAny<string>(),
            It.IsAny<PartitionKey>(),
            It.IsAny<ItemRequestOptions>(),
            It.IsAny<CancellationToken>()))
            .ThrowsAsync(new CosmosException("Not Found", System.Net.HttpStatusCode.NotFound, 0, "", 0));

        // Act
        var result = await _service.GetByIdAsync("nonexistent");

        // Assert
        Assert.IsNull(result);
    }
}
