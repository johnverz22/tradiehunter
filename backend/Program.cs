using FixoApi.Data;
using FixoApi.Hubs;
using FixoApi.Models;
using FixoApi.Services;
using FixoApi.Validators;
using FluentValidation;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Hangfire;
using Hangfire.Redis.StackExchange;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// ── Firebase Admin SDK ───────────────────────────────────────────────────────
FirebaseApp.Create(new AppOptions
{
    Credential = GoogleCredential.GetApplicationDefault(),
    ProjectId  = builder.Configuration["Firebase:ProjectId"]
                 ?? Environment.GetEnvironmentVariable("FIREBASE_PROJECT_ID")
                 ?? throw new InvalidOperationException(
                     "Firebase ProjectId is not configured. " +
                     "Set Firebase:ProjectId in appsettings.json or FIREBASE_PROJECT_ID env var.")
});

// ── ASP.NET Core services ────────────────────────────────────────────────────

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.Configure<FixoApi.Options.AddressResolutionOptions>(builder.Configuration.GetSection("AddressResolution"));
builder.Services.AddHttpClient<LinzAddressResolver>(client =>
{
    client.Timeout = TimeSpan.FromSeconds(10);
    client.MaxResponseContentBufferSize = 1024 * 1024;
}).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false })
  .RemoveAllLoggers();
builder.Services.AddScoped<IAddressResolver>(services =>
    builder.Configuration.GetValue<string>("AddressResolution:Provider", "Linz") switch
    {
        "Linz" => services.GetRequiredService<LinzAddressResolver>(),
        _ => throw new InvalidOperationException("Unsupported address resolution provider.")
    });
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("address-search", context =>
        System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
            context.User.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
            _ => new System.Threading.RateLimiting.FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});
builder.Services.Configure<LocaleOptions>(builder.Configuration.GetSection("Locale"));
builder.Services.Configure<PaymentOptions>(builder.Configuration.GetSection("PaymentInstructions"));

builder.Services.AddDbContext<FixoDbContext>(options =>
{
    var connString = builder.Configuration.GetConnectionString("DefaultConnection");
    options.UseNpgsql(connString, o => o.UseNetTopologySuite());
});

builder.Services.AddIdentity<ApplicationUser, IdentityRole>(options =>
{
    options.SignIn.RequireConfirmedAccount = false;
    options.User.RequireUniqueEmail = true;
    options.Password.RequireDigit = true;
    options.Password.RequiredLength = 8;
    options.Password.RequireNonAlphanumeric = true;
    options.Password.RequireUppercase = true;
    options.Password.RequireLowercase = true;
    options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.AllowedForNewUsers = true;
})
.AddEntityFrameworkStores<FixoDbContext>()
.AddSignInManager<SignInManager<ApplicationUser>>()
.AddDefaultTokenProviders();

var jwtConfig = builder.Configuration.GetSection("Jwt");
var secret = jwtConfig["Secret"];
if (string.IsNullOrEmpty(secret))
    throw new ArgumentNullException("Jwt:Secret", "JWT Secret must be provided in configuration or environment.");

