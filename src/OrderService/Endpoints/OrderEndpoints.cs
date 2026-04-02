using OrderService.Services;
using SharedLibrary.Models;

namespace OrderService.Endpoints;

public static class OrderEndpoints
{
    public static WebApplication MapOrderEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/orders").WithTags("Orders");

        group.MapGet("/", async (IOrderService service) =>
        {
            var orders = await service.GetAllAsync();
            return Results.Ok(ApiResponse<IEnumerable<Order>>.Ok(orders));
        });

        group.MapGet("/{id}", async (string id, IOrderService service) =>
        {
            var order = await service.GetByIdAsync(id);
            return order is not null
                ? Results.Ok(ApiResponse<Order>.Ok(order))
                : Results.NotFound(ApiResponse<Order>.Fail($"Order '{id}' not found"));
        });

        group.MapPost("/", async (Order order, IOrderService service) =>
        {
            var created = await service.CreateAsync(order);
            return Results.Created($"/api/orders/{created.Id}", ApiResponse<Order>.Ok(created));
        });

        group.MapPut("/{id}/status", async (string id, StatusUpdateRequest request, IOrderService service) =>
        {
            var updated = await service.UpdateStatusAsync(id, request.Status);
            return updated is not null
                ? Results.Ok(ApiResponse<Order>.Ok(updated))
                : Results.BadRequest(ApiResponse<Order>.Fail($"Unable to update status for order '{id}'"));
        });

        group.MapDelete("/{id}", async (string id, IOrderService service) =>
        {
            var deleted = await service.DeleteAsync(id);
            return deleted
                ? Results.NoContent()
                : Results.NotFound(ApiResponse<bool>.Fail($"Order '{id}' not found"));
        });

        group.MapGet("/user/{userId}", async (string userId, IOrderService service) =>
        {
            var orders = await service.GetByUserIdAsync(userId);
            return Results.Ok(ApiResponse<IEnumerable<Order>>.Ok(orders));
        });

        group.MapPost("/{id}/cancel", async (string id, IOrderService service) =>
        {
            var cancelled = await service.CancelAsync(id);
            return cancelled is not null
                ? Results.Ok(ApiResponse<Order>.Ok(cancelled))
                : Results.BadRequest(ApiResponse<Order>.Fail($"Unable to cancel order '{id}'"));
        });

        group.MapGet("/{id}/total", async (string id, IOrderService service) =>
        {
            var order = await service.GetByIdAsync(id);
            if (order is null)
                return Results.NotFound(ApiResponse<decimal>.Fail($"Order '{id}' not found"));

            var total = await service.CalculateTotalAsync(id);
            return Results.Ok(ApiResponse<decimal>.Ok(total));
        });

        return app;
    }
}

public record StatusUpdateRequest(string Status);
