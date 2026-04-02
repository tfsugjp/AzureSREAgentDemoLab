using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace NotificationService.Services;

public class NotificationServiceImpl : INotificationService
{
    private readonly Container _container;
    private readonly ILogger<NotificationServiceImpl> _logger;

    public NotificationServiceImpl(Database database, ILogger<NotificationServiceImpl> logger)
    {
        _container = database.GetContainer("notifications");
        _logger = logger;
    }

    public async Task<IEnumerable<Notification>> GetAllAsync()
    {
        var query = _container.GetItemQueryIterator<Notification>(
            new QueryDefinition("SELECT * FROM c ORDER BY c.createdAt DESC"));

        var results = new List<Notification>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }

        _logger.LogInformation("Retrieved {Count} notifications", results.Count);
        return results;
    }

    public async Task<Notification?> GetByIdAsync(string id)
    {
        var query = _container.GetItemQueryIterator<Notification>(
            new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
                .WithParameter("@id", id));

        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            var notification = response.FirstOrDefault();
            if (notification != null)
            {
                return notification;
            }
        }

        _logger.LogWarning("Notification with ID {Id} not found", id);
        return null;
    }

    public async Task<Notification> CreateAsync(Notification notification)
    {
        notification.CreatedAt = DateTime.UtcNow;
        var response = await _container.CreateItemAsync(
            notification,
            new PartitionKey(notification.UserId));

        _logger.LogInformation("Created notification {Id} for user {UserId}", notification.Id, notification.UserId);
        return response.Resource;
    }

    public async Task<Notification?> MarkAsReadAsync(string id)
    {
        var notification = await GetByIdAsync(id);
        if (notification == null)
        {
            return null;
        }

        notification.IsRead = true;
        var response = await _container.ReplaceItemAsync(
            notification,
            notification.Id,
            new PartitionKey(notification.UserId));

        _logger.LogInformation("Marked notification {Id} as read", id);
        return response.Resource;
    }

    public async Task<IEnumerable<Notification>> GetByUserIdAsync(string userId)
    {
        var query = _container.GetItemQueryIterator<Notification>(
            new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId ORDER BY c.createdAt DESC")
                .WithParameter("@userId", userId),
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = new PartitionKey(userId)
            });

        var results = new List<Notification>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }

        _logger.LogInformation("Retrieved {Count} notifications for user {UserId}", results.Count, userId);
        return results;
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var notification = await GetByIdAsync(id);
        if (notification == null)
        {
            return false;
        }

        await _container.DeleteItemAsync<Notification>(
            id,
            new PartitionKey(notification.UserId));

        _logger.LogInformation("Deleted notification {Id}", id);
        return true;
    }
}
