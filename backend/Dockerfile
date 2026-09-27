# Fixo API — .NET 10 Development Dockerfile
# Used by docker-compose.yml for local dev with hot reload.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS dev

WORKDIR /app

# Install dotnet-ef
RUN dotnet tool install --global dotnet-ef
ENV PATH="$PATH:/root/.dotnet/tools"

# Restore dependencies first (layer cache)
COPY *.csproj ./
RUN dotnet restore

# Copy everything else
COPY . .

# Expose port
EXPOSE 8080

# Use dotnet watch for hot reload in development
ENTRYPOINT ["dotnet", "watch", "run", "--urls", "http://0.0.0.0:8080"]
