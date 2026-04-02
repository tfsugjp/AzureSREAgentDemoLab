using SharedLibrary.Models;

namespace OrderService.Services;

public interface IOrderService
{
    Task<IEnumerable<Order>> GetAllAsync();
    Task<Order?> GetByIdAsync(string id);
    Task<Order> CreateAsync(Order order);
    Task<Order?> UpdateStatusAsync(string id, string status);
    Task<bool> DeleteAsync(string id);
    Task<IEnumerable<Order>> GetByUserIdAsync(string userId);
    Task<Order?> CancelAsync(string id);
    Task<decimal> CalculateTotalAsync(string id);
}
