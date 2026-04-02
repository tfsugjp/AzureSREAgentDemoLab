FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY SharedLibrary/SharedLibrary.csproj SharedLibrary/
COPY CatalogService/CatalogService.csproj CatalogService/
RUN dotnet restore CatalogService/CatalogService.csproj

COPY SharedLibrary/ SharedLibrary/
COPY CatalogService/ CatalogService/
RUN dotnet publish CatalogService/CatalogService.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "CatalogService.dll"]
