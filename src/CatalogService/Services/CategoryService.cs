using Microsoft.Azure.Cosmos;
using SharedLibrary.Logging;
using SharedLibrary.Models;

namespace CatalogService.Services;

public class CategoryService : ICategoryService
{
    private readonly Container _container;
    private readonly ILogger<CategoryService> _logger;

    public CategoryService(Database database, ILogger<CategoryService> logger)
    {
        _container = database.GetContainer("categories");
        _logger = logger;
    }

    public async Task<IEnumerable<Category>> GetAllAsync()
    {
        _logger.LogInformation("Retrieving all active categories");

        var query = new QueryDefinition("SELECT * FROM c WHERE c.isActive = true");
        using var iterator = _container.GetItemQueryIterator<Category>(query);

        var results = new List<Category>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }

    public async Task<Category?> GetByIdAsync(string id)
    {
        var safeCategoryId = LogSanitizer.Sanitize(id);
        _logger.LogInformation("Retrieving category with ID: {CategoryId}", safeCategoryId);

        try
        {
            var response = await _container.ReadItemAsync<Category>(id, new PartitionKey(id));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            _logger.LogWarning("Category not found: {CategoryId}", safeCategoryId);
            return null;
        }
    }
}
