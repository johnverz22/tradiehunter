using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class P2JobRequestRevision : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Preserve P0's partially populated values while bringing the names
            // and types into the P2 API contract.
            migrationBuilder.Sql("""
                UPDATE "Jobs"
                SET "HourlyRateSnapshot" = COALESCE("HourlyRateSnapshot", 0),
                    "TotalAmount" = COALESCE("TotalAmount", 0),
                    "Hours" = GREATEST(1, CEIL(COALESCE("Hours", 1))),
                    "ScheduledStart" = COALESCE("ScheduledStart", "CreatedAtUtc");
                """);


            migrationBuilder.RenameColumn(
                name: "HourlyRateSnapshot",
                table: "Jobs",
                newName: "HourlyRate");

            migrationBuilder.RenameColumn(
                name: "ScheduledStart",
                table: "Jobs",
                newName: "ScheduledStartUtc");

            migrationBuilder.AlterColumn<decimal>(
                name: "TotalAmount",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: false,
                defaultValue: 0m,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "Hours",
                table: "Jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "HourlyRate",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)",
                oldNullable: true);

            migrationBuilder.AlterColumn<DateTimeOffset>(
                name: "ScheduledStartUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ServiceId",
                table: "Jobs",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Jobs_ReferenceCode",
                table: "Jobs",
                column: "ReferenceCode",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Jobs_ReferenceCode",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ServiceId",
                table: "Jobs");

            migrationBuilder.AlterColumn<decimal>(
                name: "TotalAmount",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<decimal>(
                name: "Hours",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<decimal>(
                name: "HourlyRate",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<DateTime>(
                name: "ScheduledStartUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTimeOffset),
                oldType: "timestamp with time zone");

            migrationBuilder.RenameColumn(
                name: "HourlyRate",
                table: "Jobs",
                newName: "HourlyRateSnapshot");

            migrationBuilder.RenameColumn(
                name: "ScheduledStartUtc",
                table: "Jobs",
                newName: "ScheduledStart");
        }
    }
}
