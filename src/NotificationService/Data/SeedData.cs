using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace NotificationService.Data;

public static class SeedData
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        var database = serviceProvider.GetRequiredService<Database>();
        var container = database.GetContainer("notifications");
        var logger = serviceProvider.GetRequiredService<ILogger<Program>>();

        var notifications = new List<Notification>
        {
            new()
            {
                Id = "notif-1",
                UserId = "user-1",
                Title = "Order confirmed",
                Message = "Your order #order-1 has been confirmed.",
                Type = NotificationType.OrderConfirmation,
                IsRead = true,
                RelatedEntityId = "order-1",
                CreatedAt = DateTime.UtcNow.AddDays(-10)
            },
            new()
            {
                Id = "notif-2",
                UserId = "user-1",
                Title = "Shipment dispatched",
                Message = "Your order #order-1 has been shipped and is on its way.",
                Type = NotificationType.ShipmentUpdate,
                IsRead = true,
                RelatedEntityId = "order-1",
                CreatedAt = DateTime.UtcNow.AddDays(-9)
            },
            new()
            {
                Id = "notif-3",
                UserId = "user-1",
                Title = "Flash sale: 20% off electronics!",
                Message = "Don't miss our limited-time flash sale on all electronics. Use code FLASH20.",
                Type = NotificationType.Promotion,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-5)
            },
            new()
            {
                Id = "notif-4",
                UserId = "user-1",
                Title = "Welcome to Global Azure Store",
                Message = "Thank you for creating your account. Explore our latest products!",
                Type = NotificationType.Info,
                IsRead = true,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-15)
            },
            new()
            {
                Id = "notif-5",
                UserId = "user-1",
                Title = "System maintenance scheduled",
                Message = "Planned maintenance on May 30, 2026 from 02:00 to 04:00 UTC.",
                Type = NotificationType.Alert,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-1)
            },
            new()
            {
                Id = "notif-6",
                UserId = "user-2",
                Title = "Order confirmed",
                Message = "Your order #order-2 has been confirmed.",
                Type = NotificationType.OrderConfirmation,
                IsRead = true,
                RelatedEntityId = "order-2",
                CreatedAt = DateTime.UtcNow.AddDays(-8)
            },
            new()
            {
                Id = "notif-7",
                UserId = "user-2",
                Title = "Shipment dispatched",
                Message = "Your order #order-2 has been shipped and is on its way.",
                Type = NotificationType.ShipmentUpdate,
                IsRead = false,
                RelatedEntityId = "order-2",
                CreatedAt = DateTime.UtcNow.AddDays(-7)
            },
            new()
            {
                Id = "notif-8",
                UserId = "user-2",
                Title = "Delivery completed",
                Message = "Your order #order-2 has been delivered successfully.",
                Type = NotificationType.ShipmentUpdate,
                IsRead = false,
                RelatedEntityId = "order-2",
                CreatedAt = DateTime.UtcNow.AddDays(-6)
            },
            new()
            {
                Id = "notif-9",
                UserId = "user-2",
                Title = "Exclusive member discount",
                Message = "As a valued member, enjoy 15% off your next purchase. Code: MEMBER15.",
                Type = NotificationType.Promotion,
                IsRead = true,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-4)
            },
            new()
            {
                Id = "notif-10",
                UserId = "user-2",
                Title = "Password change reminder",
                Message = "It's been 90 days since your last password change. Please update your password.",
                Type = NotificationType.Alert,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-2)
            },
            new()
            {
                Id = "notif-11",
                UserId = "user-3",
                Title = "Order confirmed",
                Message = "Your order #order-3 has been confirmed.",
                Type = NotificationType.OrderConfirmation,
                IsRead = true,
                RelatedEntityId = "order-3",
                CreatedAt = DateTime.UtcNow.AddDays(-12)
            },
            new()
            {
                Id = "notif-12",
                UserId = "user-3",
                Title = "New arrivals this week",
                Message = "Check out the latest products added to our catalog this week.",
                Type = NotificationType.Info,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-3)
            },
            new()
            {
                Id = "notif-13",
                UserId = "user-3",
                Title = "Summer sale starts now!",
                Message = "Up to 50% off on selected items. Shop the summer collection today!",
                Type = NotificationType.Promotion,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-2)
            },
            new()
            {
                Id = "notif-14",
                UserId = "user-3",
                Title = "Shipment dispatched",
                Message = "Your order #order-3 has been shipped and is on its way.",
                Type = NotificationType.ShipmentUpdate,
                IsRead = true,
                RelatedEntityId = "order-3",
                CreatedAt = DateTime.UtcNow.AddDays(-11)
            },
            new()
            {
                Id = "notif-15",
                UserId = "user-3",
                Title = "Account security alert",
                Message = "A new login was detected from an unrecognized device. Please verify your account.",
                Type = NotificationType.Alert,
                IsRead = false,
                RelatedEntityId = null,
                CreatedAt = DateTime.UtcNow.AddDays(-1)
            }
        };

        logger.LogInformation("Seeding {Count} notifications...", notifications.Count);

        foreach (var notification in notifications)
        {
            try
            {
                await container.CreateItemAsync(
                    notification,
                    new PartitionKey(notification.UserId));
                logger.LogInformation("Seeded notification {Id}", notification.Id);
            }
            catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
            {
                logger.LogDebug("Notification {Id} already exists, skipping", notification.Id);
            }
        }

        logger.LogInformation("Notification seed data complete");
    }
}
