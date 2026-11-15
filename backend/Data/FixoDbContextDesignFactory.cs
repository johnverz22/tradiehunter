using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace FixoApi.Data;

/// <summary>
/// Design-time factory so `dotnet ef migrations add` can build the model
/// without going through <c>Program.cs</c> (whose startup wires cloud
/// credentials and rate limiting that do not exist on a build machine).
/// The connection string is never used at design time — EF only needs a
/// provider to translate the model into DDL.
/// </summary>
public class FixoDbContextDesignFactory : IDesignTimeDbContextFactory<FixoDbContext>
{
    public FixoDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<FixoDbContext>();
        optionsBuilder.UseNpgsql("Host=localhost;Database=fixo;Username=design;Password=design", o => o.UseNetTopologySuite());
        return new FixoDbContext(optionsBuilder.Options);
    }
}
