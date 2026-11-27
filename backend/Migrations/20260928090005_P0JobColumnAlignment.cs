using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FixoApi.Migrations
{
    /// <inheritdoc />
    public partial class P0JobColumnAlignment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Column already exists as ScheduledStart; legacy rename not applicable.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Column already exists as ScheduledStart; legacy rename not applicable.
        }
    }
}
