using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class Phase0Foundation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ActorRole",
                table: "JobStatusHistory",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ReasonCode",
                table: "JobStatusHistory",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancelReasonCode",
                table: "Jobs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancelledByUserId",
                table: "Jobs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "EndedAtUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "HourlyRateSnapshot",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Hours",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ReferenceCode",
                table: "Jobs",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "StartedAtUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "TotalAmount",
                table: "Jobs",
                type: "numeric(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "AuthProvider",
                table: "AspNetUsers",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "EmailVerified",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "EmailVerifiedAtUtc",
                table: "AspNetUsers",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ActorRole",
                table: "JobStatusHistory");

            migrationBuilder.DropColumn(
                name: "ReasonCode",
                table: "JobStatusHistory");

            migrationBuilder.DropColumn(
                name: "CancelReasonCode",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "CancelledByUserId",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "EndedAtUtc",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "HourlyRateSnapshot",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "Hours",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "ReferenceCode",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "StartedAtUtc",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "TotalAmount",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "AuthProvider",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "EmailVerified",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "EmailVerifiedAtUtc",
                table: "AspNetUsers");
        }
    }
}
