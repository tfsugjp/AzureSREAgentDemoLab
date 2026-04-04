using System.Text.Json.Serialization;

namespace SharedLibrary.Models;

public class Notification
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("userId")]
    public string UserId { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = NotificationType.Info;

    [JsonPropertyName("isRead")]
    public bool IsRead { get; set; }

    [JsonPropertyName("relatedEntityId")]
    public string? RelatedEntityId { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public static class NotificationType
{
    public const string Info = "Info";
    public const string OrderConfirmation = "OrderConfirmation";
    public const string ShipmentUpdate = "ShipmentUpdate";
    public const string Promotion = "Promotion";
    public const string Alert = "Alert";
}
