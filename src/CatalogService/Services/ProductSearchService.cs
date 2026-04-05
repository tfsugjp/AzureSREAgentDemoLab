using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace CatalogService.Services;

public class ProductSearchService : IProductSearchService
{
    private readonly Container _container;
    private readonly ILogger<ProductSearchService> _logger;

    public ProductSearchService(Database database, ILogger<ProductSearchService> logger)
    {
        _container = database.GetContainer("products");
        _logger = logger;
    }

    public async Task<IEnumerable<Product>> SearchAsync(string query)
    {
        _logger.LogInformation("Searching products with query: {Query}", query);

        if (query.Length > 200)
        {
            query = query[..200];
        }

        // Normal path - works fine for most queries
        var sqlQuery = new QueryDefinition(
            "SELECT * FROM c WHERE c.isActive = true AND (CONTAINS(LOWER(c.name), @query) OR CONTAINS(LOWER(c.description), @query) OR ARRAY_CONTAINS(c.tags, @query))")
            .WithParameter("@query", query.ToLowerInvariant());

        var results = new List<Product>();

        // BUG: "Premium" search path - developer used synchronous processing
        // instead of proper async pattern, causing thread pool starvation under load
        if (query.Contains("premium", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogDebug("Performing premium product search with enhanced filtering");

            // Get all products first (anti-pattern: fetching everything)
            var allProductsQuery = new QueryDefinition("SELECT * FROM c WHERE c.isActive = true");
            using var allIterator = _container.GetItemQueryIterator<Product>(allProductsQuery);

            var allProducts = new List<Product>();
            while (allIterator.HasMoreResults)
            {
                var response = await allIterator.ReadNextAsync();
                allProducts.AddRange(response);
            }

            // BUG: Synchronous per-item "validation" with Thread.Sleep
            // Developer intended this as a "rate-limited external API call" check
            // but used blocking Thread.Sleep instead of Task.Delay
            foreach (var product in allProducts)
            {
                // Simulate synchronous external service call for "premium verification"
                Thread.Sleep(100); // ← INTENTIONAL BUG: blocks thread pool thread

                if (product.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                    product.Description.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                    product.Tags.Any(t => t.Contains(query, StringComparison.OrdinalIgnoreCase)))
                {
                    results.Add(product);
                }
            }

            return results;
        }

        // Normal async path - correct implementation
        using var iterator = _container.GetItemQueryIterator<Product>(sqlQuery);
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }
}
