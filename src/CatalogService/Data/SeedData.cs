using System.Diagnostics.CodeAnalysis;
using System.Net;
using Microsoft.Azure.Cosmos;
using SharedLibrary.Models;

namespace CatalogService.Data;

[ExcludeFromCodeCoverage]
public static class SeedData
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        var logger = services.GetRequiredService<ILogger<Database>>();
        var database = services.GetRequiredService<Database>();

        logger.LogInformation("Seeding catalog data...");

        await SeedCategoriesAsync(database, logger);
        await SeedProductsAsync(database, logger);
        await SeedInventoryAsync(database, logger);

        logger.LogInformation("Catalog data seeding completed");
    }

    private static async Task SeedCategoriesAsync(Database database, ILogger logger)
    {
        var container = database.GetContainer("categories");
        var categories = GetCategories();

        foreach (var category in categories)
        {
            await SeedItemAsync(container, category, category.Id, logger);
        }
    }

    private static async Task SeedProductsAsync(Database database, ILogger logger)
    {
        var container = database.GetContainer("products");
        var products = GetProducts();

        foreach (var product in products)
        {
            await SeedItemAsync(container, product, product.CategoryId, logger);
        }
    }

    private static async Task SeedInventoryAsync(Database database, ILogger logger)
    {
        var container = database.GetContainer("inventory");
        var items = GetInventoryItems();

        foreach (var item in items)
        {
            await SeedItemAsync(container, item, item.ProductId, logger);
        }
    }

    private static async Task SeedItemAsync<T>(
        Container container, T item, string partitionKey, ILogger logger)
        where T : IHasId
    {
        try
        {
            await container.CreateItemAsync(item, new PartitionKey(partitionKey));
            logger.LogInformation("Seeded item: {Id}", item.Id);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            logger.LogDebug("Item {Id} already exists, skipping", item.Id);
        }
    }

    private static List<Category> GetCategories() =>
    [
        new Category
        {
            Id = "cat-1", Name = "Electronics",
            Description = "Electronic devices, gadgets, and accessories"
        },
        new Category
        {
            Id = "cat-2", Name = "Clothing",
            Description = "Apparel, footwear, and fashion accessories"
        },
        new Category
        {
            Id = "cat-3", Name = "Food",
            Description = "Gourmet food, snacks, and beverages"
        },
        new Category
        {
            Id = "cat-4", Name = "Books",
            Description = "Physical and digital books across all genres"
        },
        new Category
        {
            Id = "cat-5", Name = "Premium",
            Description = "Premium and luxury items across all categories"
        }
    ];

    private static List<Product> GetProducts() =>
    [
        // Electronics (cat-1)
        new Product
        {
            Id = "prod-1", Name = "Wireless Bluetooth Headphones",
            Description = "High-quality wireless headphones with noise cancellation",
            Price = 79.99m, CategoryId = "cat-1", CategoryName = "Electronics",
            Tags = ["audio", "wireless", "headphones"], ImageUrl = "/images/headphones.jpg"
        },
        new Product
        {
            Id = "prod-2", Name = "USB-C Charging Hub",
            Description = "Multi-port USB-C hub with fast charging support",
            Price = 49.99m, CategoryId = "cat-1", CategoryName = "Electronics",
            Tags = ["usb", "charging", "accessories"], ImageUrl = "/images/hub.jpg"
        },
        new Product
        {
            Id = "prod-3", Name = "4K Webcam",
            Description = "Ultra HD webcam for streaming and video conferencing",
            Price = 129.99m, CategoryId = "cat-1", CategoryName = "Electronics",
            Tags = ["webcam", "video", "streaming"], ImageUrl = "/images/webcam.jpg"
        },
        new Product
        {
            Id = "prod-4", Name = "Mechanical Keyboard",
            Description = "RGB mechanical keyboard with cherry switches",
            Price = 149.99m, CategoryId = "cat-1", CategoryName = "Electronics",
            Tags = ["keyboard", "gaming", "mechanical"], ImageUrl = "/images/keyboard.jpg"
        },
        // Clothing (cat-2)
        new Product
        {
            Id = "prod-5", Name = "Cotton T-Shirt",
            Description = "Comfortable 100% cotton t-shirt in multiple colors",
            Price = 24.99m, CategoryId = "cat-2", CategoryName = "Clothing",
            Tags = ["cotton", "casual", "t-shirt"], ImageUrl = "/images/tshirt.jpg"
        },
        new Product
        {
            Id = "prod-6", Name = "Denim Jeans",
            Description = "Classic fit denim jeans with stretch fabric",
            Price = 59.99m, CategoryId = "cat-2", CategoryName = "Clothing",
            Tags = ["denim", "jeans", "casual"], ImageUrl = "/images/jeans.jpg"
        },
        new Product
        {
            Id = "prod-7", Name = "Running Shoes",
            Description = "Lightweight running shoes with cushioned soles",
            Price = 89.99m, CategoryId = "cat-2", CategoryName = "Clothing",
            Tags = ["shoes", "running", "sports"], ImageUrl = "/images/shoes.jpg"
        },
        new Product
        {
            Id = "prod-8", Name = "Winter Jacket",
            Description = "Insulated waterproof jacket for cold weather",
            Price = 199.99m, CategoryId = "cat-2", CategoryName = "Clothing",
            Tags = ["jacket", "winter", "outerwear"], ImageUrl = "/images/jacket.jpg"
        },
        // Food (cat-3)
        new Product
        {
            Id = "prod-9", Name = "Organic Coffee Beans",
            Description = "Fair-trade organic arabica coffee beans 1kg",
            Price = 18.99m, CategoryId = "cat-3", CategoryName = "Food",
            Tags = ["coffee", "organic", "beverages"], ImageUrl = "/images/coffee.jpg"
        },
        new Product
        {
            Id = "prod-10", Name = "Dark Chocolate Assortment",
            Description = "Artisan dark chocolate collection from around the world",
            Price = 34.99m, CategoryId = "cat-3", CategoryName = "Food",
            Tags = ["chocolate", "gourmet", "gifts"], ImageUrl = "/images/chocolate.jpg"
        },
        new Product
        {
            Id = "prod-11", Name = "Matcha Green Tea Set",
            Description = "Traditional Japanese matcha tea with bamboo whisk",
            Price = 42.99m, CategoryId = "cat-3", CategoryName = "Food",
            Tags = ["tea", "matcha", "japanese"], ImageUrl = "/images/matcha.jpg"
        },
        new Product
        {
            Id = "prod-12", Name = "Mixed Nuts Pack",
            Description = "Roasted and salted premium mixed nuts 500g",
            Price = 14.99m, CategoryId = "cat-3", CategoryName = "Food",
            Tags = ["nuts", "snacks", "healthy"], ImageUrl = "/images/nuts.jpg"
        },
        // Books (cat-4)
        new Product
        {
            Id = "prod-13", Name = "Cloud Architecture Patterns",
            Description = "Comprehensive guide to designing scalable cloud applications",
            Price = 49.99m, CategoryId = "cat-4", CategoryName = "Books",
            Tags = ["cloud", "architecture", "technology"], ImageUrl = "/images/cloudbook.jpg"
        },
        new Product
        {
            Id = "prod-14", Name = "Site Reliability Engineering",
            Description = "How Google runs production systems - the SRE handbook",
            Price = 54.99m, CategoryId = "cat-4", CategoryName = "Books",
            Tags = ["sre", "devops", "technology"], ImageUrl = "/images/srebook.jpg"
        },
        new Product
        {
            Id = "prod-15", Name = "The Art of Debugging",
            Description = "Practical techniques for finding and fixing software bugs",
            Price = 39.99m, CategoryId = "cat-4", CategoryName = "Books",
            Tags = ["debugging", "programming", "technology"], ImageUrl = "/images/debugbook.jpg"
        },
        new Product
        {
            Id = "prod-16", Name = "Microservices Design Patterns",
            Description = "Building resilient and observable distributed systems",
            Price = 44.99m, CategoryId = "cat-4", CategoryName = "Books",
            Tags = ["microservices", "patterns", "technology"], ImageUrl = "/images/msbook.jpg"
        },
        // Premium (cat-5)
        new Product
        {
            Id = "prod-17", Name = "Premium Noise-Cancelling Headphones",
            Description = "Top-tier premium wireless headphones with spatial audio",
            Price = 349.99m, CategoryId = "cat-5", CategoryName = "Premium",
            Tags = ["premium", "audio", "headphones", "luxury"], ImageUrl = "/images/premiumheadphones.jpg"
        },
        new Product
        {
            Id = "prod-18", Name = "Premium Leather Briefcase",
            Description = "Handcrafted Italian leather premium briefcase",
            Price = 449.99m, CategoryId = "cat-5", CategoryName = "Premium",
            Tags = ["premium", "leather", "briefcase", "luxury"], ImageUrl = "/images/briefcase.jpg"
        },
        new Product
        {
            Id = "prod-19", Name = "Premium Swiss Watch",
            Description = "Precision-crafted premium Swiss automatic watch",
            Price = 1299.99m, CategoryId = "cat-5", CategoryName = "Premium",
            Tags = ["premium", "watch", "swiss", "luxury"], ImageUrl = "/images/watch.jpg"
        },
        new Product
        {
            Id = "prod-20", Name = "Premium Espresso Machine",
            Description = "Professional-grade premium espresso machine with grinder",
            Price = 899.99m, CategoryId = "cat-5", CategoryName = "Premium",
            Tags = ["premium", "coffee", "espresso", "luxury"], ImageUrl = "/images/espresso.jpg"
        }
    ];

    private static List<InventoryItem> GetInventoryItems() =>
    [
        new InventoryItem { Id = "inv-1", ProductId = "prod-1", Quantity = 150, ReservedQuantity = 12, ReorderThreshold = 20 },
        new InventoryItem { Id = "inv-2", ProductId = "prod-2", Quantity = 200, ReservedQuantity = 5, ReorderThreshold = 30 },
        new InventoryItem { Id = "inv-3", ProductId = "prod-3", Quantity = 75, ReservedQuantity = 8, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-4", ProductId = "prod-4", Quantity = 100, ReservedQuantity = 3, ReorderThreshold = 15 },
        new InventoryItem { Id = "inv-5", ProductId = "prod-5", Quantity = 500, ReservedQuantity = 25, ReorderThreshold = 50 },
        new InventoryItem { Id = "inv-6", ProductId = "prod-6", Quantity = 300, ReservedQuantity = 18, ReorderThreshold = 40 },
        new InventoryItem { Id = "inv-7", ProductId = "prod-7", Quantity = 120, ReservedQuantity = 10, ReorderThreshold = 15 },
        new InventoryItem { Id = "inv-8", ProductId = "prod-8", Quantity = 80, ReservedQuantity = 6, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-9", ProductId = "prod-9", Quantity = 400, ReservedQuantity = 30, ReorderThreshold = 50 },
        new InventoryItem { Id = "inv-10", ProductId = "prod-10", Quantity = 250, ReservedQuantity = 15, ReorderThreshold = 30 },
        new InventoryItem { Id = "inv-11", ProductId = "prod-11", Quantity = 180, ReservedQuantity = 7, ReorderThreshold = 20 },
        new InventoryItem { Id = "inv-12", ProductId = "prod-12", Quantity = 350, ReservedQuantity = 20, ReorderThreshold = 40 },
        new InventoryItem { Id = "inv-13", ProductId = "prod-13", Quantity = 60, ReservedQuantity = 4, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-14", ProductId = "prod-14", Quantity = 45, ReservedQuantity = 2, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-15", ProductId = "prod-15", Quantity = 90, ReservedQuantity = 5, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-16", ProductId = "prod-16", Quantity = 70, ReservedQuantity = 3, ReorderThreshold = 10 },
        new InventoryItem { Id = "inv-17", ProductId = "prod-17", Quantity = 25, ReservedQuantity = 2, ReorderThreshold = 5 },
        new InventoryItem { Id = "inv-18", ProductId = "prod-18", Quantity = 15, ReservedQuantity = 1, ReorderThreshold = 5 },
        new InventoryItem { Id = "inv-19", ProductId = "prod-19", Quantity = 10, ReservedQuantity = 1, ReorderThreshold = 5 },
        new InventoryItem { Id = "inv-20", ProductId = "prod-20", Quantity = 20, ReservedQuantity = 3, ReorderThreshold = 5 }
    ];
}
