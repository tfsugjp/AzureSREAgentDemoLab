using SharedLibrary.Models;

namespace CatalogService.Services;

public interface IProductService
{
    Task<IEnumerable<Product>> GetAllAsync();
    Task<Product?> GetByIdAsync(string id);
    Task<Product> CreateAsync(Product product);
    Task<Product?> UpdateAsync(string id, Product product);
    Task<bool> DeleteAsync(string id);
}
