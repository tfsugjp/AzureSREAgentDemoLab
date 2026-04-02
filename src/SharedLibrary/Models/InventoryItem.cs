using System.Text.Json.Serialization;

namespace SharedLibrary.Models;

public class InventoryItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }

    [JsonPropertyName("reservedQuantity")]
    public int ReservedQuantity { get; set; }

    [JsonPropertyName("availableQuantity")]
    public int AvailableQuantity => Quantity - ReservedQuantity;

    [JsonPropertyName("reorderThreshold")]
    public int ReorderThreshold { get; set; } = 10;

    [JsonPropertyName("lastRestockedAt")]
    public DateTime? LastRestockedAt { get; set; }

    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
