using FixoApi.Enums;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace FixoApi.Services;

/// <summary>
/// Payment provider seam (P4-02). TradieHunter has no gateway at this phase — the only
/// implementation is <see cref="ManualReceiptProvider"/>, where the "provider" is
/// a human at the admin queue — but the interface is the extension point a real
/// PSP (Stripe, BNZ, Windcave) drops in later without touching
/// <see cref="IPaymentService"/> or the job state machine
/// (see .agent/rules/backend.md, "Modular Boundaries").
/// </summary>
public interface IPaymentProvider
{
    /// <summary>Identifier persisted on <c>Payment.Provider</c>.</summary>
    string Name { get; }

    /// <summary>
    /// Open a payment for <paramref name="request"/> and return the reference the
    /// payer must quote, plus the amount actually payable.
    /// </summary>
    Task<ProviderPaymentResult> CreatePaymentAsync(PaymentRequest request, CancellationToken ct = default);

    /// <summary>
    /// Poll the provider for the authoritative status. Manual providers have no
    /// remote state to poll and report what they were told.
    /// </summary>
    Task<ProviderPaymentStatus> GetPaymentStatusAsync(
        string providerReference, PaymentStatus knownStatus, CancellationToken ct = default);

    /// <summary>
    /// Return funds. Not available on manual bank transfers — the money has to be
    /// reversed by a human. Implemented in P6 (cancellations and refunds).
    /// </summary>
    Task<ProviderRefundResult> ProcessRefundAsync(
        string providerReference, decimal amount, string reason, CancellationToken ct = default);
}

/// <summary>What <see cref="IPaymentProvider.CreatePaymentAsync"/> needs to open a payment.</summary>
public class PaymentRequest
{
    public int JobId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "NZD";
    public string PayerUserId { get; set; } = string.Empty;

    /// <summary>Suggested transfer reference; providers may honour or replace it.</summary>
    public string Reference { get; set; } = string.Empty;
}

public record ProviderPaymentResult(
    string ProviderReference,
    decimal Amount,
    string Currency,
    string Status);

public record ProviderPaymentStatus(string Status, decimal? AmountSettled, DateTime? LastUpdatedUtc);

public record ProviderRefundResult(bool Succeeded, string? Error);
