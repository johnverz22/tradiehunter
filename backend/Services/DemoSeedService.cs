using FixoApi.Data;
using FixoApi.Enums;
using FixoApi.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Startup service that seeds two demo users — homeowner@fixo.nz and tradie@fixo.nz —
/// with a rich set of jobs, chat messages, reviews, and status-history rows so every
/// screen in the Flutter app and React admin panel has data to show.
///
/// Safe to run on every deploy: it does nothing when the homeowner account already exists.
/// Toggle via DemoSeed:Enabled in appsettings.json (default true in Development).
/// </summary>
public class DemoSeedService : IHostedService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<DemoSeedService> _logger;

    private static readonly GeometryFactory _gf =
        new GeometryFactory(new PrecisionModel(), 4326);

    // ── Auckland-area coordinates ─────────────────────────────────────────────
    // Point(longitude, latitude) per NTS convention.
    private static Point Auck(double lng, double lat) => _gf.CreatePoint(new Coordinate(lng, lat));

    public DemoSeedService(IServiceProvider services, ILogger<DemoSeedService> logger)
    {
        _services = services;
        _logger   = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        using var scope = _services.CreateScope();
        var cfg = scope.ServiceProvider.GetRequiredService<IConfiguration>();

        // Respect the kill-switch — default to enabled in Development, disabled in Production.
        var enabled = cfg.GetValue<bool?>("DemoSeed:Enabled")
                      ?? (cfg["ASPNETCORE_ENVIRONMENT"] == "Development");

        if (!enabled)
        {
            _logger.LogDebug("DemoSeed: disabled via config, skipping.");
            return;
        }

        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var db          = scope.ServiceProvider.GetRequiredService<FixoDbContext>();

        var homeownerEmail = cfg["DemoSeed:HomeownerEmail"] ?? "homeowner@fixo.nz";
        var tradieEmail    = cfg["DemoSeed:TradieEmail"]    ?? "tradie@fixo.nz";
        var password       = cfg["DemoSeed:Password"]        ?? "Demo1!Fixo";

        // Guard: skip if the homeowner already exists.
        if (await userManager.FindByEmailAsync(homeownerEmail) is not null)
        {
            // P1-03: heal pre-OTP accounts so demo logins keep working.
            await EnsureVerifiedAsync(userManager, homeownerEmail);
            await EnsureVerifiedAsync(userManager, tradieEmail);
            _logger.LogDebug("DemoSeed: {Email} already exists — skipping full seed.", homeownerEmail);
            return;
        }

        _logger.LogInformation("DemoSeed: seeding demo users and rich dummy data …");

        // ── 1. Create homeowner ───────────────────────────────────────────────
        var homeowner = new ApplicationUser
        {
            UserName  = homeownerEmail,
            Email     = homeownerEmail,
            FirstName = "Sarah",
            LastName  = "Mitchell",
            Role      = UserRole.Homeowner,
            IsActive  = true,
            EmailConfirmed = true,
            AuthProvider = "password",
            EmailVerified = true,
            EmailVerifiedAtUtc = DateTime.UtcNow,
            PhoneNumber = "+64 21 555 0101",
        };
        await CreateUserOrThrow(userManager, homeowner, password);

        // ── 2. Create tradie ──────────────────────────────────────────────────
        var tradie = new ApplicationUser
        {
            UserName  = tradieEmail,
            Email     = tradieEmail,
            FirstName = "James",
            LastName  = "Ruru",
            Role      = UserRole.Tradie,
            IsActive  = true,
            EmailConfirmed = true,
            AuthProvider = "password",
            EmailVerified = true,
            EmailVerifiedAtUtc = DateTime.UtcNow,
            PhoneNumber = "+64 27 555 0202",
        };
        await CreateUserOrThrow(userManager, tradie, password);

        // ── 3. Create tradie profile ──────────────────────────────────────────
        var tradieProfile = new TradieProfile
        {
            UserId          = tradie.Id,
            TradeType       = "Plumber",
            BusinessName    = "Ruru Plumbing Ltd",
            IsVerified      = true,
            IsAvailable     = true,
            Location        = Auck(174.7633, -36.8485), // Auckland CBD
            Address         = "12 Queen Street, Auckland CBD, Auckland 1010",
            ServiceRadiusKm = 30m,
        };
        db.TradieProfiles.Add(tradieProfile);
        await db.SaveChangesAsync(cancellationToken);

        // ── 4. Seed jobs ──────────────────────────────────────────────────────
        // We create jobs across the full status lifecycle so every list/detail
        // screen has something to display.
        var now = DateTime.UtcNow;

        var jobs = new List<Job>
        {
            // --- Job 1: Fully complete with chat + both-direction reviews ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Leaking kitchen tap — urgent fix",
                Category        = TradeCategory.Plumber,
                Description     = "The kitchen mixer tap has been dripping for a week. Water is pooling under the sink. Need it fixed ASAP — I think the cartridge needs replacing.",
                Urgency         = JobUrgency.High,
                Status          = JobStatus.Completed,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-30),
                UpdatedAtUtc    = now.AddDays(-22),
                ScheduledStart    = now.AddDays(-24),
                ScheduledTimeSlot   = ScheduleTimeSlot.Morning,
                ScheduleStatus      = ScheduleStatus.Confirmed,
                ScheduleProposedByUserId = tradie.Id,
            },

            // --- Job 2: In progress with active chat ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Hot water cylinder replacement",
                Category        = TradeCategory.Plumber,
                Description     = "Our 25-year-old HWC finally gave up. Looking for a 180L low-pressure unit installed. Already have the new cylinder from Plumbing World.",
                Urgency         = JobUrgency.Medium,
                Status          = JobStatus.InProgress,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-10),
                UpdatedAtUtc    = now.AddDays(-2),
                ScheduledStart    = now.AddDays(1),
                ScheduledTimeSlot   = ScheduleTimeSlot.Afternoon,
                ScheduleStatus      = ScheduleStatus.Confirmed,
                ScheduleProposedByUserId = homeowner.Id,
            },

            // --- Job 3: Confirmed (upcoming) ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Shower drain unblock + re-grout",
                Category        = TradeCategory.Plumber,
                Description     = "Main bathroom shower drains really slowly. Also want the grout around the base re-done — it's going mouldy.",
                Urgency         = JobUrgency.Low,
                Status          = JobStatus.Booked,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-5),
                UpdatedAtUtc    = now.AddDays(-3),
                ScheduledStart    = now.AddDays(7),
                ScheduledTimeSlot   = ScheduleTimeSlot.Morning,
                ScheduleStatus      = ScheduleStatus.Confirmed,
                ScheduleProposedByUserId = tradie.Id,
            },

            // --- Job 4: Matched (tradie selected, waiting for homeowner confirmation) ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Outside tap installation — garden",
                Category        = TradeCategory.Plumber,
                Description     = "Want a tap installed on the exterior wall near the back garden. Existing pipe is accessible from the laundry. Need frost-proof fitting.",
                Urgency         = JobUrgency.Low,
                Status          = JobStatus.AwaitingPayment,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-2),
                UpdatedAtUtc    = now.AddDays(-1),
            },

            // --- Job 5: Requested (in matching queue) ---
            new()
            {
                HomeownerId  = homeowner.Id,
                Title        = "Toilet cistern won't fill — cistern replacement",
                Category     = TradeCategory.Plumber,
                Description  = "Toilet cistern fills very slowly, sometimes not at all. Sounds like the fill valve has failed. Toilet is a Caroma Titan. Would prefer full cistern replacement if needed.",
                Urgency      = JobUrgency.Medium,
                Status       = JobStatus.Requested,
                Address      = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location     = Auck(174.7490, -36.8585),
                CreatedAtUtc = now.AddDays(-1),
                UpdatedAtUtc = now.AddDays(-1),
            },

            // --- Job 6: Complete (older, different trade) ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Full bathroom plumbing re-pipe",
                Category        = TradeCategory.Plumber,
                Description     = "Older home with copper pipes. Two bathrooms need full re-pipe in PEX. Includes hot + cold supply lines, waste connections. Walls are open — just completed a reno.",
                Urgency         = JobUrgency.Medium,
                Status          = JobStatus.Completed,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-60),
                UpdatedAtUtc    = now.AddDays(-50),
                ScheduledStart    = now.AddDays(-55),
                ScheduledTimeSlot   = ScheduleTimeSlot.Morning,
                ScheduleStatus      = ScheduleStatus.Confirmed,
                ScheduleProposedByUserId = tradie.Id,
            },

            // --- Job 7: Cancelled ---
            new()
            {
                HomeownerId  = homeowner.Id,
                Title        = "Emergency burst pipe — laundry",
                Category     = TradeCategory.Plumber,
                Description  = "Pipe behind the laundry wall has burst. Water shut off at the mains. Need emergency repair today.",
                Urgency      = JobUrgency.Emergency,
                Status       = JobStatus.Cancelled,
                Address      = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location     = Auck(174.7490, -36.8585),
                CreatedAtUtc = now.AddDays(-14),
                UpdatedAtUtc = now.AddDays(-14),
            },

            // --- Job 8: Complete (different tradie category displayed in admin) ---
            new()
            {
                HomeownerId     = homeowner.Id,
                MatchedTradieId = tradie.Id,
                Title           = "Gas hob + oven disconnection for kitchen reno",
                Category        = TradeCategory.General,
                Description     = "Getting a new kitchen. Need gas hob and oven disconnected safely before the kitchen installer arrives on Monday. Also need the new hob connected after.",
                Urgency         = JobUrgency.High,
                Status          = JobStatus.Completed,
                Address         = "8 Ponsonby Road, Ponsonby, Auckland 1011",
                Location        = Auck(174.7490, -36.8585),
                CreatedAtUtc    = now.AddDays(-45),
                UpdatedAtUtc    = now.AddDays(-38),
                ScheduledStart    = now.AddDays(-42),
                ScheduledTimeSlot   = ScheduleTimeSlot.Morning,
                ScheduleStatus      = ScheduleStatus.Confirmed,
                ScheduleProposedByUserId = homeowner.Id,
            },
        };

        db.Jobs.AddRange(jobs);
        await db.SaveChangesAsync(cancellationToken);

        // ── 5. Status history ─────────────────────────────────────────────────
        // Simulate realistic transitions for each job.

        var history = new List<JobStatusHistory>();

        void AddHistory(Job job, JobStatus from, JobStatus to, string byId, string? reason = null, int offsetDaysAgo = 0)
        {
            history.Add(new JobStatusHistory
            {
                JobId           = job.Id,
                FromStatus      = from,
                ToStatus        = to,
                ChangedByUserId = byId,
                ChangedAtUtc    = job.CreatedAtUtc.AddHours(offsetDaysAgo),
                Reason          = reason,
            });
        }

        var j1 = jobs[0]; // Complete
        AddHistory(j1, JobStatus.Requested,      JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j1, JobStatus.Requested,  JobStatus.Requested,   homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j1, JobStatus.Requested,   JobStatus.AwaitingPayment,    tradie.Id,    offsetDaysAgo: 2);
        AddHistory(j1, JobStatus.AwaitingPayment,    JobStatus.Booked,  homeowner.Id, offsetDaysAgo: 4);
        AddHistory(j1, JobStatus.Booked,  JobStatus.InProgress, tradie.Id,    offsetDaysAgo: 192); // ~8 days later
        AddHistory(j1, JobStatus.InProgress, JobStatus.Completed,   tradie.Id,    offsetDaysAgo: 200);

        var j2 = jobs[1]; // InProgress
        AddHistory(j2, JobStatus.Requested,     JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j2, JobStatus.Requested, JobStatus.Requested,   homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j2, JobStatus.Requested,  JobStatus.AwaitingPayment,    tradie.Id,    offsetDaysAgo: 3);
        AddHistory(j2, JobStatus.AwaitingPayment,   JobStatus.Booked,  homeowner.Id, offsetDaysAgo: 6);
        AddHistory(j2, JobStatus.Booked, JobStatus.InProgress, tradie.Id,    offsetDaysAgo: 192);

        var j3 = jobs[2]; // Confirmed
        AddHistory(j3, JobStatus.Requested,     JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j3, JobStatus.Requested, JobStatus.Requested,   homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j3, JobStatus.Requested,  JobStatus.AwaitingPayment,    tradie.Id,    offsetDaysAgo: 4);
        AddHistory(j3, JobStatus.AwaitingPayment,   JobStatus.Booked,  homeowner.Id, offsetDaysAgo: 8);

        var j4 = jobs[3]; // Matched
        AddHistory(j4, JobStatus.Requested,     JobStatus.Requested, homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j4, JobStatus.Requested, JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j4, JobStatus.Requested,  JobStatus.AwaitingPayment,   tradie.Id,    offsetDaysAgo: 12);

        var j5 = jobs[4]; // Requested
        AddHistory(j5, JobStatus.Requested,     JobStatus.Requested, homeowner.Id, offsetDaysAgo: 0);

        var j6 = jobs[5]; // Complete (re-pipe)
        AddHistory(j6, JobStatus.Requested,      JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j6, JobStatus.Requested,  JobStatus.Requested,   homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j6, JobStatus.Requested,   JobStatus.AwaitingPayment,    tradie.Id,    offsetDaysAgo: 3);
        AddHistory(j6, JobStatus.AwaitingPayment,    JobStatus.Booked,  homeowner.Id, offsetDaysAgo: 6);
        AddHistory(j6, JobStatus.Booked,  JobStatus.InProgress, tradie.Id,    offsetDaysAgo: 240);
        AddHistory(j6, JobStatus.InProgress, JobStatus.Completed,   tradie.Id,    offsetDaysAgo: 480);

        var j7 = jobs[6]; // Cancelled
        AddHistory(j7, JobStatus.Requested,     JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j7, JobStatus.Requested, JobStatus.Cancelled,  homeowner.Id,
            reason: "Managed to fix it myself with emergency tape — no longer needed.", offsetDaysAgo: 3);

        var j8 = jobs[7]; // Complete (gas)
        AddHistory(j8, JobStatus.Requested,      JobStatus.Requested,  homeowner.Id, offsetDaysAgo: 0);
        AddHistory(j8, JobStatus.Requested,  JobStatus.Requested,   homeowner.Id, offsetDaysAgo: 1);
        AddHistory(j8, JobStatus.Requested,   JobStatus.AwaitingPayment,    tradie.Id,    offsetDaysAgo: 2);
        AddHistory(j8, JobStatus.AwaitingPayment,    JobStatus.Booked,  homeowner.Id, offsetDaysAgo: 6);
        AddHistory(j8, JobStatus.Booked,  JobStatus.InProgress, tradie.Id,    offsetDaysAgo: 168);
        AddHistory(j8, JobStatus.InProgress, JobStatus.Completed,   tradie.Id,    offsetDaysAgo: 180);

        db.JobStatusHistory.AddRange(history);
        await db.SaveChangesAsync(cancellationToken);

        // ── 6. Chat messages ──────────────────────────────────────────────────
        // Two separate conversations with realistic back-and-forth.

        var chat = new List<ChatMessage>();

        void Msg(Job job, ApplicationUser sender, string content, int minutesAfterJobCreated)
        {
            chat.Add(new ChatMessage
            {
                JobId    = job.Id,
                SenderId = sender.Id,
                Content  = content,
                SentAtUtc = job.CreatedAtUtc.AddMinutes(minutesAfterJobCreated),
                ReadAtUtc = job.CreatedAtUtc.AddMinutes(minutesAfterJobCreated + 3),
            });
        }

        // Job 1 — complete, full conversation
        Msg(j1, tradie,     "Hi Sarah, I've reviewed your job — leaking tap is definitely something I can sort today. Do you have a preferred time?", 60);
        Msg(j1, homeowner,  "Hi James! Great, any time before noon works well for me.", 75);
        Msg(j1, tradie,     "Perfect, I can be there at 9am. I'll bring a full set of cartridges so we don't need a second trip.", 80);
        Msg(j1, homeowner,  "Amazing, see you then! The front door code is 1234#.", 90);
        Msg(j1, tradie,     "Got it. On my way now — about 10 minutes away.", 1440 + 520); // next morning
        Msg(j1, homeowner,  "Great, door is unlocked for you.", 1440 + 525);
        Msg(j1, tradie,     "All sorted! Replaced the ceramic cartridge — should be good for years. I've left the old one on the bench so you can see it.", 1440 + 600);
        Msg(j1, homeowner,  "Wow that was fast! The tap feels brand new. Thank you so much James 😊", 1440 + 605);
        Msg(j1, tradie,     "My pleasure! Don't hesitate to reach out if anything else comes up.", 1440 + 610);

        // Job 2 — in progress, ongoing conversation
        Msg(j2, tradie,     "Hi Sarah, I've looked at the job. 180L LP cylinders are the right call. Happy to do the full installation — I can source the anode rod and expansion valve too if needed.", 120);
        Msg(j2, homeowner,  "That would be great, yes. How long do you think the job will take?", 135);
        Msg(j2, tradie,     "About 3–4 hours including draining the old unit, installing the new one, and testing. I'll also check the pressure valve while I'm there.", 145);
        Msg(j2, homeowner,  "Perfect. I'll make sure I'm home that afternoon.", 160);
        Msg(j2, tradie,     "Sounds good. I'll confirm the schedule once I've checked parts availability.", 165);
        Msg(j2, homeowner,  "Has the schedule been confirmed? I haven't seen anything yet.", 2880 + 30);
        Msg(j2, tradie,     "Sorry for the delay — confirmed for tomorrow afternoon. I have all the parts ready.", 2880 + 45);
        Msg(j2, homeowner,  "Perfect, I'll be home from 12:30. Thank you!", 2880 + 60);

        // Job 3 — confirmed, short chat
        Msg(j3, tradie,     "Hi Sarah, I can handle the drain unblock and grout. I'll bring a drain snake and waterproof epoxy grout — much better than the standard stuff for wet areas.", 60);
        Msg(j3, homeowner,  "Brilliant, thank you. Is the morning slot next week still available?", 80);
        Msg(j3, tradie,     "Yes, confirmed for next Saturday morning. I'll be there between 8 and 8:30am.", 95);
        Msg(j3, homeowner,  "Perfect, see you then!", 100);

        // Job 4 — matched, just started
        Msg(j4, tradie,     "Hi Sarah, just reviewed your request. Installing an outside tap is straightforward from the laundry — should take under 2 hours. Want to schedule a time?", 90);
        Msg(j4, homeowner,  "Yes please! Weekends work best for me.", 110);
        Msg(j4, tradie,     "I have availability this Saturday morning or Sunday afternoon. Which works better?", 120);

        chat.AddRange(new ChatMessage[]
        {
            // Job 6 — complete re-pipe, longer conversation
            new() { JobId = j6.Id, SenderId = tradie.Id, Content = "Hi Sarah, re-piping two bathrooms is a big job but with open walls it's actually perfect timing. I'll do a full PEX re-pipe — much more durable than copper for the price.", SentAtUtc = j6.CreatedAtUtc.AddMinutes(120), ReadAtUtc = j6.CreatedAtUtc.AddMinutes(125) },
            new() { JobId = j6.Id, SenderId = homeowner.Id, Content = "Great! The builders have said we have about 10 days before they close the walls. Is that enough time?", SentAtUtc = j6.CreatedAtUtc.AddMinutes(140), ReadAtUtc = j6.CreatedAtUtc.AddMinutes(145) },
            new() { JobId = j6.Id, SenderId = tradie.Id, Content = "Plenty of time. I'll need two full days — one per bathroom. I can start Monday if that works.", SentAtUtc = j6.CreatedAtUtc.AddMinutes(155), ReadAtUtc = j6.CreatedAtUtc.AddMinutes(160) },
            new() { JobId = j6.Id, SenderId = homeowner.Id, Content = "Monday is perfect. I'll let the builders know.", SentAtUtc = j6.CreatedAtUtc.AddMinutes(165), ReadAtUtc = j6.CreatedAtUtc.AddMinutes(170) },
            new() { JobId = j6.Id, SenderId = tradie.Id, Content = "Day 1 done — both hot and cold rough-ins in the main bathroom are complete. Photos taken for the council file.", SentAtUtc = j6.CreatedAtUtc.AddHours(240), ReadAtUtc = j6.CreatedAtUtc.AddHours(241) },
            new() { JobId = j6.Id, SenderId = homeowner.Id, Content = "Looks amazing! The builder is very happy with the work. See you tomorrow!", SentAtUtc = j6.CreatedAtUtc.AddHours(243), ReadAtUtc = j6.CreatedAtUtc.AddHours(244) },
            new() { JobId = j6.Id, SenderId = tradie.Id, Content = "All done! Ensuite re-piped, pressure tested at 700kPa — zero leaks. All connections labelled. Good luck with the rest of the reno!", SentAtUtc = j6.CreatedAtUtc.AddHours(480), ReadAtUtc = j6.CreatedAtUtc.AddHours(481) },
            new() { JobId = j6.Id, SenderId = homeowner.Id, Content = "Absolutely outstanding work James. The builder was seriously impressed. Will 100% recommend you.", SentAtUtc = j6.CreatedAtUtc.AddHours(482), ReadAtUtc = j6.CreatedAtUtc.AddHours(483) },
        });

        db.ChatMessages.AddRange(chat);
        await db.SaveChangesAsync(cancellationToken);

        // ── 7. Reviews ────────────────────────────────────────────────────────
        // Only complete jobs get reviews. Two-direction (homeowner→tradie and tradie→homeowner).

        var reviews = new List<Review>
        {
            // Job 1 — homeowner reviews tradie
            new()
            {
                JobId       = j1.Id,
                ReviewerId  = homeowner.Id,
                RevieweeId  = tradie.Id,
                Rating      = 5,
                Comment     = "James was on time, professional, and fixed the tap in under 30 minutes. Left the kitchen tidy. Highly recommend!",
                CreatedAtUtc = j1.UpdatedAtUtc.AddHours(2),
            },
            // Job 1 — tradie reviews homeowner
            new()
            {
                JobId       = j1.Id,
                ReviewerId  = tradie.Id,
                RevieweeId  = homeowner.Id,
                Rating      = 5,
                Comment     = "Great homeowner — clear brief, easy access, and paid promptly. Would work with again.",
                CreatedAtUtc = j1.UpdatedAtUtc.AddHours(3),
            },

            // Job 6 — homeowner reviews tradie
            new()
            {
                JobId       = j6.Id,
                ReviewerId  = homeowner.Id,
                RevieweeId  = tradie.Id,
                Rating      = 5,
                Comment     = "James did an incredible job on our full re-pipe. Clean work, thorough pressure testing, and he documented everything for the council file. Our builder was blown away. Couldn't ask for better.",
                CreatedAtUtc = j6.UpdatedAtUtc.AddHours(5),
            },
            // Job 6 — tradie reviews homeowner
            new()
            {
                JobId       = j6.Id,
                ReviewerId  = tradie.Id,
                RevieweeId  = homeowner.Id,
                Rating      = 5,
                Comment     = "Sarah was very well organised — walls open as promised, great communication throughout. Made a complex job much easier.",
                CreatedAtUtc = j6.UpdatedAtUtc.AddHours(6),
            },

            // Job 8 — homeowner reviews tradie
            new()
            {
                JobId       = j8.Id,
                ReviewerId  = homeowner.Id,
                RevieweeId  = tradie.Id,
                Rating      = 4,
                Comment     = "James disconnected and reconnected the gas hob and oven perfectly. Turned up on time both days. Only minor thing was the invoice arrived a day late, but the actual work was flawless.",
                CreatedAtUtc = j8.UpdatedAtUtc.AddHours(4),
            },
            // Job 8 — tradie reviews homeowner
            new()
            {
                JobId       = j8.Id,
                ReviewerId  = tradie.Id,
                RevieweeId  = homeowner.Id,
                Rating      = 5,
                Comment     = "Well-prepared site, all appliances accessible. Sarah had all the info I needed and the kitchen reno looked amazing!",
                CreatedAtUtc = j8.UpdatedAtUtc.AddHours(5),
            },
        };

        db.Reviews.AddRange(reviews);
        await db.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "DemoSeed: created homeowner ({H}), tradie ({T}), {J} jobs, {C} chat messages, {R} reviews.",
            homeownerEmail, tradieEmail, jobs.Count, chat.Count, reviews.Count);
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static async Task CreateUserOrThrow(
        UserManager<ApplicationUser> userManager,
        ApplicationUser user,
        string password)
    {
        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
            throw new InvalidOperationException(
                $"DemoSeed: failed to create {user.Email}: " +
                string.Join(", ", result.Errors.Select(e => e.Description)));
    }

    private static async Task EnsureVerifiedAsync(
        UserManager<ApplicationUser> userManager,
        string email)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user is not null && !user.EmailVerified)
        {
            user.EmailVerified = true;
            user.EmailVerifiedAtUtc ??= DateTime.UtcNow;
            await userManager.UpdateAsync(user);
        }
    }
}
