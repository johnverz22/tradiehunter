import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle, Receipt } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Badge } from '../../../components/Badge';
import { Banner } from '../../../components/Banner';
import { EmptyState } from '../../../components/EmptyState';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { Pagination } from '../../../components/Pagination';
import { formatDate } from '../../../utils/format';
import { usePaymentQueue, usePaymentReview } from '../hooks/usePayments';
import { PaymentReviewModal, type PaymentActionKind } from '../components/PaymentReviewModal';
import type { PendingPayment } from '../../../services/adminApi';

const PAGE_SIZE = 20;

interface PendingAction {
  kind: PaymentActionKind;
  payment: PendingPayment;
}

const money = (amount: number, currency: string) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(amount);

const submittedAgo = (iso?: string) => {
  if (!iso) return '—';
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  return hours < 24 ? `${hours}h ago` : `${Math.round(hours / 24)}d ago`;
};

/** P10-27 SLA thresholds — past these a tradie is still waiting on their payout. */
const WARN_MINUTES = 15;
const URGENT_MINUTES = 30;

/**
 * How long this payment has been waiting, preferring the server-computed count
 * (P10-16) so every staff member sees the same number, falling back to the
 * timestamp when an older payload omits it.
 */
function waitingMinutes(payment: PendingPayment): number {
  if (typeof payment.minutesSinceSubmission === 'number') {
    return payment.minutesSinceSubmission;
  }
  if (!payment.submittedAtUtc) return 0;
  return Math.max(0, Math.round((Date.now() - new Date(payment.submittedAtUtc).getTime()) / 60_000));
}

const waitLabel = (minutes: number) =>
  minutes < 60 ? `${minutes}m` : minutes < 1440 ? `${Math.floor(minutes / 60)}h ${minutes % 60}m` : `${Math.floor(minutes / 1440)}d ${Math.floor((minutes % 1440) / 60)}h`;

type WaitBand = 'ok' | 'warn' | 'urgent';

function waitBand(minutes: number): WaitBand {
  if (minutes >= URGENT_MINUTES) return 'urgent';
  if (minutes >= WARN_MINUTES) return 'warn';
  return 'ok';
}

/** Label for the Waiting column: a badge once a payment is past an SLA threshold (text + dot, never colour alone). */
function waitingCell(payment: PendingPayment) {
  const minutes = waitingMinutes(payment);
  const band = waitBand(minutes);

  return {
    minutes,
    band,
    label:
      band === 'ok' ? (
        <span className="muted">{waitLabel(minutes)}</span>
      ) : (
        <Badge tone={band === 'urgent' ? 'danger' : 'warn'} dot>
          {waitLabel(minutes)}
          {band === 'urgent' ? ' · urgent' : ''}
        </Badge>
      ),
  };
}

/**
 * Oldest first — the payment that's been waiting longest is the one a tradie
 * is blocked on. The backend already pages by submission time; sorting the page
 * again keeps the order stable when a row is processed mid-scroll.
 */
const oldestFirst = (items: PendingPayment[]) =>
  [...items].sort((a, b) => waitingMinutes(b) - waitingMinutes(a));

/**
 * The backend answers 400/404/409 with `{ message }` and validation failures with
 * a FluentValidation error array — surface whichever one it sent.
 */
function describeReviewError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;

    if (!error.response) {
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. Check the backend is running and VITE_API_URL is correct.`;
    }

    const data: unknown = error.response.data;
    if (Array.isArray(data)) {
      const firstError = data.find(
        (entry) => typeof entry === 'object' && entry !== null && 'errorMessage' in entry,
      ) as { errorMessage?: unknown } | undefined;
      if (firstError?.errorMessage) return String(firstError.errorMessage);
    }
    if (typeof data === 'object' && data !== null && 'message' in data) {
      return String((data as { message: unknown }).message);
    }

    if (status === 401 || status === 403)
      return 'Your session is not authorized to review payments (401/403). Try logging in again.';
    if (status === 404) return 'That payment no longer exists (404). Reload the queue.';
    if (status === 409)
      return 'That payment is no longer awaiting review (409) — someone else may have actioned it. Reload the queue.';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

/** Confirmation line shown after a successful action — the outcome comes from the backend. */
function actionSummary(kind: PaymentActionKind, payment: PendingPayment): string {
  const amount = money(payment.amount, payment.currency);
  return kind === 'verify'
    ? `Verified ${amount} for "${payment.jobTitle}". The job is now completed and the tradie's payout is queued. The homeowner has been notified.`
    : `Rejected the ${amount} receipt for "${payment.jobTitle}". The homeowner can re-upload before the deadline.`;
}

