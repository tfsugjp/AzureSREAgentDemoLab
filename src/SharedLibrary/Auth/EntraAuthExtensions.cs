using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Identity.Web;

namespace SharedLibrary.Auth;

public static class EntraAuthExtensions
{
    public static IServiceCollection AddEntraAuth(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddMicrosoftIdentityWebApi(configuration.GetSection("AzureAd"));

        services.AddAuthorizationBuilder()
            .AddFallbackPolicy("RequireAuthenticatedUser", policy =>
                policy.RequireAuthenticatedUser());

        return services;
    }

    public static WebApplication UseEntraAuth(this WebApplication app)
    {
        app.UseAuthentication();
        app.UseAuthorization();
        return app;
    }
}
