using SharedLibrary.Models;

namespace CatalogService.Services;

public interface IProductSearchService
{
    Task<IEnumerable<Product>> SearchAsync(string query);
}
