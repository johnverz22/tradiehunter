using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class P9_02_RegistrationToken : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Use IF NOT EXISTS so this migration is safe to apply even when
            // the columns were added manually before the migration was tracked.
            migrationBuilder.Sql(@"
                ALTER TABLE ""AspNetUsers""
                    ADD COLUMN IF NOT EXISTS ""RegistrationToken"" text,
                    ADD COLUMN IF NOT EXISTS ""RegistrationTokenExpiresAtUtc"" timestamp with time zone;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RegistrationToken",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "RegistrationTokenExpiresAtUtc",
                table: "AspNetUsers");
        }
    }
}
