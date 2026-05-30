using Microsoft.Azure.Cosmos;
using SharedLibrary.Logging;
using SharedLibrary.Models;

namespace CatalogService.Services;

public class InventoryService : IInventoryService
{
    private readonly Container _container;
    private readonly ILogger<InventoryService> _logger;

    public InventoryService(Database database, ILogger<InventoryService> logger)
    {
        _container = database.GetContainer("inventory");
        _logger = logger;
    }

    public async Task<InventoryItem?> GetByProductIdAsync(string productId)
    {
        var safeProductId = LogSanitizer.Sanitize(productId);
        _logger.LogInformation("Retrieving inventory for product: {ProductId}", safeProductId);

        var query = new QueryDefinition("SELECT * FROM c WHERE c.productId = @productId")
            .WithParameter("@productId", productId);

        using var iterator = _container.GetItemQueryIterator<InventoryItem>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var item = response.FirstOrDefault();
            if (item is not null)
                return item;
        }

        return null;
    }

    public async Task<InventoryItem?> UpdateAsync(string productId, InventoryItem item)
    {
        var safeProductId = LogSanitizer.Sanitize(productId);
        _logger.LogInformation("Updating inventory for product: {ProductId}", safeProductId);

        var existing = await GetByProductIdAsync(productId);
        if (existing is null)
            return null;

        item.Id = existing.Id;
        item.ProductId = productId;
        item.UpdatedAt = DateTime.UtcNow;

        var response = await _container.ReplaceItemAsync(item, existing.Id, new PartitionKey(productId));
        return response.Resource;
    }
}
