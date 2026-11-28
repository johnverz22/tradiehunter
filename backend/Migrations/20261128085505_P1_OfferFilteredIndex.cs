using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class P1_OfferFilteredIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_JobOffers_JobId_TradieId",
                table: "JobOffers");

            migrationBuilder.CreateIndex(
                name: "IX_JobOffers_JobId_TradieId",
                table: "JobOffers",
                columns: new[] { "JobId", "TradieId" },
                unique: true,
                filter: "\"Response\" NOT IN ('Withdrawn', 'TimedOut', 'Superseded', 'JobClosed')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_JobOffers_JobId_TradieId",
                table: "JobOffers");

            migrationBuilder.CreateIndex(
                name: "IX_JobOffers_JobId_TradieId",
                table: "JobOffers",
                columns: new[] { "JobId", "TradieId" },
                unique: true);
        }
    }
}
