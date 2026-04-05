using CatalogService.Services;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using SharedLibrary.Models;

namespace CatalogService.Tests.Services;

[TestClass]
public sealed class ProductSearchServiceTests
{
    private readonly Mock<Database> _mockDatabase;
    private readonly Mock<Container> _mockContainer;
    private readonly ProductSearchService _service;

    public ProductSearchServiceTests()
    {
        _mockDatabase = new Mock<Database>();
        _mockContainer = new Mock<Container>();
        _mockDatabase.Setup(d => d.GetContainer("products")).Returns(_mockContainer.Object);
        _service = new ProductSearchService(_mockDatabase.Object, NullLogger<ProductSearchService>.Instance);
    }

    [TestMethod]
    public async Task SearchAsync_NormalQuery_ReturnsMatchingProducts()
    {
        // Arrange
        var products = new List<Product>
        {
            new() { Id = "1", Name = "Widget", IsActive = true },
            new() { Id = "2", Name = "Gadget", IsActive = true },
        };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(products);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.SearchAsync("widget");

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task SearchAsync_EmptyResults_ReturnsEmptyList()
    {
        // Arrange
        var mockIterator = CosmosTestHelpers.CreateEmptyIterator<Product>();
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.SearchAsync("xyz_no_match");

        // Assert
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task SearchAsync_QueryBetween100And199Chars_ThrowsArgumentOutOfRangeException()
    {
        // Arrange - query exactly 150 chars (>100 but <200) triggers the substring bug
        var query = new string('a', 150);

        // Act & Assert - the bug: query.Substring(100, 100) throws when length is 150
        await Assert.ThrowsExceptionAsync<ArgumentOutOfRangeException>(
            async () => await _service.SearchAsync(query));
    }

    [TestMethod]
    public async Task SearchAsync_QueryOver200Chars_TruncatesAndSearches()
    {
        // Arrange - query >= 200 chars does NOT throw (BUG path executes fully)
        var query = new string('a', 200);
        var products = new List<Product> { new() { Id = "1", Name = "test" } };
        var mockIterator = CosmosTestHelpers.CreateMockIterator(products);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(mockIterator.Object);

        // Act
        var result = await _service.SearchAsync(query);

        // Assert - query truncated to first 200 chars
        Assert.AreEqual(1, result.Count());
    }

    [TestMethod]
    public async Task SearchAsync_PremiumQuery_UsesPremiumSearchPath()
    {
        // Arrange - "premium" in query triggers the slow path
        var products = new List<Product>
        {
            new() { Id = "1", Name = "premium widget", IsActive = true, Description = "" },
        };
        var allProductsIterator = CosmosTestHelpers.CreateMockIterator(products);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(allProductsIterator.Object);

        // Act
        var result = await _service.SearchAsync("premium");

        // Assert
        var list = result.ToList();
        Assert.AreEqual(1, list.Count);
        Assert.AreEqual("premium widget", list[0].Name);
    }

    [TestMethod]
    public async Task SearchAsync_PremiumQueryWithNoMatchingProducts_ReturnsEmpty()
    {
        // Arrange - "premium" triggers slow path but no products match
        var products = new List<Product>
        {
            new() { Id = "1", Name = "regular widget", IsActive = true, Description = "", Tags = [] },
        };
        var allProductsIterator = CosmosTestHelpers.CreateMockIterator(products);
        _mockContainer.Setup(c => c.GetItemQueryIterator<Product>(
            It.IsAny<QueryDefinition>(),
            It.IsAny<string>(),
            It.IsAny<QueryRequestOptions>()))
            .Returns(allProductsIterator.Object);

        // Act
        var result = await _service.SearchAsync("premium");

        // Assert
        Assert.AreEqual(0, result.Count());
    }
}
