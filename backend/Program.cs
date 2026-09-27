using Amazon.S3;
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
builder.Services.Configure<LocaleOptions>(builder.Configuration.GetSection("Locale"));

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
})
.AddEntityFrameworkStores<FixoDbContext>()
.AddSignInManager<SignInManager<ApplicationUser>>()
.AddDefaultTokenProviders();

var jwtConfig = builder.Configuration.GetSection("Jwt");
var secret = jwtConfig["Secret"] ?? throw new ArgumentNullException("Jwt:Secret");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false; // true in prod
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer           = true,
        ValidateAudience         = true,
        ValidateLifetime         = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer              = jwtConfig["Issuer"],
        ValidAudience            = jwtConfig["Audience"],
        IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret))
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

builder.Services.AddAuthorization();
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
              .AllowAnyMethod();
    });
});

// ── SignalR ──────────────────────────────────────────────────────────────────
builder.Services.AddSignalR();

// ── AWS S3 / MinIO client ────────────────────────────────────────────────────
builder.Services.AddSingleton<IAmazonS3>(_ =>
{
    var s3Config = builder.Configuration.GetSection("S3");
    var serviceUrl = s3Config["ServiceUrl"];

    var config = new AmazonS3Config
    {
        ForcePathStyle = true,
    };

    if (!string.IsNullOrEmpty(serviceUrl))
        config.ServiceURL = serviceUrl;

    return new AmazonS3Client(
        s3Config["AccessKey"] ?? "minioadmin",
        s3Config["SecretKey"] ?? "minioadmin",
        config);
});

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
            Prefix = "fixo:hangfire:",
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
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<IProfileService, ProfileService>();
builder.Services.AddScoped<IJobRepository, JobRepository>();
builder.Services.AddScoped<IJobService, JobService>();
builder.Services.AddScoped<IMatchingService, MatchingService>();
builder.Services.AddScoped<IBlobStorageService, S3BlobStorageService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IJobStatusService, JobStatusService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<IScheduleService, ScheduleService>();
builder.Services.AddScoped<ScheduleReminderService>();
builder.Services.AddScoped<IAdminService, AdminService>();

// Admin seed — creates the default admin user on first startup if it doesn't exist.
builder.Services.AddHostedService<AdminSeedService>();

// Demo seed — creates homeowner@fixo.nz + tradie@fixo.nz with rich dummy data for UI demos.
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

app.UseHttpsRedirection();
app.UseCors("WebClients");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// SignalR hub endpoints.
app.MapHub<JobHub>("/hubs/jobs");
app.MapHub<ChatHub>("/hubs/chat");

// Hangfire dashboard (development only — secure behind auth in production).
if (app.Environment.IsDevelopment())
{
    app.UseHangfireDashboard("/hangfire", new DashboardOptions
    {
        Authorization = [], // Open in dev — require auth in prod
    });
}

app.Run();
