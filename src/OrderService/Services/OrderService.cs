using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace OrderService.Services;

public class OrderServiceImpl : IOrderService
{
    private readonly Container _container;
    private readonly ILogger<OrderServiceImpl> _logger;

    private static readonly HashSet<string> ValidStatuses =
    [
        OrderStatus.Pending,
        OrderStatus.Confirmed,
        OrderStatus.Processing,
        OrderStatus.Shipped,
        OrderStatus.Delivered,
        OrderStatus.Cancelled
    ];

    // Defines which status transitions are allowed: current → set of valid next statuses
    private static readonly Dictionary<string, HashSet<string>> AllowedTransitions = new()
    {
        [OrderStatus.Pending] = [OrderStatus.Confirmed, OrderStatus.Cancelled],
        [OrderStatus.Confirmed] = [OrderStatus.Processing, OrderStatus.Cancelled],
        [OrderStatus.Processing] = [OrderStatus.Shipped],
        [OrderStatus.Shipped] = [OrderStatus.Delivered],
        [OrderStatus.Delivered] = [],
        [OrderStatus.Cancelled] = []
    };

    public OrderServiceImpl(Database database, ILogger<OrderServiceImpl> logger)
    {
        _container = database.GetContainer("orders");
        _logger = logger;
    }

    public async Task<IEnumerable<Order>> GetAllAsync()
    {
        var query = _container.GetItemQueryIterator<Order>("SELECT * FROM c");
        var results = new List<Order>();

        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }

        _logger.LogInformation("Retrieved {Count} orders", results.Count);
        return results;
    }

    public async Task<Order?> GetByIdAsync(string id)
    {
        var query = _container.GetItemQueryIterator<Order>(
            new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
                .WithParameter("@id", id));

        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            var order = response.FirstOrDefault();
            if (order is not null)
                return order;
        }

        _logger.LogWarning("Order {OrderId} not found", id);
        return null;
    }

    public async Task<Order> CreateAsync(Order order)
    {
        order.Id = string.IsNullOrWhiteSpace(order.Id) ? Guid.NewGuid().ToString() : order.Id;
        order.Status = OrderStatus.Pending;
        order.TotalAmount = order.Items.Sum(i => i.Subtotal);
        order.CreatedAt = DateTime.UtcNow;
        order.UpdatedAt = DateTime.UtcNow;

        var response = await _container.CreateItemAsync(order, new PartitionKey(order.UserId));
        _logger.LogInformation("Created order {OrderId} for user {UserId}", order.Id, order.UserId);
        return response.Resource;
    }

    public async Task<Order?> UpdateStatusAsync(string id, string status)
    {
        if (!ValidStatuses.Contains(status))
        {
            _logger.LogWarning("Invalid status '{Status}' for order {OrderId}", status, id);
            return null;
        }

        var order = await GetByIdAsync(id);
        if (order is null)
            return null;

        if (AllowedTransitions.TryGetValue(order.Status, out var allowed) && !allowed.Contains(status))
        {
            _logger.LogWarning("Invalid status transition from '{Current}' to '{New}' for order {OrderId}",
                order.Status, status, id);
            return null;
        }

        order.Status = status;
        order.UpdatedAt = DateTime.UtcNow;

        var response = await _container.ReplaceItemAsync(order, order.Id, new PartitionKey(order.UserId));
        _logger.LogInformation("Updated order {OrderId} status to {Status}", id, status);
        return response.Resource;
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var order = await GetByIdAsync(id);
        if (order is null)
            return false;

        await _container.DeleteItemAsync<Order>(id, new PartitionKey(order.UserId));
        _logger.LogInformation("Deleted order {OrderId}", id);
        return true;
    }

    public async Task<IEnumerable<Order>> GetByUserIdAsync(string userId)
    {
        var query = _container.GetItemQueryIterator<Order>(
            new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId")
                .WithParameter("@userId", userId),
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(userId) });

        var results = new List<Order>();
        while (query.HasMoreResults)
        {
            var response = await query.ReadNextAsync();
            results.AddRange(response);
        }

        _logger.LogInformation("Retrieved {Count} orders for user {UserId}", results.Count, userId);
        return results;
    }

    public async Task<Order?> CancelAsync(string id)
    {
        var order = await GetByIdAsync(id);
        if (order is null)
            return null;

        if (order.Status is not (OrderStatus.Pending or OrderStatus.Confirmed))
        {
            _logger.LogWarning("Cannot cancel order {OrderId} with status '{Status}'", id, order.Status);
            return null;
        }

        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        var response = await _container.ReplaceItemAsync(order, order.Id, new PartitionKey(order.UserId));
        _logger.LogInformation("Cancelled order {OrderId}", id);
        return response.Resource;
    }

    public async Task<decimal> CalculateTotalAsync(string id)
    {
        var order = await GetByIdAsync(id);
        return order?.TotalAmount ?? 0m;
    }
}