builder.Services.AddAuthentication(options =>
{
    // The default scheme is still JWT Bearer so mobile continues to work
    // without specifying a scheme in the [Authorize] attribute.
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
})
.AddCookie("AdminCookie", options =>
{
    // Over plain http (local dev / Playwright e2e) browsers refuse to store a
    // `Secure` + `__Host-` prefixed cookie at all, so in Development we fall
    // back to a plain name and SameAsRequest. Production keeps the hardened
    // cookie. If you rename, update the QA docs that mention __Host-th-admin.
    var isDev = builder.Environment.IsDevelopment();
    options.Cookie.Name        = isDev ? "th-admin" : "__Host-th-admin";
    options.Cookie.HttpOnly    = true;
    options.Cookie.SecurePolicy = isDev ? CookieSecurePolicy.SameAsRequest
                                        : CookieSecurePolicy.Always;
    options.Cookie.SameSite    = SameSiteMode.Strict;
    options.ExpireTimeSpan     = TimeSpan.FromHours(8);
    options.SlidingExpiration  = true;
    options.Events.OnRedirectToLogin = ctx =>
    {
        ctx.Response.StatusCode = 401;
        return Task.CompletedTask;
    };
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    options.SaveToken = true;
    // P9-15: prevent middleware from remapping standard JWT claim names
    // (e.g. "sub" → nameidentifier) so claims are read exactly as issued.
    options.MapInboundClaims = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer           = true,
        ValidateAudience         = true,
        ValidateLifetime         = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer              = jwtConfig["Issuer"],
        ValidAudience            = jwtConfig["Audience"],
        IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
        // RFC 8725: explicitly require a signature — rejects alg:none regardless
        // of library default behaviour (P9-13).
        RequireSignedTokens      = true,
        // RFC 8725: require exp claim — tokens without exp would be treated as eternal.
        RequireExpirationTime    = true,
        // RFC 8725 / OWASP: reduce clock-skew from the 5-minute default to 30 s.
        // Limits replay of just-expired tokens. OTP codes have a separate
        // 10-minute lifetime and are unaffected by JWT clock skew.
        ClockSkew                = TimeSpan.FromSeconds(30),
        // P9-13: pin the signing algorithm — rejects alg:none and prevents
        // HMAC↔RSA confusion attacks. Migration path: when a dedicated auth server
        // is adopted, switch IssuerSigningKey to a JsonWebKeySet from the issuer's
        // jwks_uri and update ValidAlgorithms to ["RS256"] or ["ES256"].
        // Note: Microsoft.IdentityModel.Tokens does NOT honour jwk/jku/x5u header
        // injection by default — verify this remains true on each library upgrade.
        ValidAlgorithms          = [SecurityAlgorithms.HmacSha256],
        // P9-15: because MapInboundClaims=false the middleware no longer maps
        // the short "role" claim to ClaimTypes.Role. Explicitly declare the
        // role claim type so RequireRole() and User.IsInRole() still work.
        RoleClaimType            = "role",
        NameClaimType            = "unique_name",
    };

    // Allow SignalR to receive the JWT from the query string (WebSocket doesn't support headers).
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                context.Token = accessToken;
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization(options =>
{
    // P0-02: Staff covers support/admin users; Superadmin additionally
    // manages staff invites and platform settings.
    options.AddPolicy("RequireStaffRole", policy => policy
        .AddAuthenticationSchemes("AdminCookie", JwtBearerDefaults.AuthenticationScheme)
        .RequireRole("Staff", "Superadmin"));

    options.AddPolicy("RequireSuperadminRole", policy => policy
        .AddAuthenticationSchemes("AdminCookie", JwtBearerDefaults.AuthenticationScheme)
        .RequireRole("Superadmin"));
});
builder.Services.AddControllers();

// ── CORS (admin web + local dev origins) ─────────────────────────────────────
// Browser clients (Vite dev on :5173, docker web on :3000) call the API
// cross-origin, so preflight must succeed. Origins are configurable via
// Cors:AllowedOrigins (e.g. Cors__AllowedOrigins__0 env var).
var corsOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:3000", "http://localhost:5173"];
builder.Services.AddCors(options =>
{
    options.AddPolicy("WebClients", policy =>
    {
        policy.WithOrigins(corsOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials(); // required for cookies cross-origin in dev
    });
});

// ── SignalR ──────────────────────────────────────────────────────────────────
builder.Services.AddSignalR();
// Hubs resolve user identity from the JWT "sub" claim — required because
// MapInboundClaims=false leaves ClaimTypes.NameIdentifier unpopulated.
builder.Services.AddSingleton<Microsoft.AspNetCore.SignalR.IUserIdProvider,
    FixoApi.Hubs.SubClaimUserIdProvider>();

// ── Azure Blob / Azurite ─────────────────────────────────────────────────────
// The service builds its own BlobServiceClient from the AzureBlob config
// section (Azurite locally, Azure Blob Storage in production) and creates
// containers lazily on first use — no init container needed. Registered
// below with the other scoped services.

// ── Redis (SignalR backplane + Hangfire storage) ─────────────────────────────
var redisConn = builder.Configuration.GetConnectionString("Redis");
IConnectionMultiplexer? redis = null;
if (!string.IsNullOrEmpty(redisConn))
{
    redis = ConnectionMultiplexer.Connect(redisConn);
    builder.Services.AddSingleton<IConnectionMultiplexer>(redis);
}

// ── Hangfire (M4-09) ─────────────────────────────────────────────────────────
if (redis != null)
{
    builder.Services.AddHangfire(config =>
    {
        config.UseRedisStorage(redis, new RedisStorageOptions
        {
            Prefix = "th:hangfire:",
        });
    });
    builder.Services.AddHangfireServer();
}
else
{
    // Fallback: Hangfire still registered but without persistent storage.
    // Redis is always expected in production (docker-compose.yml).
    builder.Services.AddHangfire(config =>
        config.UseSimpleAssemblyNameTypeSerializer()
              .UseRecommendedSerializerSettings());
    builder.Services.AddHangfireServer();
}

// ── Scoped / singleton services ──────────────────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<IAuditLogService, AuditLogService>();
builder.Services.AddScoped<IProfileService, ProfileService>();
builder.Services.AddScoped<IJobRepository, JobRepository>();
builder.Services.AddScoped<IJobService, JobService>();
builder.Services.AddScoped<IMatchingService, MatchingService>();
builder.Services.AddScoped<IBlobStorageService, AzureBlobStorageService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IJobStatusService, JobStatusService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<IScheduleService, ScheduleService>();
builder.Services.AddScoped<ScheduleReminderService>();
builder.Services.AddScoped<IAdminService, AdminService>();
builder.Services.AddScoped<IDisputeService, DisputeService>();
builder.Services.AddScoped<IAccountFlagService, AccountFlagService>();

builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// ── Payments (P4-02, P4-03, P10-03) ──────────────────────────────────────────
// The provider is the seam a real gateway drops into later; swapping
// ManualReceiptProvider for a PSP implementation is the only change needed.
builder.Services.AddScoped<IPaymentProvider, ManualReceiptProvider>();
builder.Services.AddScoped<IPaymentService, PaymentService>();

builder.Services.Configure<FixoApi.Options.PayoutOptions>(builder.Configuration.GetSection("PayoutOptions"));
builder.Services.Configure<FixoApi.Options.BrandOptions>(builder.Configuration.GetSection("Brand"));
builder.Services.AddScoped<FixoApi.Services.Payout.IPayoutService, FixoApi.Services.Payout.PayoutService>();
builder.Services.AddScoped<FixoApi.Services.Payout.TradieEarningsService>();

// P3-04: Hangfire offer-timeout job. Registered as scoped so Hangfire's
// DI activator can resolve FixoDbContext + IMatchingService per invocation.
builder.Services.AddScoped<FixoApi.Jobs.OfferTimeoutJob>();

// P3-03: starts the sequential matching run in its own scope (a scoped
// DbContext cannot outlive the request that would have triggered it inline).
builder.Services.AddScoped<FixoApi.Jobs.SendOfferJob>();

// P4-06: expires a job whose manual payment was never verified. Armed by
// IJobStatusService whenever a job enters AwaitingPayment.
builder.Services.AddScoped<FixoApi.Jobs.PaymentExpiryJob>();

builder.Services.AddScoped<FixoApi.Jobs.PayoutBatchJob>();
builder.Services.AddScoped<FixoApi.Jobs.RevealReviewsJob>();
builder.Services.AddScoped<FixoApi.Jobs.PaymentSlaJob>();

// Admin seed — creates the default admin user on first startup if it doesn't exist.
builder.Services.AddHostedService<AdminSeedService>();

// P8-05: expires Requested jobs left untouched past the threshold.
builder.Services.AddHostedService<ExpirationWorker>();

// Demo seed — creates homeowner@tradiehunter.nz + tradie@tradiehunter.nz with rich dummy data for UI demos.
// Controlled by DemoSeed:Enabled in appsettings.json (auto-enabled in Development).
builder.Services.AddHostedService<DemoSeedService>();

// PushNotificationService is a thin wrapper around FirebaseMessaging.DefaultInstance —
// safe as singleton because FirebaseMessaging is thread-safe.
builder.Services.AddSingleton<PushNotificationService>();

builder.Services.AddValidatorsFromAssemblyContaining<RegisterRequestValidator>();

// ── Middleware pipeline ──────────────────────────────────────────────────────
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.Use(async (context, next) =>
{
    context.Response.Headers.Append(
        "Content-Security-Policy",
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; connect-src 'self' wss:;"
    );
    await next();
});

app.UseHttpsRedirection();
app.UseCors("WebClients");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();

// SignalR hub endpoints.
app.MapHub<JobHub>("/hubs/jobs");
app.MapHub<ChatHub>("/hubs/chat");

// Hangfire dashboard — requires Superadmin auth in all environments (P9-09).
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = [new FixoApi.Filters.HangfireDashboardAuthorizationFilter()]
});

// Configure recurring payout batch job
var payoutOptions = app.Configuration.GetSection("PayoutOptions").Get<FixoApi.Options.PayoutOptions>() ?? new FixoApi.Options.PayoutOptions();
RecurringJob.AddOrUpdate<FixoApi.Jobs.PayoutBatchJob>(
    "payout-batch-job",
    j => j.ExecuteAsync(),
    payoutOptions.PayoutBatchCron);

// Configure recurring review reveal job
RecurringJob.AddOrUpdate<FixoApi.Jobs.RevealReviewsJob>(
    "reveal-reviews-job",
    j => j.ExecuteAsync(),
    "*/5 * * * *"); // Every 5 minutes

// Configure recurring payment SLA job
RecurringJob.AddOrUpdate<FixoApi.Jobs.PaymentSlaJob>(
    "payment-sla-job",
    j => j.ExecuteAsync(),
    "*/15 * * * *"); // Every 15 minutes

app.Run();
