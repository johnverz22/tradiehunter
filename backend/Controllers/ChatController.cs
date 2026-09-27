using FixoApi.DTOs;
using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// REST endpoints for chat message history and sending (M3-03).
/// Real-time delivery uses the SignalR ChatHub — these endpoints cover
/// initial load and scroll-back only.
/// </summary>
[ApiController]
[Route("api/jobs/{jobId:int}/messages")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly IChatService _chatService;

    public ChatController(IChatService chatService)
    {
        _chatService = chatService;
    }

    // ── GET /api/jobs/{jobId}/messages ────────────────────────────────────────
    // Cursor-based pagination: pass beforeId to scroll back in history.

    /// <summary>
    /// Fetch paginated message history for a job (newest first).
    /// Query parameters:
    ///   • beforeId  — cursor: return messages older than this message ID
    ///   • pageSize  — default 30, max 50
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetMessages(
        int jobId,
        [FromQuery] int? beforeId = null,
        [FromQuery] int pageSize = 30)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var result = await _chatService.GetHistoryAsync(jobId, userId, beforeId, pageSize);

        // GetHistoryAsync returns an empty response for non-participants.
        if (result.Messages.Count == 0 && !result.HasMore)
        {
            // Distinguish "not a participant / job not found" from "no messages yet".
            if (!await _chatService.IsParticipantAsync(jobId, userId))
                return NotFound();
        }

        return Ok(result);
    }

    // ── POST /api/jobs/{jobId}/messages ───────────────────────────────────────
    // Optional REST send path (primary path is SignalR hub).

    [HttpPost]
    public async Task<IActionResult> SendMessage(int jobId, [FromBody] SendMessageRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (!await _chatService.IsParticipantAsync(jobId, userId))
            return NotFound();

        var content = request.Content?.Trim() ?? string.Empty;
        if (string.IsNullOrEmpty(content) || content.Length > 2000)
            return BadRequest("Content must be between 1 and 2000 characters.");

        var msg = await _chatService.SaveMessageAsync(jobId, userId, content);
        return Ok(msg);
    }

    private string? GetUserId() => User.FindFirstValue(ClaimTypes.NameIdentifier);
}
