using NotificationService.Services;
using SharedLibrary.Models;

namespace NotificationService.Endpoints;

public static class NotificationEndpoints
{
    public static WebApplication MapNotificationEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/notifications")
            .WithTags("Notifications");

        group.MapGet("/", async (INotificationService service) =>
        {
            var notifications = await service.GetAllAsync();
            return Results.Ok(ApiResponse<IEnumerable<Notification>>.Ok(notifications));
        });

        group.MapGet("/{id}", async (string id, INotificationService service) =>
        {
            var notification = await service.GetByIdAsync(id);
            return notification is not null
                ? Results.Ok(ApiResponse<Notification>.Ok(notification))
                : Results.NotFound(ApiResponse<Notification>.Fail($"Notification with ID '{id}' not found."));
        });

        group.MapPost("/", async (Notification notification, INotificationService service) =>
        {
            var created = await service.CreateAsync(notification);
            return Results.Created(
                $"/api/notifications/{created.Id}",
                ApiResponse<Notification>.Ok(created));
        });

        group.MapPut("/{id}/read", async (string id, INotificationService service) =>
        {
            var notification = await service.MarkAsReadAsync(id);
            return notification is not null
                ? Results.Ok(ApiResponse<Notification>.Ok(notification))
                : Results.NotFound(ApiResponse<Notification>.Fail($"Notification with ID '{id}' not found."));
        });

        group.MapGet("/user/{userId}", async (string userId, INotificationService service) =>
        {
            var notifications = await service.GetByUserIdAsync(userId);
            return Results.Ok(ApiResponse<IEnumerable<Notification>>.Ok(notifications));
        });

        group.MapDelete("/{id}", async (string id, INotificationService service) =>
        {
            var deleted = await service.DeleteAsync(id);
            return deleted
                ? Results.Ok(ApiResponse<bool>.Ok(true))
                : Results.NotFound(ApiResponse<bool>.Fail($"Notification with ID '{id}' not found."));
        });

        return app;
    }
}
