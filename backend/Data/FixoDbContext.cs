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
    public DbSet<JobOffer> JobOffers { get; set; } = null!;
    public DbSet<Payment> Payments { get; set; } = null!;
    public DbSet<Review> Reviews { get; set; } = null!;
    public DbSet<EmailOtp> EmailOtps { get; set; } = null!;
    public DbSet<TradieCredential> TradieCredentials { get; set; } = null!;
    public DbSet<TradieSchedule> TradieSchedules { get; set; } = null!;
    public DbSet<Service> Services { get; set; } = null!;
    public DbSet<TradieRate> TradieRates { get; set; } = null!;
    public DbSet<Refund> Refunds { get; set; } = null!;
    public DbSet<Dispute> Disputes { get; set; } = null!;
    public DbSet<DisputeEvidence> DisputeEvidences { get; set; } = null!;
    public DbSet<AccountFlag> AccountFlags { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<AuditLog> AuditLogs { get; set; } = null!;
    public DbSet<UserBlock> UserBlocks { get; set; } = null!;
    public DbSet<PayoutBatch> PayoutBatches { get; set; } = null!;
    public DbSet<TradiePayout> TradiePayouts { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<RefreshToken>()
            .HasIndex(r => r.TokenHash).IsUnique();

        builder.Entity<ApplicationUser>()
            .Property(u => u.Role)
            .HasConversion<string>();

        builder.Entity<TradieCredential>(entity =>
        {
            entity.Property(c => c.Type).HasConversion<string>();
            entity.Property(c => c.Status).HasConversion<string>();
        });

        builder.Entity<Service>()
            .Property(s => s.Category)
            .HasConversion<string>();

        builder.Entity<TradieRate>()
            .Property(r => r.HourlyRate)
            .HasColumnType("decimal(18,2)");

        builder.Entity<TradieProfile>()
            .HasIndex(t => t.Location)
            .HasMethod("GIST");

        builder.Entity<DeviceTokenEntity>()
            .HasIndex(dt => new { dt.UserId, dt.Token })
            .IsUnique();

        builder.Entity<Job>(entity =>
        {
            entity.Property(j => j.Status).HasConversion<string>();
            entity.Property(j => j.Category).HasConversion<string>();
            entity.Property(j => j.Urgency).HasConversion<string>();
            entity.Property(j => j.ScheduleStatus).HasConversion<string>();
            entity.Property(j => j.ScheduledTimeSlot).HasConversion<string>();
            entity.Property(j => j.CancelReasonCode).HasConversion<string>();
            entity.Property(j => j.HourlyRate).HasColumnType("decimal(18,2)");
            entity.Property(j => j.TotalAmount).HasColumnType("decimal(18,2)");

            entity.HasIndex(j => j.Location).HasMethod("GIST");
            entity.HasIndex(j => j.ReferenceCode).IsUnique();

            entity.HasOne(j => j.Homeowner)
                  .WithMany()
                  .HasForeignKey(j => j.HomeownerId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(j => j.MatchedTradie)
                  .WithMany()
                  .HasForeignKey(j => j.MatchedTradieId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.SetNull);

            entity.HasMany(j => j.Photos)
                  .WithOne(p => p.Job)
                  .HasForeignKey(p => p.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(j => j.Reviews)
                  .WithOne(r => r.Job)
                  .HasForeignKey(r => r.JobId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<ChatMessage>(entity =>
        {
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

        builder.Entity<JobStatusHistory>(entity =>
        {
            entity.Property(h => h.FromStatus).HasConversion<string>();
            entity.Property(h => h.ToStatus).HasConversion<string>();
            entity.Property(h => h.ActorRole).HasConversion<string>();
            entity.Property(h => h.ReasonCode).HasConversion<string>();

            entity.HasOne(h => h.Job)
                  .WithMany(j => j.StatusHistory)
                  .HasForeignKey(h => h.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(h => h.JobId);
        });

        builder.Entity<Review>(entity =>
        {
            entity.Property(r => r.Status).HasConversion<string>();

            entity.HasIndex(r => new { r.JobId, r.ReviewerId })
                  .IsUnique();

            entity.HasOne(r => r.Reviewer)
                  .WithMany()
                  .HasForeignKey(r => r.ReviewerId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(r => r.Reviewee)
                  .WithMany()
                  .HasForeignKey(r => r.RevieweeId)
                  .OnDelete(DeleteBehavior.Restrict);

            entity.ToTable(t =>
                t.HasCheckConstraint("CK_Review_Rating", "\"Rating\" BETWEEN 1 AND 5"));
        });

        builder.Entity<JobOffer>(entity =>
        {
            entity.Property(o => o.Response).HasConversion<string>();
            entity.Property(o => o.Stage).HasConversion<string>();

            entity.HasIndex(o => o.JobId);
            entity.HasIndex(o => new { o.JobId, o.Response });
            // A tradie is offered a given job at most once — the sequential
            // engine skips previously-offered tradies, this index backstops it.
            entity.HasIndex(o => new { o.JobId, o.TradieId }).IsUnique();

            entity.HasOne(o => o.Job)
                  .WithMany(j => j.Offers)
                  .HasForeignKey(o => o.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(o => o.Tradie)
                  .WithMany()
                  .HasForeignKey(o => o.TradieId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Payment>(entity =>
        {
            entity.Property(p => p.Status).HasConversion<string>();
            entity.Property(p => p.Amount).HasColumnType("decimal(18,2)");

            // One manual payment per job; re-uploads mutate the existing row
            // rather than appending a new one.
            entity.HasIndex(p => p.JobId).IsUnique();

            // The transfer reference is what staff match a bank line against, so
            // it has to resolve to exactly one job.
            entity.HasIndex(p => p.ProviderReference).IsUnique();

            // Catches receipt reuse: the same bank-confirmation image cannot back
            // two different payments. NULLs stay exempt until a receipt arrives.
            entity.HasIndex(p => p.ReceiptHash).IsUnique();

            entity.HasIndex(p => new { p.Status, p.SubmittedAtUtc });

            entity.HasOne(p => p.Job)
                  .WithOne(j => j.Payment)
                  .HasForeignKey<Payment>(p => p.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(p => p.VerifiedByUser)
                  .WithMany()
                  .HasForeignKey(p => p.VerifiedBy)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Refund>(entity =>
        {
            entity.Property(r => r.Status).HasConversion<string>();
            entity.Property(r => r.SuggestedAmount).HasColumnType("decimal(18,2)");
            entity.Property(r => r.FinalAmount).HasColumnType("decimal(18,2)");
            entity.Property(r => r.Penalty).HasColumnType("decimal(18,2)");
            entity.Property(r => r.HoursWorked).HasColumnType("decimal(18,2)");
            entity.Property(r => r.HoursWorkedAmount).HasColumnType("decimal(18,2)");

            // One refund per job (1-to-0..1).
            entity.HasIndex(r => r.JobId).IsUnique();
            entity.HasIndex(r => r.Status);

            entity.HasOne(r => r.Job)
                  .WithOne(j => j.Refund)
                  .HasForeignKey<Refund>(r => r.JobId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.Payment)
                  .WithMany()
                  .HasForeignKey(r => r.PaymentId)
                  .IsRequired(false)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<Dispute>(entity =>
        {
            entity.Property(d => d.Status).HasConversion<string>();
            entity.Property(d => d.Outcome).HasConversion<string>();

            // One dispute per job (1-to-0..1 or 1-to-many? Spec says "One dispute per job")
            entity.HasIndex(d => d.JobId).IsUnique();

            entity.HasOne(d => d.Job)
                  .WithMany() // or WithOne, depends on Job model
                  .HasForeignKey(d => d.JobId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<DisputeEvidence>(entity =>
        {
            entity.Property(e => e.Type).HasConversion<string>();

            entity.HasOne(e => e.Dispute)
                  .WithMany(d => d.Evidence)
                  .HasForeignKey(e => e.DisputeId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<AccountFlag>(entity =>
        {
            entity.Property(f => f.Type).HasConversion<string>();
            entity.HasIndex(f => f.UserId);
        });

        // P10-07: Seed initial NZ catalog
        // P10-07: Seed initial NZ catalog
        builder.Entity<Service>().HasData(
            new Service { Id = 1, Name = "Plumbing", Category = TradeCategory.Plumber, RequiresLicence = true, LicenceBoard = "PGDB" },
            new Service { Id = 2, Name = "Gasfitting", Category = TradeCategory.Plumber, RequiresLicence = true, LicenceBoard = "PGDB" },
            new Service { Id = 3, Name = "Electrical Wiring", Category = TradeCategory.Electrician, RequiresLicence = true, LicenceBoard = "EWRB" },
            new Service { Id = 4, Name = "Appliance Repair", Category = TradeCategory.Electrician, RequiresLicence = false },
            new Service { Id = 5, Name = "Carpentry", Category = TradeCategory.Builder, RequiresLicence = true, LicenceBoard = "LBP" },
            new Service { Id = 6, Name = "Decking", Category = TradeCategory.Builder, RequiresLicence = false },
            new Service { Id = 7, Name = "Roofing", Category = TradeCategory.Builder, RequiresLicence = true, LicenceBoard = "LBP" },
            new Service { Id = 8, Name = "Painting", Category = TradeCategory.Painter, RequiresLicence = false },
            new Service { Id = 9, Name = "Lawn Mowing", Category = TradeCategory.Landscaper, RequiresLicence = false },
            new Service { Id = 10, Name = "General Handyman", Category = TradeCategory.General, RequiresLicence = false }
        );

        builder.Entity<AuditLog>(entity =>
        {
            entity.HasIndex(a => a.CreatedAtUtc);
            entity.HasIndex(a => a.UserId);
            entity.HasIndex(a => new { a.Action, a.CreatedAtUtc });
        });

        builder.Entity<UserBlock>(entity =>
        {
            entity.HasIndex(b => new { b.BlockerId, b.BlockedId }).IsUnique();
            entity.HasIndex(b => b.BlockedId);
        });

        builder.Entity<TradiePayout>(entity =>
        {
            entity.Property(p => p.Status).HasConversion<string>();
            entity.Property(p => p.GrossAmount).HasColumnType("decimal(18,2)");
            entity.Property(p => p.CommissionPercent).HasColumnType("decimal(18,2)");
            entity.Property(p => p.CommissionAmount).HasColumnType("decimal(18,2)");
            entity.Property(p => p.NetAmount).HasColumnType("decimal(18,2)");
            
            entity.HasIndex(p => p.JobId).IsUnique();
            entity.HasIndex(p => p.Status);
            
            entity.HasOne(p => p.Job)
                  .WithOne()
                  .HasForeignKey<TradiePayout>(p => p.JobId)
                  .OnDelete(DeleteBehavior.Restrict);
                  
            entity.HasOne(p => p.ProcessedBy)
                  .WithMany()
                  .HasForeignKey(p => p.ProcessedById)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<PayoutBatch>(entity =>
        {
            entity.Property(b => b.Status).HasConversion<string>();
            entity.Property(b => b.TotalAmount).HasColumnType("decimal(18,2)");
            
            entity.HasIndex(b => b.Status);
        });
    }
}
