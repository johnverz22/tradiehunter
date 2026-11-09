using FixoApi.Data;
using FixoApi.DTOs;
using FixoApi.Enums;
using FixoApi.Hubs;
using FixoApi.Jobs;
using FixoApi.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Hangfire;

namespace FixoApi.Services;

public class JobStatusService : IJobStatusService
{
    private readonly FixoDbContext _context;
    private readonly IHubContext<JobHub> _jobHub;
    private readonly PushNotificationService _push;
    private readonly IBackgroundJobClient _hangfire;
    private readonly IOptions<PaymentOptions> _paymentOptions;
    private readonly ILogger<JobStatusService> _logger;
    private readonly IAccountFlagService _accountFlagService;
    private readonly IServiceProvider _serviceProvider;

    public JobStatusService(
        FixoDbContext context,
        IHubContext<JobHub> jobHub,
        PushNotificationService push,
        IBackgroundJobClient hangfire,
        IOptions<PaymentOptions> paymentOptions,
        ILogger<JobStatusService> logger,
        IAccountFlagService accountFlagService,
        IServiceProvider serviceProvider)
    {
        _context = context;
        _jobHub = jobHub;
        _push = push;
        _hangfire = hangfire;
        _paymentOptions = paymentOptions;
        _logger = logger;
        _accountFlagService = accountFlagService;
        _serviceProvider = serviceProvider;
    }

    public async Task<JobDto> TransitionAsync(
        int jobId, JobStatus newStatus, string userId, UserRole actorRole, ReasonCode? reasonCode = null, string? note = null)
    {
        var job = await _context.Jobs
            .Include(j => j.Photos)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        var from = job.Status;

        // Ensure transition is valid based on spec
        ValidateTransition(from, newStatus, actorRole);

        // Apply transition
        job.Status = newStatus;
        job.UpdatedAtUtc = DateTime.UtcNow;

        // Entering AwaitingPayment starts (or restarts) the homeowner's payment
        // clock. Stamp the deadline and arm the expiry job; PaymentExpiryJob
        // re-reads Job.PaymentDueAtUtc rather than trusting its own fire time, so
        // a rejection that pushes this edge re-baselines the window safely (P4-06).
        if (newStatus == JobStatus.AwaitingPayment)
        {
            job.PaymentDueAtUtc = DateTime.UtcNow.AddHours(PaymentWindowHours());
            SchedulePaymentExpiry(jobId, job.PaymentDueAtUtc.Value);
        }
        else if (newStatus is not (JobStatus.PaymentReview or JobStatus.Expired))
        {
            // Booked / Cancelled / Completed — nothing outstanding to expire.
            job.PaymentDueAtUtc = null;
        }

        // P5-03: Schedule pre-job reminder when job becomes Booked
        if (newStatus == JobStatus.Booked)
        {
            SchedulePreJobReminder(jobId, job.ScheduledStartUtc);
        }
        // P5-03: Cancel pre-job reminder when leaving Booked status
        else if (from == JobStatus.Booked && !string.IsNullOrEmpty(job.ReminderJobIds))
        {
            CancelScheduledReminders(job);
        }

        if (newStatus == JobStatus.Cancelled && !string.IsNullOrEmpty(job.ReminderJobIds))
        {
            foreach (var hId in job.ReminderJobIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                try { _hangfire.Delete(hId); }
                catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel reminder"); }
            }
            job.ReminderJobIds = null;
        }

        // Set timestamps
        if (newStatus == JobStatus.InProgress) job.StartedAtUtc = DateTime.UtcNow;
        if (newStatus == JobStatus.AwaitingConfirmation) job.EndedAtUtc = DateTime.UtcNow;
        
        // P5-04: Schedule auto-complete when job enters AwaitingConfirmation
        if (newStatus == JobStatus.AwaitingConfirmation)
        {
            ScheduleAutoComplete(jobId);
        }
        // P5-04: Cancel auto-complete when job leaves AwaitingConfirmation (confirmed or cancelled)
        else if (from == JobStatus.AwaitingConfirmation && !string.IsNullOrEmpty(job.AutoCompleteJobId))
        {
            try { _hangfire.Delete(job.AutoCompleteJobId); }
            catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel auto-complete job"); }
            job.AutoCompleteJobId = null;
        }

        if (newStatus == JobStatus.Cancelled)
        {
            job.CancelledByUserId = userId;
            job.CancelReasonCode = reasonCode;
        }

        var history = new JobStatusHistory
        {
            JobId = jobId,
            FromStatus = from,
            ToStatus = newStatus,
            ChangedByUserId = userId,
            ActorRole = actorRole,
            ReasonCode = reasonCode,
            Reason = note,
            ChangedAtUtc = DateTime.UtcNow
        };
        _context.JobStatusHistory.Add(history);

        await _context.SaveChangesAsync();

        var payload = new JobStatusChangedPayload
        {
            JobId          = jobId,
            Status         = job.Status.ToString(),
            PreviousStatus = from.ToString(),
            ReasonCode     = reasonCode?.ToString(),
            Reason         = note,
        };

        await _jobHub.Clients.Group(JobHub.GroupName(jobId)).SendAsync("JobStatusChanged", payload);

        // P5-05: Send review prompt notification when job is completed
        if (newStatus == JobStatus.Completed)
        {
            await SendReviewPromptAsync(job);
            
            // P10-04: Create payout when job is completed
            using var scope = _serviceProvider.CreateScope();
            var payoutService = scope.ServiceProvider.GetRequiredService<FixoApi.Services.Payout.IPayoutService>();
            try
            {
                await payoutService.CreatePayoutAsync(job);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create payout for completed job {JobId}", jobId);
            }
        }

        // Determine if the actor is a tradie for address privacy (P5-01)
        var isTradieActor = actorRole == UserRole.Tradie;
        return MapToDto(job, isTradieActor);
    }

