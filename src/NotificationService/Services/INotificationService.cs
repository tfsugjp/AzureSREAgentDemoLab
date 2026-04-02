using SharedLibrary.Models;

namespace NotificationService.Services;

public interface INotificationService
{
    Task<IEnumerable<Notification>> GetAllAsync();
    Task<Notification?> GetByIdAsync(string id);
    Task<Notification> CreateAsync(Notification notification);
    Task<Notification?> MarkAsReadAsync(string id);
    Task<IEnumerable<Notification>> GetByUserIdAsync(string userId);
    Task<bool> DeleteAsync(string id);
}
