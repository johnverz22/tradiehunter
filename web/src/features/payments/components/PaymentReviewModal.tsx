import React from 'react';
import { AlertTriangle, FileText } from 'lucide-react';
import { Badge } from '../../../components/Badge';
import { Banner } from '../../../components/Banner';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { Field } from '../../../components/Field';
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
  const currency = payment.currency || 'NZD';
  const finalAmount = payment.finalAmount ?? payment.amount;
  const overEstimate =
    payment.estimatedTotal != null &&
    payment.estimatedTotal > 0 &&
    finalAmount > payment.estimatedTotal;

  return (
    <ConfirmModal
      open
      size="lg"
      destructive={isReject}
      title={isReject ? 'Reject this payment?' : 'Verify this payment?'}
      message={
        isReject
          ? `Send "${payment.jobTitle}" back to the homeowner. They can upload a corrected receipt before the deadline.`
          : `Confirm you found the ${money(payment.amount, payment.currency)} transfer for "${payment.jobTitle}". Verifying completes the job and queues the tradie's payout.`
      }
      confirmLabel={confirmLabel}
      confirmDisabled={confirmDisabled || isSubmitting}
      onConfirm={onConfirm}
      onCancel={onCancel}
    >
      <div className="stack">
        {/* What was claimed */}
        <dl className="dl">
          <div>
            <dt>Amount</dt>
            <dd>
              <span className="money">{money(payment.amount, payment.currency)}</span>
            </dd>
          </div>
          {payment.labourAmount != null && (
            <div>
              <dt>Labour</dt>
              <dd className="mono">{money(payment.labourAmount, currency)}</dd>
            </div>
          )}
          {payment.adjustmentsTotal != null && (
            <div>
              <dt>Approved adjustments</dt>
              <dd className="mono">{money(payment.adjustmentsTotal, currency)}</dd>
            </div>
          )}
          {payment.estimatedTotal != null && (
            <div>
              <dt>Original estimate</dt>
              <dd className="mono">
                {money(payment.estimatedTotal, currency)}
                {overEstimate && (
                  <Badge tone="warn" dot className="ml-2">
                    Final is higher than the estimate
                  </Badge>
                )}
              </dd>
            </div>
          )}
          {payment.completionSubmittedAtUtc && (
            <div>
              <dt>Work completed</dt>
              <dd>{submitted(payment.completionSubmittedAtUtc)}</dd>
            </div>
          )}
          <div>
            <dt>Reference</dt>
            <dd className="mono">{payment.reference}</dd>
          </div>
          <div>
            <dt>Homeowner</dt>
            <dd>
              {payment.homeownerName}
              <span className="block t-meta muted">{payment.homeownerEmail}</span>
            </dd>
          </div>
          <div>
            <dt>Method</dt>
            <dd>{payment.method ?? '—'}</dd>
          </div>
          <div>
            <dt>Submitted</dt>
            <dd>{submitted(payment.submittedAtUtc)}</dd>
          </div>
        </dl>

        {payment.reUploadCount > 0 && (
          <p className="t-meta c-soft row nowrap">
            <AlertTriangle size={16} className="shrink-0" aria-hidden="true" />
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
              className="btn btn-secondary btn-block"
            >
              <FileText size={20} aria-hidden="true" />
              Open receipt PDF
            </a>
          ) : (
            <div>
              <a href={payment.receiptUrl} target="_blank" rel="noopener noreferrer" className="block">
                <img
                  src={payment.receiptUrl}
                  alt={`Bank transfer receipt for ${payment.reference}`}
                  className="receipt-img"
                />
              </a>
              <p className="t-meta c-soft">Tap the image to open it full size.</p>
            </div>
          )
        ) : (
          <Banner variant="error">
            The receipt file could not be loaded. Verify against the bank statement before approving.
          </Banner>
        )}

        {isReject && (
          <Field
            label="Reason for rejection"
            help={`Required. Shown to the homeowner so they know what to fix. ${reason.length}/${REASON_MAX} characters.`}
          >
            {(a11y) => (
              <textarea
                {...a11y}
                value={reason}
                onChange={(e) => onReasonChange(e.target.value)}
                rows={3}
                maxLength={REASON_MAX}
                autoFocus
                data-autofocus
                placeholder="e.g. The amount on the slip doesn't match — please resend the full transfer."
                className="textarea"
              />
            )}
          </Field>
        )}
      </div>
    </ConfirmModal>
  );
};
