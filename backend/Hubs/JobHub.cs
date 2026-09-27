using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using FixoApi.DTOs;

namespace FixoApi.Hubs;

/// <summary>
/// SignalR hub for real-time job events (M2-05).
/// Registered at /hubs/jobs.
///
/// Server → Client methods:
///   • NewJobMatch(NewJobMatchPayload)  — pushed to matched tradies
///   • JobStatusChanged(jobId, status) — pushed to homeowner + matched tradie
///
/// Client → Server methods:
///   • JoinJobGroup(jobId) — client subscribes to a specific job's updates
///   • LeaveJobGroup(jobId)
///
/// User targeting uses ASP.NET Identity claims via IHubContext.
/// </summary>
[Authorize]
public class JobHub : Hub
{
    private readonly ILogger<JobHub> _logger;

    public JobHub(ILogger<JobHub> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Called by clients to subscribe to updates for a specific job.
    /// Group name: "job-{jobId}"
    /// </summary>
    public async Task JoinJobGroup(string jobId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(jobId));
        _logger.LogInformation("User {User} joined job group {Group}",
            Context.UserIdentifier, GroupName(jobId));
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
