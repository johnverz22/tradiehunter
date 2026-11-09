using FixoApi.DTOs;
using FixoApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;

namespace FixoApi.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class DisputesController : ControllerBase
{
    private readonly IDisputeService _disputeService;

    public DisputesController(IDisputeService disputeService)
    {
        _disputeService = disputeService;
    }

    [HttpPost]
    public async Task<IActionResult> OpenDispute([FromBody] CreateDisputeRequest request)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        try
        {
            var dispute = await _disputeService.OpenDisputeAsync(request.JobId, userId, request);
            return CreatedAtAction(nameof(GetDispute), new { id = dispute.Id }, dispute);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            // e.g. "A dispute is already open for this job."
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetDispute(int id)
    {
        try
        {
            var dispute = await _disputeService.GetDisputeAsync(id);
            return Ok(dispute);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetOpenDisputes()
    {
        var disputes = await _disputeService.GetOpenDisputesAsync();
        return Ok(disputes);
    }

    [HttpPost("{id}/evidence/text")]
    public async Task<IActionResult> AddEvidenceText(int id, [FromBody] AddEvidenceTextRequest request)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        try
        {
            var evidence = await _disputeService.AddEvidenceTextAsync(id, userId, request);
            return Ok(evidence);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpPost("{id}/evidence/files")]
    public async Task<IActionResult> AddEvidenceFiles(int id, [FromForm] List<IFormFile> files)
    {
        var userId = User.FindFirstValue("sub");
        if (userId == null) return Unauthorized();

        if (files == null || files.Count == 0) return BadRequest(new { message = "No files uploaded." });

        try
        {
            var evidence = await _disputeService.AddEvidenceFilesAsync(id, userId, files);
            return Ok(evidence);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }
}
