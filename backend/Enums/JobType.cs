namespace FixoApi.Enums;

/// <summary>
/// v1.7 (P12-21): one Job table, one lifecycle. <see cref="Hourly"/> is the
/// classic quick job (rate shown up front, total confirmed at completion).
/// <see cref="Project"/> lets tradies send quotes (up to 3 concurrent requests).
/// </summary>
public enum JobType
{
    Hourly,
    Project
}