export const PaymentQueue: React.FC = () => {
  const [page, setPage] = useState(1);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const {
    data,
    isLoading,
    isError,
    error: queryError,
    refetch,
  } = usePaymentQueue({ page, pageSize: PAGE_SIZE });
  const { verify, reject } = usePaymentReview();

  const openAction = (kind: PaymentActionKind, payment: PendingPayment) => {
    setSuccessMessage(null);
    setActionError(null);
    setRejectReason('');
    setPendingAction({ kind, payment });
  };

  const closeAction = () => {
    setPendingAction(null);
    setRejectReason('');
  };

  const handleConfirm = async () => {
    if (!pendingAction) return;
    const { kind, payment } = pendingAction;
    setActionError(null);

    try {
      if (kind === 'verify') {
        await verify.mutateAsync(payment.id);
      } else {
        await reject.mutateAsync({ id: payment.id, reason: { reason: rejectReason.trim() } });
      }
      setSuccessMessage(actionSummary(kind, payment));
      // Reviewing the only row left on a page would leave it empty — step back.
      if (data && data.items.length === 1 && page > 1) setPage(page - 1);
    } catch (err) {
      setActionError(
        `Could not ${kind} ${money(payment.amount, payment.currency)} for "${payment.jobTitle}": ${describeReviewError(err)}`,
      );
    } finally {
      closeAction();
    }
  };

  const busy = verify.isPending || reject.isPending;

  const items = data ? oldestFirst(data.items) : [];
  const urgentCount = items.filter((p) => waitBand(waitingMinutes(p)) === 'urgent').length;

  const columns: ColumnDef<PendingPayment>[] = [
    {
      key: 'job',
      header: 'Job',
      priority: 'primary',
      cell: (payment) => (
        <div>
          <Link to={`/jobs/${payment.jobId}`} className="cell-link">
            {payment.jobTitle}
          </Link>
          {/* v1.7: rows are finished work — the completion date is the key context. */}
          {payment.completionSubmittedAtUtc && (
            <span className="block t-meta muted">
              Work completed on {formatDate(payment.completionSubmittedAtUtc)}
            </span>
          )}
          {payment.reUploadCount > 0 && (
            <span className="block t-meta c-accent">
              {payment.reUploadCount} send-back{payment.reUploadCount === 1 ? '' : 's'}
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (payment) => (
        <div>
          {payment.homeownerName}
          <span className="block t-meta muted">{payment.homeownerEmail}</span>
        </div>
      ),
    },
    {
      key: 'amount',
      header: 'Amount',
      priority: 'secondary',
      cell: (payment) => {
        const currency = payment.currency || 'NZD';
        const hasBreakdown = payment.labourAmount != null || payment.adjustmentsTotal != null;
        if (!hasBreakdown) {
          return <span className="money">{money(payment.amount, currency)}</span>;
        }
        // v1.7 itemised row: labour + approved adjustments = the final total.
        // Show only the parts the payload actually carries — never invented ones.
        const parts: string[] = [];
        if (payment.labourAmount != null) {
          parts.push(`${money(payment.labourAmount, currency)} labour`);
        }
        if (payment.adjustmentsTotal) {
          parts.push(`${money(payment.adjustmentsTotal, currency)} adjustments`);
        }
        if (parts.length === 0) parts.push('no adjustments');
        return (
          <div>
            <span className="money">
              {money(payment.finalAmount ?? payment.amount, currency)}
            </span>
            <span className="block t-meta muted mono">{parts.join(' + ')}</span>
          </div>
        );
      },
    },
    {
      key: 'reference',
      header: 'Reference',
      priority: 'detail',
      cell: (payment) => (
        <span className="mono">{payment.reference}</span>
      ),
    },
    {
      key: 'submitted',
      header: 'Submitted',
      priority: 'detail',
      cell: (payment) => (
        <span className="muted">{submittedAgo(payment.submittedAtUtc)}</span>
      ),
    },
    {
      key: 'waiting',
      header: 'Waiting',
      priority: 'secondary',
      cell: (payment) => {
        const wait = waitingCell(payment);
        return (
          <span title={`${wait.minutes} minutes waiting`}>
            {wait.label}
          </span>
        );
      },
    },
  ];

  const rowActions = (payment: PendingPayment): RowAction[] => [
    {
      label: 'Verify',
      onClick: () => openAction('verify', payment),
      variant: 'primary',
      disabled: busy,
      primary: true,
    },
    {
      label: 'Reject',
      onClick: () => openAction('reject', payment),
      variant: 'danger',
      disabled: busy,
    },
  ];

  return (
    <>
      {/* Header */}
      <PageHeader
        title="Payment queue"
        description="Manual bank transfers for finished work, uploaded by homeowners. Check the amount and reference against the bank statement, then verify to complete the job and queue the tradie's payout, or reject to ask for a corrected receipt."
        actions={
          <Link to="/payments/overdue" className="btn btn-secondary">
            Overdue payments
          </Link>
        }
        meta={
          data && items.length > 0 ? (
            <>
              <Badge>
                {money(
                  items.reduce((sum, p) => sum + p.amount, 0),
                  items[0]?.currency ?? 'NZD',
                )}{' '}
                on this page
              </Badge>
              {urgentCount > 0 && (
                <Badge tone="danger" dot>
                  {urgentCount} waiting over {URGENT_MINUTES}m
                </Badge>
              )}
            </>
          ) : undefined
        }
      />

      {urgentCount > 0 && (
        <Banner variant="warn">
          {urgentCount} payment{urgentCount === 1 ? '' : 's'} on this page{' '}
          {urgentCount === 1 ? 'has' : 'have'} been waiting over {URGENT_MINUTES} minutes — the
          job can't be completed and the tradie can't be paid until{' '}
          {urgentCount === 1 ? 'it is' : 'they are'} checked.
        </Banner>
      )}

      {successMessage && (
        <Banner variant="success">{successMessage}</Banner>
      )}

      {actionError && (
        <Banner variant="error">{actionError}</Banner>
      )}

      {isError && (
        <Banner
          variant="error"
          action={{ label: 'Retry', onClick: () => refetch() }}
        >
          Could not load the payment queue: {describeReviewError(queryError)}
        </Banner>
      )}

      {/* Queue table */}
      <DataTable
        columns={columns}
        rows={items}
        getRowKey={(p) => p.id}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={
          data && data.totalCount > 0 && page > 1 ? (
            <>
              No payments left on this page.{' '}
              <button
                type="button"
                className="cell-link"
                onClick={() => setPage(Math.max(1, data.totalPages))}
              >
                Go to page {Math.max(1, data.totalPages)}
              </button>
            </>
          ) : (
            <EmptyState icon={<CheckCircle size={26} />} title="No payments awaiting review.">
              Check the{' '}
              <Link to="/payouts" className="cell-link">
                payout queue
              </Link>{' '}
              or{' '}
              <Link to="/refunds" className="cell-link">
                refund queue
              </Link>
              .
            </EmptyState>
          )
        }
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="payments"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      <p className="t-meta c-soft row">
        <Receipt size={16} aria-hidden="true" />
        Receipt images are served from a private container; links expire 15 minutes after the queue was
        loaded. Verifying completes the job and queues the tradie's payout — it cannot be undone from
        this screen.
      </p>

      {/* Verify / reject with the receipt on screen */}
      {pendingAction && (
        <PaymentReviewModal
          payment={pendingAction.payment}
          kind={pendingAction.kind}
          reason={rejectReason}
          onReasonChange={setRejectReason}
          confirmLabel={pendingAction.kind === 'verify' ? 'Verify payment' : 'Reject payment'}
          confirmDisabled={pendingAction.kind === 'reject' && rejectReason.trim().length === 0}
          isSubmitting={busy}
          onConfirm={handleConfirm}
          onCancel={closeAction}
        />
      )}
    </>
  );
};
