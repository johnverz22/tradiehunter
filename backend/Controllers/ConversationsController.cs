using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace FixoApi.Controllers;

/// <summary>
/// Inbox overview — one summary per two-party job thread.
/// Participant-gated like the rest of chat: only jobs where the caller is the
/// homeowner or the matched tradie are returned.
/// </summary>
[ApiController]
[Route("api/chat")]
[Authorize]
public class ConversationsController : ControllerBase
{
    private readonly IChatService _chatService;

    public ConversationsController(IChatService chatService)
    {
        _chatService = chatService;
    }

    // ── GET /api/chat/conversations ─────────────────────────────────────────

    /// <summary>
    /// Conversation summaries for the signed-in user, newest activity first.
    /// Each row carries the counterparty name, real preview, localized-time
    /// source timestamp, and a real unread count — no per-job history reads.
    /// </summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations([FromQuery] int limit = 50)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        var result = await _chatService.GetConversationsAsync(userId, limit);
        return Ok(result);
    }
}
