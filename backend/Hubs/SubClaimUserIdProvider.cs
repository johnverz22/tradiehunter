using Microsoft.AspNetCore.SignalR;

namespace FixoApi.Hubs;

/// <summary>
/// Resolves SignalR's Context.UserIdentifier / Clients.User(id) identity from
/// the JWT "sub" claim. Required because Program.cs sets MapInboundClaims=false,
/// so the default provider's ClaimTypes.NameIdentifier lookup never matches.
/// </summary>
public class SubClaimUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) =>
        connection.User?.FindFirst("sub")?.Value;
}
