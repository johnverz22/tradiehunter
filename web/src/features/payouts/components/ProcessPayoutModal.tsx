import React from 'react';
import { Landmark } from 'lucide-react';
import { Banner } from '../../../components/Banner';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Field } from '../../../components/Field';
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
  <div>
    <dt>{label}</dt>
    <dd className="mono">{value}</dd>
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
      <div className="stack">
        <dl className="dl">
          {row('Tradie', payout.tradieName)}
          {row('Job', payout.jobReferenceCode || `#${payout.jobId}`)}
          {row('Gross', money(payout.grossAmount))}
          {row(`Platform fee (${payout.commissionPercent}%)`, `−${money(payout.commissionAmount)}`)}
          <div className="total">
            <dt>Net payout</dt>
            <dd className="mono">{money(payout.netAmount)}</dd>
          </div>
          {row(
            'Bank account',
            payout.hasBankDetails
              ? `${payout.bankAccountName ?? '—'} ····${payout.bankAccountLast4 ?? '????'}`
              : 'Not supplied',
          )}
          {row('Payout status', payout.status)}
        </dl>

        {!payout.hasBankDetails && (
          <Banner variant="error">
            This tradie has no bank account on file. Do not mark this payout processed until
            they've supplied details — resolve it with the tradie first.
          </Banner>
        )}

        <Field
          label="Bank transfer reference"
          error={trimmed.length === 0 && reference.length > 0 ? 'Enter the transfer reference.' : undefined}
          help="Required. The reference your bank shows for this transfer — the tradie sees it on their payout notification."
        >
          {(a11y) => (
            <input
              {...a11y}
              className="field mono"
              value={reference}
              onChange={(e) => onReferenceChange(e.target.value)}
              placeholder="e.g. FP-2026-0143"
              maxLength={64}
              autoFocus
              data-autofocus
            />
          )}
        </Field>

        <p className="t-meta c-soft row nowrap">
          <Landmark size={16} className="shrink-0" aria-hidden="true" />
          The platform does not move money itself. Confirm the transfer in your banking platform first.
        </p>
      </div>
    </ConfirmModal>
  );
};
