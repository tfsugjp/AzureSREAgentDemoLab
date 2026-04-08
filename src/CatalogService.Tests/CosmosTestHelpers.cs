using Microsoft.Azure.Cosmos;
using Moq;

namespace CatalogService.Tests;

internal static class CosmosTestHelpers
{
    internal static Mock<FeedIterator<T>> CreateMockIterator<T>(IEnumerable<T> items)
    {
        var itemList = items.ToList();
        var mockResponse = new Mock<FeedResponse<T>>();
        mockResponse.Setup(r => r.GetEnumerator()).Returns(() => itemList.GetEnumerator());

        var mockIterator = new Mock<FeedIterator<T>>();
        mockIterator.SetupSequence(i => i.HasMoreResults)
            .Returns(true)
            .Returns(false);
        mockIterator.Setup(i => i.ReadNextAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(mockResponse.Object);

        return mockIterator;
    }

    internal static Mock<FeedIterator<T>> CreateEmptyIterator<T>()
    {
        var mockIterator = new Mock<FeedIterator<T>>();
        mockIterator.Setup(i => i.HasMoreResults).Returns(false);
        return mockIterator;
    }

    internal static Mock<ItemResponse<T>> CreateMockItemResponse<T>(T item)
    {
        var mockResponse = new Mock<ItemResponse<T>>();
        mockResponse.Setup(r => r.Resource).Returns(item);
        return mockResponse;
    }
}
