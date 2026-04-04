FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/SharedLibrary/SharedLibrary.csproj SharedLibrary/
COPY src/CatalogService/CatalogService.csproj CatalogService/
RUN dotnet restore CatalogService/CatalogService.csproj

COPY src/SharedLibrary/ SharedLibrary/
COPY src/CatalogService/ CatalogService/
RUN dotnet publish CatalogService/CatalogService.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "CatalogService.dll"]
