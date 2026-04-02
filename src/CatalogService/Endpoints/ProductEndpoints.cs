using CatalogService.Services;
using SharedLibrary.Models;

namespace CatalogService.Endpoints;

public static class ProductEndpoints
{
    public static WebApplication MapProductEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/products").WithTags("Products");

        group.MapGet("/", async (IProductService service) =>
        {
            var products = await service.GetAllAsync();
            return Results.Ok(ApiResponse<IEnumerable<Product>>.Ok(products));
        });

        group.MapGet("/{id}", async (string id, IProductService service) =>
        {
            var product = await service.GetByIdAsync(id);
            return product is not null
                ? Results.Ok(ApiResponse<Product>.Ok(product))
                : Results.NotFound(ApiResponse<Product>.Fail($"Product '{id}' not found"));
        });

        group.MapPost("/", async (Product product, IProductService service) =>
        {
            var created = await service.CreateAsync(product);
            return Results.Created($"/api/products/{created.Id}", ApiResponse<Product>.Ok(created));
        });

        group.MapPut("/{id}", async (string id, Product product, IProductService service) =>
        {
            var updated = await service.UpdateAsync(id, product);
            return updated is not null
                ? Results.Ok(ApiResponse<Product>.Ok(updated))
                : Results.NotFound(ApiResponse<Product>.Fail($"Product '{id}' not found"));
        });

        group.MapDelete("/{id}", async (string id, IProductService service) =>
        {
            var deleted = await service.DeleteAsync(id);
            return deleted
                ? Results.Ok(ApiResponse<bool>.Ok(true))
                : Results.NotFound(ApiResponse<bool>.Fail($"Product '{id}' not found"));
        });

        group.MapGet("/search", async (string? q, IProductSearchService searchService) =>
        {
            if (string.IsNullOrWhiteSpace(q))
                return Results.BadRequest(ApiResponse<IEnumerable<Product>>.Fail("Query parameter 'q' is required"));

            var results = await searchService.SearchAsync(q);
            return Results.Ok(ApiResponse<IEnumerable<Product>>.Ok(results));
        });

        return app;
    }
}
