using System;
using System.Threading;
using System.Threading.Tasks;
using FixoApi.Enums;

namespace FixoApi.Services;

/// <summary>
/// Manual receipt provider (P4-02) — the only implementation at this phase.
///
/// There is no remote payment system, so "creating" a payment just echoes back
/// the reference the homeowner is told to quote on their bank transfer, and
/// "status" is whatever the local <c>Payment</c> row says. Verification is a
/// staff decision in the admin queue, not a callback from a provider.
/// </summary>
public class ManualReceiptProvider : IPaymentProvider
{
    /// <inheritdoc />
    public string Name => "Manual";

    /// <inheritdoc />
    public Task<ProviderPaymentResult> CreatePaymentAsync(
        PaymentRequest request, CancellationToken ct = default)
    {
        // Nothing to do remotely: the instructions the homeowner follows are
        // served straight from the PaymentInstructions config, and the payment
        // becomes real once a receipt is uploaded and a human approves it.
        return Task.FromResult(new ProviderPaymentResult(
            request.Reference, request.Amount, request.Currency, PaymentStatus.Pending.ToString()));
    }

    /// <inheritdoc />
    public Task<ProviderPaymentStatus> GetPaymentStatusAsync(
        string providerReference, PaymentStatus knownStatus, CancellationToken ct = default) =>
        Task.FromResult(new ProviderPaymentStatus(knownStatus.ToString(), null, DateTime.UtcNow));

    /// <inheritdoc />
    /// <remarks>
    /// Manual bank transfers cannot be reversed by the platform — funds have to be
    /// returned by a human through their bank. Refunds land in P6.
    /// </remarks>
    public Task<ProviderRefundResult> ProcessRefundAsync(
        string providerReference, decimal amount, string reason, CancellationToken ct = default) =>
        throw new NotImplementedException(
            "Manual bank-transfer refunds are handled by operations, not the API. See P6-05.");
}
