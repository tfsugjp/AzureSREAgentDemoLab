using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Net.Http;

namespace SharedLibrary.Cosmos;

public static class CosmosDbExtensions
{
    public static IServiceCollection AddCosmosDb(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration["CosmosDb:ConnectionString"];
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("CosmosDb:ConnectionString is not configured.");
        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "GlobalAzureDemo";
        var allowInsecureCertificate = configuration.GetValue<bool>("CosmosDb:AllowInsecureCertificate");

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
                ConnectionMode = ConnectionMode.Gateway,
                ApplicationName = "GlobalAzureDemo2026"
            };

            if (allowInsecureCertificate)
            {
                var environment = configuration["ASPNETCORE_ENVIRONMENT"] ?? "Production";
                if (!environment.Equals("Development", StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException(
                        "CosmosDb:AllowInsecureCertificate can only be enabled in the Development environment. " +
                        "Do not use this setting in production.");

                logger.LogWarning("CosmosDb:AllowInsecureCertificate is enabled. SSL certificate validation is disabled. Use only in development/emulator environments.");
                var handler = new HttpClientHandler
                {
                    ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
                };
                clientOptions.HttpClientFactory = () => new HttpClient(handler, disposeHandler: false);
            }

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
