using System.Threading.Tasks;
using FixoApi.Enums;

namespace FixoApi.Services;

public interface IAccountFlagService
{
    Task LogFlagAsync(string userId, AccountFlagType flagType, string? note, string? createdBy = null);
}
