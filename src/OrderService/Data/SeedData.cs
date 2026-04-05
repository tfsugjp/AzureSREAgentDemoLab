using System.Diagnostics.CodeAnalysis;
using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace OrderService.Data;

[ExcludeFromCodeCoverage]
public static class SeedData
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        var database = serviceProvider.GetRequiredService<Database>();
        var container = database.GetContainer("orders");
        var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

        var orders = GetSeedOrders();

        foreach (var order in orders)
        {
            try
            {
                await container.CreateItemAsync(order, new PartitionKey(order.UserId));
                logger.LogInformation("Seeded order {OrderId}", order.Id);
            }
            catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
            {
                logger.LogDebug("Order {OrderId} already exists, skipping", order.Id);
            }
        }
    }

    private static List<Order> GetSeedOrders()
    {
        return
        [
            new Order
            {
                Id = "order-1",
                UserId = "user-1",
                Status = OrderStatus.Pending,
                ShippingAddress = "123 Main St, Seattle, WA 98101",
                Notes = "Please leave at front door",
                Items =
                [
                    new OrderItem { ProductId = "prod-1", ProductName = "Wireless Mouse", Quantity = 2, UnitPrice = 29.99m },
                    new OrderItem { ProductId = "prod-2", ProductName = "USB-C Hub", Quantity = 1, UnitPrice = 49.99m }
                ],
                TotalAmount = 109.97m,
                CreatedAt = DateTime.UtcNow.AddDays(-5),
                UpdatedAt = DateTime.UtcNow.AddDays(-5)
            },
            new Order
            {
                Id = "order-2",
                UserId = "user-1",
                Status = OrderStatus.Confirmed,
                ShippingAddress = "123 Main St, Seattle, WA 98101",
                Notes = "",
                Items =
                [
                    new OrderItem { ProductId = "prod-3", ProductName = "Mechanical Keyboard", Quantity = 1, UnitPrice = 149.99m }
                ],
                TotalAmount = 149.99m,
                CreatedAt = DateTime.UtcNow.AddDays(-4),
                UpdatedAt = DateTime.UtcNow.AddDays(-3)
            },
            new Order
            {
                Id = "order-3",
                UserId = "user-2",
                Status = OrderStatus.Shipped,
                ShippingAddress = "456 Oak Ave, Portland, OR 97201",
                Notes = "Gift wrap requested",
                Items =
                [
                    new OrderItem { ProductId = "prod-5", ProductName = "Monitor Stand", Quantity = 1, UnitPrice = 79.99m },
                    new OrderItem { ProductId = "prod-6", ProductName = "Desk Lamp", Quantity = 2, UnitPrice = 34.99m }
                ],
                TotalAmount = 149.97m,
                CreatedAt = DateTime.UtcNow.AddDays(-7),
                UpdatedAt = DateTime.UtcNow.AddDays(-2)
            },
            new Order
            {
                Id = "order-4",
                UserId = "user-2",
                Status = OrderStatus.Delivered,
                ShippingAddress = "456 Oak Ave, Portland, OR 97201",
                Notes = "",
                Items =
                [
                    new OrderItem { ProductId = "prod-8", ProductName = "Webcam HD", Quantity = 1, UnitPrice = 89.99m },
                    new OrderItem { ProductId = "prod-9", ProductName = "Ring Light", Quantity = 1, UnitPrice = 45.99m },
                    new OrderItem { ProductId = "prod-10", ProductName = "Tripod", Quantity = 1, UnitPrice = 25.99m }
                ],
                TotalAmount = 161.97m,
                CreatedAt = DateTime.UtcNow.AddDays(-14),
                UpdatedAt = DateTime.UtcNow.AddDays(-8)
            },
            new Order
            {
                Id = "order-5",
                UserId = "user-3",
                Status = OrderStatus.Cancelled,
                ShippingAddress = "789 Pine Rd, San Francisco, CA 94102",
                Notes = "Customer requested cancellation",
                Items =
                [
                    new OrderItem { ProductId = "prod-11", ProductName = "Bluetooth Speaker", Quantity = 1, UnitPrice = 59.99m }
                ],
                TotalAmount = 59.99m,
                CreatedAt = DateTime.UtcNow.AddDays(-3),
                UpdatedAt = DateTime.UtcNow.AddDays(-2)
            },
            new Order
            {
                Id = "order-6",
                UserId = "user-1",
                Status = OrderStatus.Processing,
                ShippingAddress = "123 Main St, Seattle, WA 98101",
                Notes = "Expedited shipping",
                Items =
                [
                    new OrderItem { ProductId = "prod-12", ProductName = "Laptop Sleeve", Quantity = 1, UnitPrice = 39.99m },
                    new OrderItem { ProductId = "prod-13", ProductName = "Screen Protector", Quantity = 2, UnitPrice = 14.99m }
                ],
                TotalAmount = 69.97m,
                CreatedAt = DateTime.UtcNow.AddDays(-2),
                UpdatedAt = DateTime.UtcNow.AddDays(-1)
            },
            new Order
            {
                Id = "order-7",
                UserId = "user-3",
                Status = OrderStatus.Pending,
                ShippingAddress = "789 Pine Rd, San Francisco, CA 94102",
                Notes = "",
                Items =
                [
                    new OrderItem { ProductId = "prod-14", ProductName = "Wireless Earbuds", Quantity = 1, UnitPrice = 79.99m },
                    new OrderItem { ProductId = "prod-15", ProductName = "Charging Case", Quantity = 1, UnitPrice = 19.99m }
                ],
                TotalAmount = 99.98m,
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow.AddDays(-1)
            },
            new Order
            {
                Id = "order-8",
                UserId = "user-2",
                Status = OrderStatus.Confirmed,
                ShippingAddress = "456 Oak Ave, Portland, OR 97201",
                Notes = "Second floor apartment, buzz #204",
                Items =
                [
                    new OrderItem { ProductId = "prod-16", ProductName = "USB Cable Pack", Quantity = 3, UnitPrice = 12.99m },
                    new OrderItem { ProductId = "prod-17", ProductName = "Power Bank", Quantity = 1, UnitPrice = 44.99m }
                ],
                TotalAmount = 83.96m,
                CreatedAt = DateTime.UtcNow.AddDays(-2),
                UpdatedAt = DateTime.UtcNow.AddDays(-1)
            },
            new Order
            {
                Id = "order-9",
                UserId = "user-3",
                Status = OrderStatus.Shipped,
                ShippingAddress = "789 Pine Rd, San Francisco, CA 94102",
                Notes = "Signature required",
                Items =
                [
                    new OrderItem { ProductId = "prod-18", ProductName = "External SSD 1TB", Quantity = 1, UnitPrice = 119.99m }
                ],
                TotalAmount = 119.99m,
                CreatedAt = DateTime.UtcNow.AddDays(-6),
                UpdatedAt = DateTime.UtcNow.AddDays(-3)
            },
            new Order
            {
                Id = "order-10",
                UserId = "user-1",
                Status = OrderStatus.Delivered,
                ShippingAddress = "123 Main St, Seattle, WA 98101",
                Notes = "",
                Items =
                [
                    new OrderItem { ProductId = "prod-19", ProductName = "Mouse Pad XL", Quantity = 1, UnitPrice = 24.99m },
                    new OrderItem { ProductId = "prod-20", ProductName = "Wrist Rest", Quantity = 1, UnitPrice = 19.99m },
                    new OrderItem { ProductId = "prod-4", ProductName = "Cable Clips", Quantity = 2, UnitPrice = 9.99m }
                ],
                TotalAmount = 64.96m,
                CreatedAt = DateTime.UtcNow.AddDays(-10),
                UpdatedAt = DateTime.UtcNow.AddDays(-6)
            }
        ];
    }
}
