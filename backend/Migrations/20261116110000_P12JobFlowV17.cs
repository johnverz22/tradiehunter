using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class P12JobFlowV17 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── v1.7 P12-01: Job pricing & timing migration ─────────────────────
            // Timing becomes optional, price determination moves to completion.
            // Column renames carry the existing data: Hours → EstimatedHours,
            // TotalAmount → EstimatedTotal. FinalAmount is back-filled to the
            // old total for already-Completed jobs so payouts/history stay intact.

            migrationBuilder.RenameColumn(
                name: "Hours",
                table: "Jobs",
                newName: "EstimatedHours");

            migrationBuilder.RenameColumn(
                name: "TotalAmount",
                table: "Jobs",
                newName: "EstimatedTotal");

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "ScheduledStartUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone");

            migrationBuilder.AlterColumn<decimal>(
                name: "EstimatedTotal",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "decimal(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "EstimatedHours",
                table: "Jobs",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddColumn<string>(
                name: "TimingPreference",
                table: "Jobs",
                type: "text",
                nullable: false,
                defaultValue: "Flexible");

            migrationBuilder.AddColumn<string>(
                name: "JobType",
                table: "Jobs",
                type: "text",
                nullable: false,
                defaultValue: "Hourly");

            migrationBuilder.AddColumn<string>(
                name: "MaterialsBy",
                table: "Jobs",
                type: "text",
                nullable: false,
                defaultValue: "Undecided");

            migrationBuilder.AddColumn<int>(
                name: "FlowVersion",
                table: "Jobs",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<bool>(
                name: "SiteVisitWelcome",
                table: "Jobs",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "WrittenContractConfirmed",
                table: "Jobs",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTimeOffset?>(
                name: "ScheduledEndUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CompletionSubmittedAtUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "FinalHours",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "LabourAmount",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "AdjustmentsTotal",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BudgetMin",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "BudgetMax",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ScopeNotes",
                table: "Jobs",
                type: "character varying(5000)",
                maxLength: 5000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AgreedPricingModel",
                table: "Jobs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "AcceptedQuoteId",
                table: "Jobs",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "FinalAmount",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: true);

            // Back-fill timing semantics: legacy jobs all carried a start date.
            migrationBuilder.Sql(
                "UPDATE \"Jobs\" SET \"TimingPreference\" = 'SpecificDate' " +
                "WHERE \"ScheduledStartUtc\" IS NOT NULL AND \"TimingPreference\" = 'Flexible';");

            migrationBuilder.Sql(
                "UPDATE \"Jobs\" SET \"FinalAmount\" = \"EstimatedTotal\" " +
                "WHERE \"Status\" = 'Completed' AND \"EstimatedTotal\" IS NOT NULL;");

            // ── v1.7 P12-08: JobOffer rate snapshot + message + kind ────────────

            migrationBuilder.AddColumn<decimal>(
                name: "HourlyRateSnapshot",
                table: "JobOffers",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "Message",
                table: "JobOffers",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Kind",
                table: "JobOffers",
                type: "text",
                nullable: false,
                defaultValue: "Instant");

            // ── v1.7 P12-05 / D8: GST registration flag ────────────────────────

            migrationBuilder.AddColumn<bool>(
                name: "IsGstRegistered",
                table: "TradieProfiles",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            // ── v1.7 P12-17: JobPriceAdjustments ────────────────────────────────

            migrationBuilder.CreateTable(
                name: "JobPriceAdjustments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", Npgsql.EntityFrameworkCore.PostgreSQL.Metadata.NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    JobId = table.Column<int>(type: "integer", nullable: false),
                    ProposedByTradieId = table.Column<string>(type: "text", nullable: false),
                    Kind = table.Column<string>(type: "text", nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    EvidenceFileKey = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    Status = table.Column<string>(type: "text", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RespondedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResponseNote = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ExpiryJobId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ReminderJobId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JobPriceAdjustments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_JobPriceAdjustments_Jobs_JobId",
                        column: x => x.JobId,
                        principalTable: "Jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_JobPriceAdjustments_AspNetUsers_ProposedByTradieId",
                        column: x => x.ProposedByTradieId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_JobPriceAdjustments_JobId",
                table: "JobPriceAdjustments",
                column: "JobId");

            migrationBuilder.CreateIndex(
                name: "IX_JobPriceAdjustments_JobId_Status",
                table: "JobPriceAdjustments",
                columns: new[] { "JobId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_JobPriceAdjustments_ProposedByTradieId",
                table: "JobPriceAdjustments",
                column: "ProposedByTradieId");

            migrationBuilder.Sql(
                "ALTER TABLE \"JobPriceAdjustments\" ADD CONSTRAINT \"CK_Adjustment_Amount\" CHECK (\"Amount\" > 0);");

            // ── v1.7 P12-23: Quotes ─────────────────────────────────────────────

            migrationBuilder.CreateTable(
                name: "Quotes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", Npgsql.EntityFrameworkCore.PostgreSQL.Metadata.NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    JobId = table.Column<int>(type: "integer", nullable: false),
                    TradieId = table.Column<string>(type: "text", nullable: false),
                    PricingModel = table.Column<string>(type: "text", nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    MinAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    MaxAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Cap = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Inclusions = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    Exclusions = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    MaterialsIncluded = table.Column<bool>(type: "boolean", nullable: false),
                    GstIncluded = table.Column<bool>(type: "boolean", nullable: false),
                    ProposedStartUtc = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    EstimatedDurationDays = table.Column<int>(type: "integer", nullable: true),
                    ValidUntilUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    OfferId = table.Column<int>(type: "integer", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RespondedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Quotes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Quotes_Jobs_JobId",
                        column: x => x.JobId,
                        principalTable: "Jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Quotes_AspNetUsers_TradieId",
                        column: x => x.TradieId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Quotes_JobOffers_OfferId",
                        column: x => x.OfferId,
                        principalTable: "JobOffers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Quotes_JobId",
                table: "Quotes",
                column: "JobId");

            migrationBuilder.CreateIndex(
                name: "IX_Quotes_JobId_Status",
                table: "Quotes",
                columns: new[] { "JobId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Quotes_OfferId",
                table: "Quotes",
                column: "OfferId");

            migrationBuilder.CreateIndex(
                name: "IX_Quotes_TradieId",
                table: "Quotes",
                column: "TradieId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "ALTER TABLE \"JobPriceAdjustments\" DROP CONSTRAINT IF EXISTS \"CK_Adjustment_Amount\";");

            migrationBuilder.DropTable(
                name: "Quotes");

            migrationBuilder.DropTable(
                name: "JobPriceAdjustments");

            migrationBuilder.DropColumn(
                name: "IsGstRegistered",
                table: "TradieProfiles");

            migrationBuilder.DropColumn(
                name: "HourlyRateSnapshot",
                table: "JobOffers");

            migrationBuilder.DropColumn(
                name: "Message",
                table: "JobOffers");

            migrationBuilder.DropColumn(
                name: "Kind",
                table: "JobOffers");

            migrationBuilder.DropColumn(
                name: "TimingPreference",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "JobType",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "MaterialsBy",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "FlowVersion",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "SiteVisitWelcome",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "WrittenContractConfirmed",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ScheduledEndUtc",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "CompletionSubmittedAtUtc",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "FinalHours",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "LabourAmount",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "AdjustmentsTotal",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "BudgetMin",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "BudgetMax",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ScopeNotes",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "AgreedPricingModel",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "AcceptedQuoteId",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "FinalAmount",
                table: "Jobs");

            migrationBuilder.AlterColumn<int>(
                name: "EstimatedHours",
                table: "Jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "EstimatedTotal",
                table: "Jobs",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m,
                oldClrType: typeof(decimal),
                oldType: "decimal(18,2)",
                oldNullable: true);

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "ScheduledStartUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTimeOffset(new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)),
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.RenameColumn(
                name: "EstimatedHours",
                table: "Jobs",
                newName: "Hours");

            migrationBuilder.RenameColumn(
                name: "EstimatedTotal",
                table: "Jobs",
                newName: "TotalAmount");
        }
    }
}
