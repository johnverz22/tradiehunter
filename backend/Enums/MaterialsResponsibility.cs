namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-21): who buys materials on a project job. Optional, homeowner
/// chooses at posting; <see cref="Undecided"/> is the default.
/// </summary>
public enum MaterialsResponsibility
{
    Undecided,
    Tradie,
    Homeowner
}
