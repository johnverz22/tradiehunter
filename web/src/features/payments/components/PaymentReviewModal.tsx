import React from 'react';
import { AlertTriangle, FileText } from 'lucide-react';
import { ConfirmModal } from '../../../components/ConfirmModal';
import type { PendingPayment } from '../../../services/adminApi';

export type PaymentActionKind = 'verify' | 'reject';

interface PaymentReviewModalProps {
  payment: PendingPayment;
  kind: PaymentActionKind;
  /** Rejection reason owned by the page so it survives re-renders of the modal. */
  reason: string;
  onReasonChange: (reason: string) => void;
  confirmLabel: string;
  confirmDisabled?: boolean;
  isSubmitting: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

/** Mirrors `RejectPaymentRequestValidator.MaxReasonLength`. */
const REASON_MAX = 500;

const money = (amount: number, currency: string) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(amount);

const submitted = (iso?: string) =>
  iso ? new Date(iso).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' }) : '—';

/** Receipts can be a photo (HEIC/JPEG/PNG) or a PDF statement, so both are handled. */
const isPdf = (url: string) => url.split('?')[0].toLowerCase().endsWith('.pdf');

/**
 * Shows staff exactly what the homeowner claims to have paid — amount, reference
 * and the receipt itself — before they verify or reject it. The reference is the
 * thing to check against the bank statement; the amount must match to the cent.
 */
export const PaymentReviewModal: React.FC<PaymentReviewModalProps> = ({
  payment,
  kind,
  reason,
  onReasonChange,
  confirmLabel,
  confirmDisabled = false,
  isSubmitting,
  onConfirm,
  onCancel,
}) => {
  const isReject = kind === 'reject';

  return (
    <ConfirmModal
      open
      size="lg"
      destructive={isReject}
      title={isReject ? 'Reject this payment?' : 'Verify this payment?'}
      message={
        isReject
          ? `Send "${payment.jobTitle}" back to the homeowner. They can upload a corrected receipt before the deadline.`
          : `Confirm you found the ${money(payment.amount, payment.currency)} transfer for "${payment.jobTitle}". This books the tradie.`
      }
      confirmLabel={confirmLabel}
      confirmDisabled={confirmDisabled || isSubmitting}
      onConfirm={onConfirm}
      onCancel={onCancel}
    >
      <div className="mt-4 space-y-4">
        {/* What was claimed */}
        <dl className="rounded-lg border border-[var(--paper-line)] divide-y divide-[var(--paper-line)]">
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Amount</dt>
            <dd className="font-mono text-sm font-semibold text-[var(--ink)]">
              {money(payment.amount, payment.currency)}
            </dd>
          </div>
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Reference</dt>
            <dd className="font-mono text-sm text-[var(--ink)]">{payment.reference}</dd>
          </div>
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Homeowner</dt>
            <dd className="text-sm text-[var(--ink)] text-right">
              {payment.homeownerName}
              <span className="block text-xs cell-muted">{payment.homeownerEmail}</span>
            </dd>
          </div>
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Method</dt>
            <dd className="text-sm text-[var(--ink)]">{payment.method ?? '—'}</dd>
          </div>
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Submitted</dt>
            <dd className="text-sm text-[var(--ink)]">{submitted(payment.submittedAtUtc)}</dd>
          </div>
        </dl>

        {payment.reUploadCount > 0 && (
          <p className="flex items-start gap-2 text-xs text-[var(--ink-soft)]">
            <AlertTriangle size={13} className="mt-0.5 shrink-0" aria-hidden="true" />
            This payment has been sent back {payment.reUploadCount}{' '}
            {payment.reUploadCount === 1 ? 'time' : 'times'} already.
          </p>
        )}

        {/* The receipt itself */}
        {payment.receiptUrl ? (
          isPdf(payment.receiptUrl) ? (
            <a
              href={payment.receiptUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-ghost w-full justify-center"
            >
              <FileText size={14} aria-hidden="true" />
              Open receipt PDF
            </a>
          ) : (
            <div>
              <a href={payment.receiptUrl} target="_blank" rel="noopener noreferrer" className="block">
                <img
                  src={payment.receiptUrl}
                  alt={`Bank transfer receipt for ${payment.reference}`}
                  className="w-full max-h-80 object-contain rounded-lg border border-[var(--paper-line)] bg-[var(--paper)]"
                />
              </a>
              <p className="text-xs text-[var(--ink-soft)] mt-1">
                Tap the image to open it full size.
              </p>
            </div>
          )
        ) : (
          <p className="rounded-lg border border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 px-3 py-2 text-xs text-[var(--red)]">
            The receipt file could not be loaded. Verify against the bank statement before approving.
          </p>
        )}

        {isReject && (
          <div>
            <label htmlFor="payment-reject-reason" className="block text-sm font-medium text-[var(--ink)] mb-1">
              Reason for rejection
            </label>
            <textarea
              id="payment-reject-reason"
              value={reason}
              onChange={(e) => onReasonChange(e.target.value)}
              rows={3}
              maxLength={REASON_MAX}
              autoFocus
              placeholder="e.g. The amount on the slip doesn't match — please resend the full transfer."
              className="field field-multiline w-full resize-none"
            />
            <p className="text-xs text-[var(--ink-soft)] mt-1">
              Required. Shown to the homeowner so they know what to fix.{' '}
              {reason.length}/{REASON_MAX} characters.
            </p>
          </div>
        )}
      </div>
    </ConfirmModal>
  );
};
