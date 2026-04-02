using CatalogService.Services;
using SharedLibrary.Models;

namespace CatalogService.Endpoints;

public static class InventoryEndpoints
{
    public static WebApplication MapInventoryEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/inventory").WithTags("Inventory");

        group.MapGet("/{productId}", async (string productId, IInventoryService service) =>
        {
            var item = await service.GetByProductIdAsync(productId);
            return item is not null
                ? Results.Ok(ApiResponse<InventoryItem>.Ok(item))
                : Results.NotFound(ApiResponse<InventoryItem>.Fail($"Inventory for product '{productId}' not found"));
        });

        group.MapPut("/{productId}", async (string productId, InventoryItem item, IInventoryService service) =>
        {
            var updated = await service.UpdateAsync(productId, item);
            return updated is not null
                ? Results.Ok(ApiResponse<InventoryItem>.Ok(updated))
                : Results.NotFound(ApiResponse<InventoryItem>.Fail($"Inventory for product '{productId}' not found"));
        });

        return app;
    }
}
