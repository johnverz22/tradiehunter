namespace FixoApi.Enums;

/// <summary>
/// The broadening stage of the matching run at the time an offer was created.
/// Stored as string in the database via EF HasConversion.
/// </summary>
public enum OfferStage
{
    /// <summary>Initial strict-radius matching phase.</summary>
    Auto,

    /// <summary>Expanded-radius phase after the Auto list was exhausted.</summary>
    Broadened
}
