using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Models;
using System.Text.Json;

namespace FixoApi.Services;

public interface IAuditLogService
{
    Task LogAsync(
        string? userId,
        string action,
        string? entityType = null,
        string? entityId = null,
        object? oldValues = null,
        object? newValues = null,
        string? ipAddress = null,
        CancellationToken ct = default);

    Task<PagedResult<AuditLogDto>> QueryAsync(
        DateTime? fromUtc,
        DateTime? toUtc,
        string? action,
        string? userId,
        int page,
        int pageSize,
        CancellationToken ct = default);
}

public class AuditLogDto
{
    public int Id { get; set; }
    public string? UserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string? EntityType { get; set; }
    public string? EntityId { get; set; }
    public string? OldValues { get; set; }
    public string? NewValues { get; set; }
    public string? IpAddress { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public class AuditLogQueryParams
{
    public DateTime? FromUtc { get; set; }
    public DateTime? ToUtc { get; set; }
    public string? Action { get; set; }
    public string? UserId { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

/// <summary>
/// P8-01/P8-04: append-only audit log for admin + critical system actions.
/// Old/new states are JSON snapshots so the admin UI can show a diff modal.
/// Failures are swallowed — auditing must never break the action it records.
/// </summary>
public class AuditLogService : IAuditLogService
{
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    private readonly FixoDbContext _db;
    private readonly IHttpContextAccessor _http;
    private readonly ILogger<AuditLogService> _logger;

    public AuditLogService(
        FixoDbContext db,
        IHttpContextAccessor http,
        ILogger<AuditLogService> logger)
    {
        _db = db;
        _http = http;
        _logger = logger;
    }

    public async Task LogAsync(
        string? userId,
        string action,
        string? entityType = null,
        string? entityId = null,
        object? oldValues = null,
        object? newValues = null,
        string? ipAddress = null,
        CancellationToken ct = default)
    {
        try
        {
            var ip = ipAddress ?? _http.HttpContext?.Connection.RemoteIpAddress?.ToString();
            _db.AuditLogs.Add(new AuditLog
            {
                UserId = userId,
                Action = action,
                EntityType = entityType,
                EntityId = entityId,
                OldValues = oldValues is null ? null : JsonSerializer.Serialize(oldValues, JsonOpts),
                NewValues = newValues is null ? null : JsonSerializer.Serialize(newValues, JsonOpts),
                IpAddress = ip,
                CreatedAtUtc = DateTime.UtcNow,
            });
            await _db.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Audit log write failed for action {Action}.", action);
        }
    }

    public async Task<PagedResult<AuditLogDto>> QueryAsync(
        DateTime? fromUtc,
        DateTime? toUtc,
        string? action,
        string? userId,
        int page,
        int pageSize,
        CancellationToken ct = default)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _db.AuditLogs.AsQueryable();
        if (fromUtc.HasValue) query = query.Where(a => a.CreatedAtUtc >= fromUtc.Value);
        if (toUtc.HasValue) query = query.Where(a => a.CreatedAtUtc <= toUtc.Value);
        if (!string.IsNullOrWhiteSpace(action)) query = query.Where(a => a.Action == action);
        if (!string.IsNullOrWhiteSpace(userId)) query = query.Where(a => a.UserId == userId);

        var total = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions
            .CountAsync(query, ct);

        var rows = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions
            .ToListAsync(
                query.OrderByDescending(a => a.CreatedAtUtc)
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize),
                ct);

        return new PagedResult<AuditLogDto>
        {
            Items = rows.Select(a => new AuditLogDto
            {
                Id = a.Id,
                UserId = a.UserId,
                Action = a.Action,
                EntityType = a.EntityType,
                EntityId = a.EntityId,
                OldValues = a.OldValues,
                NewValues = a.NewValues,
                IpAddress = a.IpAddress,
                CreatedAtUtc = a.CreatedAtUtc,
            }).ToList(),
            TotalCount = total,
            Page = page,
            PageSize = pageSize,
        };
    }
}
