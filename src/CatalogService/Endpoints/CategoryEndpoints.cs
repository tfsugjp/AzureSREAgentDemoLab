using System.Diagnostics.CodeAnalysis;
using CatalogService.Services;
using SharedLibrary.Models;

namespace CatalogService.Endpoints;

[ExcludeFromCodeCoverage]
public static class CategoryEndpoints
{
    public static WebApplication MapCategoryEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/categories").WithTags("Categories");

        group.MapGet("/", async (ICategoryService service) =>
        {
            var categories = await service.GetAllAsync();
            return Results.Ok(ApiResponse<IEnumerable<Category>>.Ok(categories));
        });

        group.MapGet("/{id}", async (string id, ICategoryService service) =>
        {
            var category = await service.GetByIdAsync(id);
            return category is not null
                ? Results.Ok(ApiResponse<Category>.Ok(category))
                : Results.NotFound(ApiResponse<Category>.Fail($"Category '{id}' not found"));
        });

        return app;
    }
}
