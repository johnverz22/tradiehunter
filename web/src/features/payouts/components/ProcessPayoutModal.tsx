import React, { useEffect } from 'react';
import { AlertTriangle, Landmark } from 'lucide-react';
import { ConfirmModal } from '../../../components/ConfirmModal';
import type { PayoutQueueItem } from '../../../services/adminApi';

interface ProcessPayoutModalProps {
  payout: PayoutQueueItem;
  /** Transfer reference owned by the page so it survives the modal re-rendering. */
  reference: string;
  onReferenceChange: (value: string) => void;
  isSubmitting: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

const money = (amount: number) =>
  new Intl.NumberFormat('en-NZ', { style: 'currency', currency: 'NZD' }).format(amount);

const row = (label: string, value: React.ReactNode) => (
  <div className="flex items-baseline justify-between gap-3 px-3 py-2">
    <dt className="text-xs text-[var(--ink-soft)]">{label}</dt>
    <dd className="font-mono text-sm text-[var(--ink)]">{value}</dd>
  </div>
);

/**
 * Payouts leave the platform by a manual bank transfer, so staff have to type the
 * reference the bank actually shows before the payout is marked Processed. This
 * modal puts the net amount and the account it goes to on screen at the same
 * time, because those two are what the reference has to be checked against.
 */
export const ProcessPayoutModal: React.FC<ProcessPayoutModalProps> = ({
  payout,
  reference,
  onReferenceChange,
  isSubmitting,
  onConfirm,
  onCancel,
}) => {
  useEffect(() => {
    const input = document.getElementById('payout-transfer-reference');
    input?.focus();
  }, []);

  const trimmed = reference.trim();

  return (
    <ConfirmModal
      open
      size="lg"
      title="Confirm this payout was transferred?"
      message={`Mark the ${money(payout.netAmount)} payout to ${payout.tradieName} as Processed and notify them.`}
      confirmLabel="Mark as processed"
      confirmDisabled={trimmed.length === 0 || isSubmitting}
      onConfirm={onConfirm}
      onCancel={onCancel}
    >
      <div className="mt-4 space-y-4">
        <dl className="rounded-lg border border-[var(--paper-line)] divide-y divide-[var(--paper-line)]">
          {row('Tradie', payout.tradieName)}
          {row('Job', payout.jobReferenceCode || `#${payout.jobId}`)}
          {row('Gross', money(payout.grossAmount))}
          {row(`Platform fee (${payout.commissionPercent}%)`, `−${money(payout.commissionAmount)}`)}
          {row('Net payout', <strong>{money(payout.netAmount)}</strong>)}
          {row(
            'Bank account',
            payout.hasBankDetails
              ? `${payout.bankAccountName ?? '—'} ····${payout.bankAccountLast4 ?? '????'}`
              : 'Not supplied',
          )}
          {row('Payout status', payout.status)}
        </dl>

        {!payout.hasBankDetails && (
          <p className="flex items-start gap-2 text-xs text-[var(--red)]" role="alert">
            <AlertTriangle size={13} className="mt-0.5 shrink-0" aria-hidden="true" />
            This tradie has no bank account on file. Do not mark this payout processed until
            they've supplied details — resolve it with the tradie first.
          </p>
        )}

        <div>
          <label
            htmlFor="payout-transfer-reference"
            className="block text-sm font-medium text-[var(--ink)] mb-1"
          >
            Bank transfer reference
          </label>
          <input
            id="payout-transfer-reference"
            className="field w-full font-mono"
            value={reference}
            onChange={(e) => onReferenceChange(e.target.value)}
            placeholder="e.g. FP-2026-0143"
            maxLength={64}
            aria-invalid={trimmed.length === 0 && reference.length > 0}
          />
          <p className="text-xs text-[var(--ink-soft)] mt-1">
            Required. The reference your bank shows for this transfer — the tradie sees it on
            their payout notification.
          </p>
        </div>

        <p className="flex items-start gap-2 text-xs text-[var(--ink-soft)]">
          <Landmark size={13} className="mt-0.5 shrink-0" aria-hidden="true" />
          The platform does not move money itself. Confirm the transfer in your banking platform first.
        </p>
      </div>
    </ConfirmModal>
  );
};