    private void ValidateTransition(JobStatus from, JobStatus to, UserRole actorRole)
    {
        var valid = (from, to) switch
        {
            (JobStatus.Requested, JobStatus.AwaitingPayment) => actorRole == UserRole.Tradie,
            // System cancels Requested jobs when matching is exhausted (no_tradie_found).
            (JobStatus.Requested, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.AwaitingPayment, JobStatus.PaymentReview) => actorRole == UserRole.Homeowner,
            (JobStatus.AwaitingPayment, JobStatus.Expired) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.PaymentReview, JobStatus.Booked) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.PaymentReview, JobStatus.AwaitingPayment) => actorRole is UserRole.Staff or UserRole.Superadmin,
            // A receipt can sit un-reviewed past the payment window, so PaymentReview
            // expires on the same terms as AwaitingPayment (P4-06).
            (JobStatus.PaymentReview, JobStatus.Expired) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.InProgress) => actorRole == UserRole.Tradie,
            (JobStatus.Booked, JobStatus.Requested) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Booked, JobStatus.Cancelled) => true,
            (JobStatus.InProgress, JobStatus.AwaitingConfirmation) => actorRole == UserRole.Tradie,
            (JobStatus.InProgress, JobStatus.Cancelled) => true,
            (JobStatus.AwaitingConfirmation, JobStatus.Completed) => actorRole is UserRole.Homeowner or UserRole.Staff or UserRole.Superadmin,
            (JobStatus.AwaitingConfirmation, JobStatus.Disputed) => actorRole == UserRole.Homeowner,
            (_, JobStatus.Disputed) => true,
            (JobStatus.Disputed, JobStatus.Completed) => actorRole is UserRole.Staff or UserRole.Superadmin,
            (JobStatus.Disputed, JobStatus.Cancelled) => actorRole is UserRole.Staff or UserRole.Superadmin,
            _ => false
        };

        if (!valid) throw new InvalidOperationException($"Invalid transition from {from} to {to} by {actorRole}.");
    }

    private int PaymentWindowHours() => Math.Max(0, _paymentOptions.Value.WindowHours);

    private void SchedulePaymentExpiry(int jobId, DateTime dueAtUtc)
    {
        try
        {
            _hangfire.Schedule<PaymentExpiryJob>(j => j.ExecuteAsync(jobId), dueAtUtc);
            _logger.LogInformation("Armed payment expiry for job {JobId} at {DueAtUtc}.", jobId, dueAtUtc);
        }
        catch (Exception ex)
        {
            // Never fail the transition because scheduling did not land — an
            // unarmed job simply waits for staff to act on it manually.
            _logger.LogError(ex, "Could not schedule payment expiry for job {JobId}.", jobId);
        }
    }

    /// <summary>
    /// P5-03: Schedule a pre-job reminder 1 hour before the scheduled start time.
    /// </summary>
    private void SchedulePreJobReminder(int jobId, DateTimeOffset scheduledStartUtc)
    {
        if (scheduledStartUtc == default) return;

        var reminderAt = scheduledStartUtc.UtcDateTime.AddHours(-1);
        if (reminderAt <= DateTime.UtcNow) return; // Already past the reminder time

        try
        {
            var jobIdStr = _hangfire.Schedule<PreJobReminderJob>(j => j.ExecuteAsync(jobId), reminderAt);
            _logger.LogInformation("Scheduled pre-job reminder for job {JobId} at {ReminderAtUtc}.", jobId, reminderAt);

            // Store the Hangfire job ID so we can cancel it later
            var job = _context.Jobs.Find(jobId);
            if (job != null)
            {
                var existingIds = job.ReminderJobIds?.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList() ?? new List<string>();
                existingIds.Add(jobIdStr);
                job.ReminderJobIds = string.Join(",", existingIds);
                _context.SaveChanges();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not schedule pre-job reminder for job {JobId}.", jobId);
        }
    }

    /// <summary>
    /// P5-03: Cancel all scheduled reminders for a job.
    /// </summary>
    private void CancelScheduledReminders(Job job)
    {
        if (string.IsNullOrEmpty(job.ReminderJobIds)) return;

        foreach (var hId in job.ReminderJobIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            try { _hangfire.Delete(hId); }
            catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel reminder"); }
        }
        job.ReminderJobIds = null;
    }

    /// <summary>
    /// P5-04: Schedule auto-complete after 48 hours in AwaitingConfirmation.
    /// </summary>
    private void ScheduleAutoComplete(int jobId)
    {
        var dueAt = DateTime.UtcNow.AddHours(48);

        try
        {
            var jobIdStr = _hangfire.Schedule<AutoCompleteJob>(j => j.ExecuteAsync(jobId), dueAt);
            _logger.LogInformation("Scheduled auto-complete for job {JobId} at {DueAtUtc}.", jobId, dueAt);

            var job = _context.Jobs.Find(jobId);
            if (job != null)
            {
                job.AutoCompleteJobId = jobIdStr;
                _context.SaveChanges();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not schedule auto-complete for job {JobId}.", jobId);
        }
    }

    // ── P6-02: Cancellation logic ─────────────────────────────────────────────

    /// <summary>
    /// Cancel a job with full business logic:
    /// - Homeowner cancel: calculates penalty and suggested refund, creates a Pending Refund record.
    /// - Tradie cancel: reverts job to Requested, increments tradie's cancellation counter,
    ///   re-triggers the matching engine (excluding the cancelling tradie).
    /// Sends push notifications to affected parties (P6-06).
    /// </summary>
    public async Task<JobDto> CancelJobAsync(int jobId, string userId, UserRole actorRole, CancelJobRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Photos)
            .Include(j => j.Payment)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new KeyNotFoundException($"Job {jobId} not found.");

        if (actorRole == UserRole.Tradie)
        {
            return await HandleTradieCancellationAsync(job, userId, request);
        }
        else
        {
            return await HandleHomeownerCancellationAsync(job, userId, request);
        }
    }

    /// <summary>
    /// Homeowner cancellation: cancel the job and create a Pending refund.
    /// Penalty is applied if work has started (InProgress / AwaitingConfirmation).
    /// </summary>
    private async Task<JobDto> HandleHomeownerCancellationAsync(Job job, string userId, CancelJobRequest request)
    {
        var from = job.Status;
        var allowedStatuses = new[]
        {
            JobStatus.Requested, JobStatus.AwaitingPayment, JobStatus.PaymentReview,
            JobStatus.Booked, JobStatus.InProgress, JobStatus.AwaitingConfirmation
        };
        if (!allowedStatuses.Contains(from))
            throw new InvalidOperationException($"Cannot cancel a job in status '{from}'.");

        // Calculate penalty and refund amounts.
        var payment = job.Payment;
        var totalPaid = payment?.Amount ?? job.TotalAmount;

        // Determine hours worked (best estimate).
        decimal hoursWorked = 0m;
        decimal hoursWorkedAmount = 0m;
        decimal penalty = 0m;
        decimal suggestedAmount = totalPaid;

        bool workStarted = from is JobStatus.InProgress or JobStatus.AwaitingConfirmation;

        if (workStarted)
        {
            // Estimate hours worked from StartedAtUtc → now.
            if (job.StartedAtUtc.HasValue)
            {
                var elapsed = DateTime.UtcNow - job.StartedAtUtc.Value;
                hoursWorked = Math.Round((decimal)elapsed.TotalHours, 2);
            }
            hoursWorkedAmount = Math.Round(hoursWorked * job.HourlyRate, 2);
            // Penalty = hours worked amount (tradie keeps what they earned) + 10% platform fee.
            penalty = Math.Min(Math.Round(hoursWorkedAmount + totalPaid * 0.10m, 2), totalPaid);
            suggestedAmount = Math.Max(totalPaid - penalty, 0m);
        }
        else if (from == JobStatus.Booked)
        {
            // Cancel before work: flat 10% platform penalty.
            penalty = Math.Round(totalPaid * 0.10m, 2);
            suggestedAmount = Math.Max(totalPaid - penalty, 0m);
        }

        // Transition job to Cancelled.
        job.Status = JobStatus.Cancelled;
        job.CancelledByUserId = userId;
        job.CancelReasonCode = request.ReasonCode;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.PaymentDueAtUtc = null;
        CancelJobReminders(job);

        var history = new JobStatusHistory
        {
            JobId = job.Id,
            FromStatus = from,
            ToStatus = JobStatus.Cancelled,
            ChangedByUserId = userId,
            ActorRole = UserRole.Homeowner,
            ReasonCode = request.ReasonCode,
            Reason = request.Notes,
            ChangedAtUtc = DateTime.UtcNow
        };
        _context.JobStatusHistory.Add(history);

        // Create Pending refund only when payment was collected (totalPaid > 0).
        if (totalPaid > 0)
        {
            var refund = new Refund
            {
                JobId            = job.Id,
                PaymentId        = payment?.Id,
                SuggestedAmount  = suggestedAmount,
                FinalAmount      = suggestedAmount,    // pre-filled; admin adjusts on process
                Penalty          = penalty,
                HoursWorked      = hoursWorked,
                HoursWorkedAmount = hoursWorkedAmount,
                Status           = RefundStatus.Pending,
                CreatedAtUtc     = DateTime.UtcNow,
            };
            _context.Refunds.Add(refund);
            _logger.LogInformation(
                "Created Pending refund for job {JobId}: suggested={Suggested}, penalty={Penalty}.",
                job.Id, suggestedAmount, penalty);
        }

        await _context.SaveChangesAsync();

        // Broadcast status change via SignalR.
        await _jobHub.Clients.Group(JobHub.GroupName(job.Id)).SendAsync("JobStatusChanged", new JobStatusChangedPayload
        {
            JobId          = job.Id,
            Status         = JobStatus.Cancelled.ToString(),
            PreviousStatus = from.ToString(),
            ReasonCode     = request.ReasonCode.ToString(),
            Reason         = request.Notes,
        });

        // P6-06: Notify matched tradie that the homeowner cancelled.
        if (!string.IsNullOrEmpty(job.MatchedTradieId))
        {
            await SendPushToUserAsync(
                job.MatchedTradieId,
                "Job cancelled",
                $"The homeowner cancelled \"{job.Title}\". Your schedule has been freed up.",
                new Dictionary<string, string>
                {
                    ["jobId"] = job.Id.ToString(),
                    ["type"]  = "job_cancelled_by_homeowner"
                });
        }

        return MapToDto(job);
    }

    /// <summary>
    /// Tradie cancellation: revert job to Requested, increment tradie's cancel count,
    /// exclude this tradie and re-dispatch the next offer.
    /// </summary>
    private async Task<JobDto> HandleTradieCancellationAsync(Job job, string userId, CancelJobRequest request)
    {
        var from = job.Status;
        if (from is not (JobStatus.Booked or JobStatus.InProgress or JobStatus.AwaitingConfirmation))
            throw new InvalidOperationException($"Tradie cannot cancel a job in status '{from}'.");

        // Revert to Requested and clear the matched tradie.
        var cancellingTradieId = job.MatchedTradieId ?? userId;
        job.Status = JobStatus.Requested;
        job.MatchedTradieId = null;
        job.CancelledByUserId = userId;
        job.CancelReasonCode = request.ReasonCode;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.StartedAtUtc = null;
        CancelJobReminders(job);

        var history = new JobStatusHistory
        {
            JobId = job.Id,
            FromStatus = from,
            ToStatus = JobStatus.Requested,
            ChangedByUserId = userId,
            ActorRole = UserRole.Tradie,
            ReasonCode = request.ReasonCode,
            Reason = request.Notes,
            ChangedAtUtc = DateTime.UtcNow
        };
        _context.JobStatusHistory.Add(history);

        // Increment tradie's cancellation counter.
        var profile = await _context.TradieProfiles.FirstOrDefaultAsync(p => p.UserId == cancellingTradieId);
        if (profile != null)
        {
            profile.CancellationCount++;
            _logger.LogInformation(
                "Tradie {TradieId} cancellation count incremented to {Count}.",
                cancellingTradieId, profile.CancellationCount);
        }

        await _context.SaveChangesAsync();

        // Broadcast status change via SignalR.
        await _jobHub.Clients.Group(JobHub.GroupName(job.Id)).SendAsync("JobStatusChanged", new JobStatusChangedPayload
        {
            JobId          = job.Id,
            Status         = JobStatus.Requested.ToString(),
            PreviousStatus = from.ToString(),
            ReasonCode     = request.ReasonCode.ToString(),
            Reason         = request.Notes,
        });

        // P6-06: Notify homeowner that the tradie cancelled; job is being reassigned.
        await SendPushToUserAsync(
            job.HomeownerId,
            "Your tradie cancelled",
            $"Don't worry — we're finding you a new tradie for \"{job.Title}\".",
            new Dictionary<string, string>
            {
                ["jobId"] = job.Id.ToString(),
                ["type"]  = "job_cancelled_by_tradie"
            });

        // Re-dispatch the next offer, excluding the cancelling tradie.
        // The tradie is already excluded because they no longer have a Pending offer
        // (their offer is now effectively dead), so SendNextOfferAsync naturally
        // skips them. Kick it off via the Hangfire SendOfferJob.
        try
        {
            _hangfire.Enqueue<SendOfferJob>(j => j.ExecuteAsync(job.Id, userId));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Could not enqueue re-match for job {JobId} after tradie cancellation.", job.Id);
        }

        return MapToDto(job);
    }

    /// <summary>Cancel all scheduled Hangfire reminders for a job (inline helper).</summary>
    private void CancelJobReminders(Job job)
    {
        if (!string.IsNullOrEmpty(job.ReminderJobIds))
        {
            foreach (var hId in job.ReminderJobIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                try { _hangfire.Delete(hId); }
                catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel reminder {HangfireId}.", hId); }
            }
            job.ReminderJobIds = null;
        }

        if (!string.IsNullOrEmpty(job.AutoCompleteJobId))
        {
            try { _hangfire.Delete(job.AutoCompleteJobId); }
            catch (Exception ex) { _logger.LogWarning(ex, "Could not cancel auto-complete job {HangfireId}.", ex.Message); }
            job.AutoCompleteJobId = null;
        }
    }

    // ── P6-06: Push notification helper ──────────────────────────────────────

    /// <summary>Send a push notification to all devices registered to a user.</summary>
    internal async Task SendPushToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null)
    {
        try
        {
            var tokens = await _context.DeviceTokens
                .Where(dt => dt.UserId == userId)
                .Select(dt => dt.Token)
                .ToListAsync();

            foreach (var token in tokens)
            {
                try
                {
                    await _push.SendAsync(token, title, body, data);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "FCM push to token for user {UserId} failed.", userId);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not load device tokens for user {UserId}.", userId);
        }
    }

    private static JobDto MapToDto(Job job, bool isTradie = false)
    {
        // Extract suburb as the first comma-separated segment of the address.
        var suburb = job.Address?.Split(',').FirstOrDefault()?.Trim() ?? "";

        // P5-01: Address privacy - mask exact address for tradies before Booked
        var showFullAddress = !isTradie || job.Status >= JobStatus.Booked;
        var addressToShow = showFullAddress ? job.Address : suburb;
        var latToShow = showFullAddress ? job.Location?.Y : null;
        var lngToShow = showFullAddress ? job.Location?.X : null;

        return new JobDto
        {
            Id               = job.Id,
            HomeownerId      = job.HomeownerId,
            Title            = job.Title,
            Category         = job.Category.ToString(),
            Description      = job.Description,
            Urgency          = job.Urgency.ToString(),
            Status           = job.Status.ToString(),
            Address          = addressToShow,
            Suburb           = suburb,
            Latitude         = latToShow,
            Longitude        = lngToShow,
            CreatedAtUtc     = job.CreatedAtUtc,
            UpdatedAtUtc     = job.UpdatedAtUtc,
            ServiceId        = job.ServiceId,
            ScheduledStartUtc = job.ScheduledStartUtc,
            Hours            = job.Hours,
            HourlyRate       = job.HourlyRate,
            TotalAmount      = job.TotalAmount,
            ReferenceCode    = job.ReferenceCode,
            MatchedTradieId  = job.MatchedTradieId,
            MatchedTradieName = string.IsNullOrWhiteSpace(job.MatchedTradie?.FullName) ? null : job.MatchedTradie.FullName,
            DisputeStatus    = job.DisputeStatus,
            Stage            = 0, // Not used in transition responses
            Photos           = [],
        };
    }

    /// <summary>
    /// P5-05: Send review prompt notification to both parties when job is completed.
    /// </summary>
    private async Task SendReviewPromptAsync(Job job)
    {
        var recipients = new[] { job.HomeownerId, job.MatchedTradieId }
            .Where(id => !string.IsNullOrEmpty(id))
            .Distinct()
            .ToList();

        foreach (var userId in recipients)
        {
            try
            {
                var tokens = await _context.DeviceTokens
                    .Where(dt => dt.UserId == userId)
                    .Select(dt => dt.Token)
                    .ToListAsync();

                var role = userId == job.HomeownerId ? "homeowner" : "tradie";
                var title = "Job completed!";
                var body = $"How did it go with \"{job.Title}\"? Leave a review.";

                foreach (var token in tokens)
                {
                    await _push.SendAsync(token, title, body,
                        new Dictionary<string, string>
                        {
                            ["jobId"] = job.Id.ToString(),
                            ["type"] = "review_prompt",
                            ["role"] = role
                        });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "FCM push to {UserId} about review prompt for job {JobId} failed.", userId, job.Id);
            }
        }

        _logger.LogInformation("Sent review prompts for completed job {JobId}.", job.Id);
    }

    public async Task<JobDto> ReportNoShowAsync(int jobId, string userId, UserRole actorRole, ReportNoShowRequest request)
    {
        var job = await _context.Jobs
            .Include(j => j.Homeowner)
            .Include(j => j.MatchedTradie)
            .FirstOrDefaultAsync(j => j.Id == jobId);
            
        if (job == null) throw new KeyNotFoundException($"Job {jobId} not found.");
        
        if (job.Status != JobStatus.Booked)
            throw new InvalidOperationException("Can only report a no-show for booked jobs.");

        if (actorRole == UserRole.Homeowner)
        {
            if (job.HomeownerId != userId) throw new UnauthorizedAccessException();
            
            // Log flag against tradie
            if (job.MatchedTradieId != null)
                await _accountFlagService.LogFlagAsync(job.MatchedTradieId, AccountFlagType.RepeatNoShow,
                    $"Reported by homeowner for job {jobId}", userId);
            
            // Notify tradie
            if (job.MatchedTradieId != null)
                await SendPushToUserAsync(job.MatchedTradieId, "No-Show Reported",
                    $"The homeowner has reported you as a no-show for job {job.Title}.");
            
            if (request.CancelJob)
            {
                // Full refund if cancelled by homeowner due to tradie no-show
                var payment = await _context.Payments
                    .FirstOrDefaultAsync(p => p.JobId == jobId && p.Status == PaymentStatus.Verified);
                if (payment != null)
                {
                    _context.Refunds.Add(new Refund
                    {
                        JobId = jobId,
                        PaymentId = payment.Id,
                        SuggestedAmount = payment.Amount,
                        Status = RefundStatus.Pending,
                    });
                }
                
                return await TransitionAsync(jobId, JobStatus.Cancelled, userId, actorRole, ReasonCode.tradie_no_show);
            }
            else
            {
                // Revert to Requested to allow reassignment
                job.MatchedTradieId = null;
                return await TransitionAsync(jobId, JobStatus.Requested, userId, actorRole, ReasonCode.tradie_no_show);
            }
        }
        else if (actorRole == UserRole.Tradie)
        {
            if (job.MatchedTradieId != userId) throw new UnauthorizedAccessException();
            
            // Log flag against homeowner
            await _accountFlagService.LogFlagAsync(job.HomeownerId, AccountFlagType.RepeatNoShow,
                $"Reported by tradie for job {jobId}", userId);
            
            // Notify homeowner
            await SendPushToUserAsync(job.HomeownerId, "No-Show Reported",
                $"The tradie has reported you as a no-show for job {job.Title}.");
            
            // Partial refund: tradie gets 50% for time lost; homeowner receives the remainder
            var payment = await _context.Payments
                .FirstOrDefaultAsync(p => p.JobId == jobId && p.Status == PaymentStatus.Verified);
            if (payment != null)
            {
                var refundAmount = Math.Round(payment.Amount * 0.5m, 2);
                _context.Refunds.Add(new Refund
                {
                    JobId = jobId,
                    PaymentId = payment.Id,
                    SuggestedAmount = refundAmount,
                    Status = RefundStatus.Pending,
                });
            }
            
            return await TransitionAsync(jobId, JobStatus.Cancelled, userId, actorRole, ReasonCode.homeowner_no_show);
        }
        else
        {
            throw new UnauthorizedAccessException("Admin cannot report no-show directly.");
        }
    }
}
