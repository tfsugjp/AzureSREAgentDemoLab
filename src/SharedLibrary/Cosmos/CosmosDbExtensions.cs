using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace SharedLibrary.Cosmos;

public static class CosmosDbExtensions
{
    public static IServiceCollection AddCosmosDb(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration["CosmosDb:ConnectionString"]
            ?? throw new InvalidOperationException("CosmosDb:ConnectionString is not configured.");
        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";

        services.AddSingleton<CosmosClient>(sp =>
        {
            var logger = sp.GetRequiredService<ILogger<CosmosClient>>();
            logger.LogInformation("Initializing Cosmos DB client for database: {Database}", databaseName);

            var clientOptions = new CosmosClientOptions
            {
                SerializerOptions = new CosmosSerializationOptions
                {
                    PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
                },
                ConnectionMode = ConnectionMode.Direct,
                ApplicationName = "GlobalAzureDemo2026"
            };

            return new CosmosClient(connectionString, clientOptions);
        });

        services.AddSingleton<Database>(sp =>
        {
            var client = sp.GetRequiredService<CosmosClient>();
            return client.GetDatabase(databaseName);
        });

        return services;
    }

    public static async Task EnsureCosmosDbCreatedAsync(
        this IServiceProvider serviceProvider,
        string databaseName,
        IEnumerable<(string containerName, string partitionKeyPath)> containers)
    {
        var client = serviceProvider.GetRequiredService<CosmosClient>();
        var logger = serviceProvider.GetRequiredService<ILogger<CosmosClient>>();

        logger.LogInformation("Ensuring Cosmos DB database '{Database}' exists...", databaseName);
        var databaseResponse = await client.CreateDatabaseIfNotExistsAsync(databaseName);
        var database = databaseResponse.Database;

        foreach (var (containerName, partitionKeyPath) in containers)
        {
            logger.LogInformation("Ensuring container '{Container}' exists with partition key '{PartitionKey}'...",
                containerName, partitionKeyPath);
            await database.CreateContainerIfNotExistsAsync(containerName, partitionKeyPath);
        }
    }
}
