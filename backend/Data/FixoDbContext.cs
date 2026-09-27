using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using FixoApi.Models;
using FixoApi.Enums;

namespace FixoApi.Data;

public class FixoDbContext : IdentityDbContext<ApplicationUser>
{
    public FixoDbContext(DbContextOptions<FixoDbContext> options)
        : base(options)
    {
    }

    public DbSet<TradieProfile> TradieProfiles { get; set; } = null!;
    public DbSet<DeviceTokenEntity> DeviceTokens { get; set; } = null!;
    public DbSet<Job> Jobs { get; set; } = null!;
    public DbSet<JobPhoto> JobPhotos { get; set; } = null!;
    public DbSet<ChatMessage> ChatMessages { get; set; } = null!;
    public DbSet<JobStatusHistory> JobStatusHistory { get; set; } = null!;
    public DbSet<Review> Reviews { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // ── ApplicationUser ────────────────────────────────────────────────────
        builder.Entity<ApplicationUser>()
            .Property(u => u.Role)
            .HasConversion<string>();

        // ── TradieProfile ──────────────────────────────────────────────────────
        builder.Entity<TradieProfile>()
            .HasIndex(t => t.Location)
            .HasMethod("GIST");

        // ── DeviceToken ────────────────────────────────────────────────────────
        builder.Entity<DeviceTokenEntity>()
            .HasIndex(dt => new { dt.UserId, dt.Token })
            .IsUnique();

        // ── Job ────────────────────────────────────────────────────────────────
        builder.Entity<Job>(entity =>
        {
            // Store enums as strings for readability & forward-compatibility.
            entity.Property(j => j.Status)
                  .HasConversion<string>();
            entity.Property(j => j.Category)
                  .HasConversion<string>();
            entity.Property(j => j.Urgency)
                  .HasConversion<string>();
            entity.Property(j => j.ScheduleStatus)
                  .HasConversion<string>();
            entity.Property(j => j.ScheduledTimeSlot)
                  .HasConversion<string>();

            // Spatial GIST index on the job location point.
            entity.HasIndex(j => j.Location)
                  .HasMethod("GIST");

            // Homeowner → many Jobs.
            entity.HasOne(j => j.Homeowner)
                  .WithMany()
                  .HasForeignKey(j => j.HomeownerId)
                  .OnDelete(DeleteBehavior.Restrict);

            // MatchedTradie is nullable.
            entity.HasOne(j => j.MatchedTradie)
                  .WithMany()
                  .HasForeignKey(j => j.MatchedTradieId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.SetNull);

            // Photos child collection.
            entity.HasMany(j => j.Photos)
                  .WithOne(p => p.Job)
                  .HasForeignKey(p => p.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Reviews child collection.
            entity.HasMany(j => j.Reviews)
                  .WithOne(r => r.Job)
                  .HasForeignKey(r => r.JobId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // ── ChatMessage ────────────────────────────────────────────────────────
        builder.Entity<ChatMessage>(entity =>
        {
            // Efficient conversation loading: newest messages first per job.
            entity.HasIndex(m => new { m.JobId, m.SentAtUtc });

            entity.HasOne(m => m.Job)
                  .WithMany(j => j.ChatMessages)
                  .HasForeignKey(m => m.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(m => m.Sender)
                  .WithMany()
                  .HasForeignKey(m => m.SenderId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // ── JobStatusHistory ───────────────────────────────────────────────────
        builder.Entity<JobStatusHistory>(entity =>
        {
            entity.Property(h => h.FromStatus).HasConversion<string>();
            entity.Property(h => h.ToStatus).HasConversion<string>();

            entity.HasOne(h => h.Job)
                  .WithMany(j => j.StatusHistory)
                  .HasForeignKey(h => h.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Index for fast per-job history retrieval.
            entity.HasIndex(h => h.JobId);
        });

        // ── Review ────────────────────────────────────────────────────────────
        builder.Entity<Review>(entity =>
        {
            // One review per reviewer per job.
            entity.HasIndex(r => new { r.JobId, r.ReviewerId })
                  .IsUnique();

            // Reviewer FK — restrict delete (don't cascade-delete reviews if user is deleted).
            entity.HasOne(r => r.Reviewer)
                  .WithMany()
                  .HasForeignKey(r => r.ReviewerId)
                  .OnDelete(DeleteBehavior.Restrict);

            // Reviewee FK.
            entity.HasOne(r => r.Reviewee)
                  .WithMany()
                  .HasForeignKey(r => r.RevieweeId)
                  .OnDelete(DeleteBehavior.Restrict);

            // CHECK constraint: rating must be 1–5.
            entity.ToTable(t =>
                t.HasCheckConstraint("CK_Review_Rating", "\"Rating\" BETWEEN 1 AND 5"));
        });
    }
}
