using Microsoft.Azure.Cosmos;
using SharedLibrary.Logging;
using SharedLibrary.Models;

namespace CatalogService.Services;

public class ProductService : IProductService
{
    private readonly Container _container;
    private readonly ILogger<ProductService> _logger;

    public ProductService(Database database, ILogger<ProductService> logger)
    {
        _container = database.GetContainer("products");
        _logger = logger;
    }

    public async Task<IEnumerable<Product>> GetAllAsync()
    {
        _logger.LogInformation("Retrieving all active products");

        var query = new QueryDefinition("SELECT * FROM c WHERE c.isActive = true");
        using var iterator = _container.GetItemQueryIterator<Product>(query);

        var results = new List<Product>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }

    public async Task<Product?> GetByIdAsync(string id)
    {
        var safeProductId = LogSanitizer.Sanitize(id);
        _logger.LogInformation("Retrieving product with ID: {ProductId}", safeProductId);

        var query = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
            .WithParameter("@id", id);

        using var iterator = _container.GetItemQueryIterator<Product>(query);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            var product = response.FirstOrDefault();
            if (product is not null)
                return product;
        }

        return null;
    }

    public async Task<Product> CreateAsync(Product product)
    {
        var safeProductName = LogSanitizer.Sanitize(product.Name);
        _logger.LogInformation("Creating product: {ProductName}", safeProductName);

        product.CreatedAt = DateTime.UtcNow;
        product.UpdatedAt = DateTime.UtcNow;

        var response = await _container.CreateItemAsync(product, new PartitionKey(product.CategoryId));
        return response.Resource;
    }

    public async Task<Product?> UpdateAsync(string id, Product product)
    {
        var safeProductId = LogSanitizer.Sanitize(id);
        _logger.LogInformation("Updating product with ID: {ProductId}", safeProductId);

        var existing = await GetByIdAsync(id);
        if (existing is null)
            return null;

        product.Id = id;
        product.CategoryId = existing.CategoryId;
        product.UpdatedAt = DateTime.UtcNow;

        var response = await _container.ReplaceItemAsync(product, id, new PartitionKey(product.CategoryId));
        return response.Resource;
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var safeProductId = LogSanitizer.Sanitize(id);
        _logger.LogInformation("Soft-deleting product with ID: {ProductId}", safeProductId);

        var existing = await GetByIdAsync(id);
        if (existing is null)
            return false;

        existing.IsActive = false;
        existing.UpdatedAt = DateTime.UtcNow;

        await _container.ReplaceItemAsync(existing, id, new PartitionKey(existing.CategoryId));
        return true;
    }
}
