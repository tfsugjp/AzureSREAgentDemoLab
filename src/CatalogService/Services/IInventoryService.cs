using SharedLibrary.Models;

namespace CatalogService.Services;

public interface IInventoryService
{
    Task<InventoryItem?> GetByProductIdAsync(string productId);
    Task<InventoryItem?> UpdateAsync(string productId, InventoryItem item);
}
