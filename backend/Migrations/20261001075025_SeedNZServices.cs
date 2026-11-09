using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class SeedNZServices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Services",
                columns: new[] { "Id", "Category", "LicenceBoard", "Name", "RequiresLicence" },
                values: new object[,]
                {
                    { 1, "Plumber", "PGDB", "Plumbing", true },
                    { 2, "Plumber", "PGDB", "Gasfitting", true },
                    { 3, "Electrician", "EWRB", "Electrical Wiring", true },
                    { 4, "Electrician", null, "Appliance Repair", false },
                    { 5, "Builder", "LBP", "Carpentry", true },
                    { 6, "Builder", null, "Decking", false },
                    { 7, "Builder", "LBP", "Roofing", true },
                    { 8, "Painter", null, "Painting", false },
                    { 9, "Landscaper", null, "Lawn Mowing", false },
                    { 10, "General", null, "General Handyman", false }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 1);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 2);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 4);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "Services",
                keyColumn: "Id",
                keyValue: 10);
        }
    }
}
