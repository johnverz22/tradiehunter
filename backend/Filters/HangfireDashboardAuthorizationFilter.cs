using Hangfire.Dashboard;

namespace FixoApi.Filters;

/// <summary>
/// P9-09: Restricts the Hangfire dashboard to authenticated Superadmin users
/// in all environments. An unauthenticated or non-Superadmin request gets
/// a 401 / redirect rather than the dashboard HTML.
/// </summary>
public class HangfireDashboardAuthorizationFilter : IDashboardAuthorizationFilter
{
    public bool Authorize(DashboardContext context)
    {
        var httpContext = context.GetHttpContext();
        return httpContext.User.Identity?.IsAuthenticated == true
            && httpContext.User.IsInRole("Superadmin");
    }
}
