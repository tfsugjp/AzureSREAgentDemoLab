using SharedLibrary.Models;

namespace CatalogService.Tests.Models;

[TestClass]
public class SharedLibraryModelTests
{
    [TestMethod]
    public void ApiResponse_Ok_SetsSuccessTrueAndData()
    {
        var data = "test data";
        var response = ApiResponse<string>.Ok(data);

        Assert.IsTrue(response.Success);
        Assert.AreEqual(data, response.Data);
        Assert.IsNull(response.Error);
    }

    [TestMethod]
    public void ApiResponse_Fail_SetsSuccessFalseAndError()
    {
        var error = "something went wrong";
        var response = ApiResponse<string>.Fail(error);

        Assert.IsFalse(response.Success);
        Assert.AreEqual(error, response.Error);
        Assert.IsNull(response.Data);
    }

    [TestMethod]
    public void ApiResponse_HasTimestamp()
    {
        var response = ApiResponse<int>.Ok(42);

        Assert.IsTrue(response.Timestamp > DateTime.UtcNow.AddMinutes(-1));
    }

    [TestMethod]
    public void Notification_DefaultValues_AreCorrect()
    {
        var notification = new Notification();

        Assert.IsFalse(string.IsNullOrEmpty(notification.Id));
        Assert.AreEqual(string.Empty, notification.UserId);
        Assert.AreEqual(string.Empty, notification.Title);
        Assert.AreEqual(string.Empty, notification.Message);
        Assert.AreEqual(NotificationType.Info, notification.Type);
        Assert.IsFalse(notification.IsRead);
        Assert.IsNull(notification.RelatedEntityId);
    }

    [TestMethod]
    public void Notification_CanSetAllProperties()
    {
        var notification = new Notification
        {
            Id = "notif-1",
            UserId = "user-1",
            Title = "Order Shipped",
            Message = "Your order has shipped",
            Type = NotificationType.ShipmentUpdate,
            IsRead = true,
            RelatedEntityId = "order-123"
        };

        Assert.AreEqual("notif-1", notification.Id);
        Assert.AreEqual("user-1", notification.UserId);
        Assert.AreEqual("Order Shipped", notification.Title);
        Assert.AreEqual("Your order has shipped", notification.Message);
        Assert.AreEqual(NotificationType.ShipmentUpdate, notification.Type);
        Assert.IsTrue(notification.IsRead);
        Assert.AreEqual("order-123", notification.RelatedEntityId);
    }

    [TestMethod]
    public void NotificationType_Constants_AreCorrect()
    {
        Assert.AreEqual("Info", NotificationType.Info);
        Assert.AreEqual("OrderConfirmation", NotificationType.OrderConfirmation);
        Assert.AreEqual("ShipmentUpdate", NotificationType.ShipmentUpdate);
        Assert.AreEqual("Promotion", NotificationType.Promotion);
        Assert.AreEqual("Alert", NotificationType.Alert);
    }

    [TestMethod]
    public void Order_DefaultValues_AreCorrect()
    {
        var order = new Order();

        Assert.IsFalse(string.IsNullOrEmpty(order.Id));
        Assert.AreEqual(string.Empty, order.UserId);
        Assert.IsNotNull(order.Items);
        Assert.AreEqual(0, order.Items.Count);
        Assert.AreEqual(OrderStatus.Pending, order.Status);
        Assert.AreEqual(0m, order.TotalAmount);
        Assert.AreEqual(string.Empty, order.ShippingAddress);
        Assert.AreEqual(string.Empty, order.Notes);
    }

    [TestMethod]
    public void OrderStatus_Constants_AreCorrect()
    {
        Assert.AreEqual("Pending", OrderStatus.Pending);
        Assert.AreEqual("Confirmed", OrderStatus.Confirmed);
        Assert.AreEqual("Processing", OrderStatus.Processing);
        Assert.AreEqual("Shipped", OrderStatus.Shipped);
        Assert.AreEqual("Delivered", OrderStatus.Delivered);
        Assert.AreEqual("Cancelled", OrderStatus.Cancelled);
    }

    [TestMethod]
    public void OrderItem_SubtotalCalculation_IsCorrect()
    {
        var item = new OrderItem
        {
            ProductId = "prod-1",
            ProductName = "Widget",
            Quantity = 3,
            UnitPrice = 9.99m
        };

        Assert.AreEqual(29.97m, item.Subtotal);
        Assert.AreEqual("prod-1", item.ProductId);
        Assert.AreEqual("Widget", item.ProductName);
    }

    [TestMethod]
    public void InventoryItem_AvailableQuantityCalculation_IsCorrect()
    {
        var item = new InventoryItem
        {
            Quantity = 100,
            ReservedQuantity = 15
        };

        Assert.AreEqual(85, item.AvailableQuantity);
    }

    [TestMethod]
    public void InventoryItem_DefaultValues_AreCorrect()
    {
        var item = new InventoryItem();

        Assert.IsFalse(string.IsNullOrEmpty(item.Id));
        Assert.AreEqual(10, item.ReorderThreshold);
        Assert.IsNull(item.LastRestockedAt);
    }
}
