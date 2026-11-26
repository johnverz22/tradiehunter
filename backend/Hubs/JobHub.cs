using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.DTOs;
using Microsoft.EntityFrameworkCore;

namespace FixoApi.Hubs;

/// <summary>
/// SignalR hub for real-time job events (M2-05).
/// Registered at /hubs/jobs.
///
/// Server → Client methods:
///   • NewJobMatch(NewJobMatchPayload)       — pushed to matched tradies
///   • JobStatusChanged(JobStatusChangedPayload) — every status transition
///   • OfferLifecycleEvent(OfferLifecyclePayload) — sequential offer events
///     (OfferCreated | OfferExpired | OfferAccepted | OfferDeclined)
///
/// Client → Server methods:
///   • JoinJobGroup(jobId) — client subscribes to a specific job's updates
///     (authorised: homeowner, matched/offered tradie, staff)
///   • LeaveJobGroup(jobId)
///
/// User targeting uses ASP.NET Identity claims via IHubContext.
/// </summary>
[Authorize]
public class JobHub : Hub
{
    private readonly FixoDbContext _context;
    private readonly ILogger<JobHub> _logger;

    public JobHub(FixoDbContext context, ILogger<JobHub> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Called by clients to subscribe to updates for a specific job.
    /// Group name: "job-{jobId}". Only the job's homeowner, its matched
    /// tradie, a tradie holding an offer on it, or staff may join; anyone else
    /// gets a <see cref="HubException"/> (same rule shape as ChatHub.JoinJob).
    /// </summary>
    public async Task JoinJobGroup(string jobId)
    {
        var userId = Context.UserIdentifier;
        var isStaff = Context.User?.IsInRole(nameof(UserRole.Staff)) == true
            || Context.User?.IsInRole(nameof(UserRole.Superadmin)) == true;

        if (userId == null
            || !int.TryParse(jobId, out var id)
            || !await CanJoinAsync(_context, id, userId, isStaff))
        {
            _logger.LogWarning("Unauthorised JoinJobGroup attempt: user={User} job={Job}",
                userId, jobId);
            throw new HubException("Not authorized to join this job.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(jobId));
        _logger.LogInformation("User {User} joined job group {Group}",
            userId, GroupName(jobId));
    }

    /// <summary>
    /// Group-membership rule for <see cref="JoinJobGroup"/>: homeowner, matched
    /// tradie, any tradie with an offer on the job, or staff.
    /// </summary>
    public static async Task<bool> CanJoinAsync(
        FixoDbContext context, int jobId, string userId, bool isStaff)
    {
        var job = await context.Jobs
            .AsNoTracking()
            .Where(j => j.Id == jobId)
            .Select(j => new { j.HomeownerId, j.MatchedTradieId })
            .FirstOrDefaultAsync();

        if (job == null) return false;
        if (isStaff) return true;
        if (job.HomeownerId == userId || job.MatchedTradieId == userId) return true;

        return await context.JobOffers
            .AsNoTracking()
            .AnyAsync(o => o.JobId == jobId && o.TradieId == userId);
    }

    /// <summary>Called by clients to unsubscribe from a job's updates.</summary>
    public async Task LeaveJobGroup(string jobId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(jobId));
    }

    public override async Task OnConnectedAsync()
    {
        _logger.LogInformation("SignalR connected: {ConnectionId} user={User}",
            Context.ConnectionId, Context.UserIdentifier);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogInformation("SignalR disconnected: {ConnectionId}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    public static string GroupName(int jobId) => $"job-{jobId}";
    public static string GroupName(string jobId) => $"job-{jobId}";
}
