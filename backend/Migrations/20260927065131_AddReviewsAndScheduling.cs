using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class AddReviewsAndScheduling : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ReminderJobIds",
                table: "Jobs",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ScheduleProposedByUserId",
                table: "Jobs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ScheduleStatus",
                table: "Jobs",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ScheduledTimeSlot",
                table: "Jobs",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Reviews",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    JobId = table.Column<int>(type: "integer", nullable: false),
                    ReviewerId = table.Column<string>(type: "text", nullable: false),
                    RevieweeId = table.Column<string>(type: "text", nullable: false),
                    Rating = table.Column<int>(type: "integer", nullable: false),
                    Comment = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Reviews", x => x.Id);
                    table.CheckConstraint("CK_Review_Rating", "\"Rating\" BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "FK_Reviews_AspNetUsers_RevieweeId",
                        column: x => x.RevieweeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Reviews_AspNetUsers_ReviewerId",
                        column: x => x.ReviewerId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Reviews_Jobs_JobId",
                        column: x => x.JobId,
                        principalTable: "Jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_JobId_ReviewerId",
                table: "Reviews",
                columns: new[] { "JobId", "ReviewerId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_RevieweeId",
                table: "Reviews",
                column: "RevieweeId");

            migrationBuilder.CreateIndex(
                name: "IX_Reviews_ReviewerId",
                table: "Reviews",
                column: "ReviewerId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Reviews");

            migrationBuilder.DropColumn(
                name: "ReminderJobIds",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ScheduleProposedByUserId",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ScheduleStatus",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ScheduledTimeSlot",
                table: "Jobs");
        }
    }
}
