using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class AddDisputeFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DisputeNote",
                table: "Jobs",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DisputeStatus",
                table: "Jobs",
                type: "character varying(50)",
                maxLength: 50,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "FlagReason",
                table: "Jobs",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "FlaggedAtUtc",
                table: "Jobs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsFlagged",
                table: "Jobs",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DisputeNote",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "DisputeStatus",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "FlagReason",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "FlaggedAtUtc",
                table: "Jobs");

            migrationBuilder.DropColumn(
                name: "IsFlagged",
                table: "Jobs");
        }
    }
}
