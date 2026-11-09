import re
import sys

filename = sys.argv[1]
with open(filename, 'r') as f:
    content = f.read()

sql = """
            migrationBuilder.Sql("UPDATE \\"Jobs\\" SET \\"Status\\" = 'Requested' WHERE \\"Status\\" IN ('Draft', 'Matching');");
            migrationBuilder.Sql("UPDATE \\"Jobs\\" SET \\"Status\\" = 'AwaitingPayment' WHERE \\"Status\\" = 'Matched';");
            migrationBuilder.Sql("UPDATE \\"Jobs\\" SET \\"Status\\" = 'Booked' WHERE \\"Status\\" = 'Confirmed';");
            migrationBuilder.Sql("UPDATE \\"Jobs\\" SET \\"Status\\" = 'Completed' WHERE \\"Status\\" = 'Complete';");

            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"FromStatus\\" = 'Requested' WHERE \\"FromStatus\\" IN ('Draft', 'Matching');");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"FromStatus\\" = 'AwaitingPayment' WHERE \\"FromStatus\\" = 'Matched';");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"FromStatus\\" = 'Booked' WHERE \\"FromStatus\\" = 'Confirmed';");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"FromStatus\\" = 'Completed' WHERE \\"FromStatus\\" = 'Complete';");

            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"ToStatus\\" = 'Requested' WHERE \\"ToStatus\\" IN ('Draft', 'Matching');");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"ToStatus\\" = 'AwaitingPayment' WHERE \\"ToStatus\\" = 'Matched';");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"ToStatus\\" = 'Booked' WHERE \\"ToStatus\\" = 'Confirmed';");
            migrationBuilder.Sql("UPDATE \\"JobStatusHistory\\" SET \\"ToStatus\\" = 'Completed' WHERE \\"ToStatus\\" = 'Complete';");
"""

# Insert right after protected override void Up(MigrationBuilder migrationBuilder)\n    {
content = content.replace('protected override void Up(MigrationBuilder migrationBuilder)\n    {', 'protected override void Up(MigrationBuilder migrationBuilder)\n    {' + sql)

with open(filename, 'w') as f:
    f.write(content)
