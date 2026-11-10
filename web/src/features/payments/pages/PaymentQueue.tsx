import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle, Receipt, Wallet } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { Pagination } from '../../../components/Pagination';
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

/** P10-27 SLA thresholds — past these a homeowner is still waiting on a booking. */
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

/** Row tint + badge for the Waiting column. */
function waitingCell(payment: PendingPayment) {
  const minutes = waitingMinutes(payment);
  const band = waitBand(minutes);

  const bandClass =
    band === 'urgent'
      ? 'bg-red-50 dark:bg-red-900/25'
      : band === 'warn'
        ? 'bg-amber-50 dark:bg-amber-900/25'
        : undefined;

  return {
    minutes,
    band,
    bandClass,
    label: (
      <span className={band === 'ok' ? 'cell-muted' : 'font-medium'}>
        {waitLabel(minutes)}
        {band === 'urgent' && (
          <span className="pill pill-red ml-2">URGENT</span>
        )}
      </span>
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
    ? `Verified ${amount} for "${payment.jobTitle}". The tradie is now booked and the homeowner has been notified.`
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
          {payment.reUploadCount > 0 && (
            <span className="block text-xs text-[var(--amber-dark)]">
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
          <span className="block text-xs cell-muted">{payment.homeownerEmail}</span>
        </div>
      ),
    },
    {
      key: 'amount',
      header: 'Amount',
      priority: 'secondary',
      cell: (payment) => (
        <span className="font-mono">{money(payment.amount, payment.currency)}</span>
      ),
    },
    {
      key: 'reference',
      header: 'Reference',
      priority: 'detail',
      cell: (payment) => (
        <span className="font-mono">{payment.reference}</span>
      ),
    },
    {
      key: 'submitted',
      header: 'Submitted',
      priority: 'detail',
      cell: (payment) => (
        <span className="cell-muted">{submittedAgo(payment.submittedAtUtc)}</span>
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
    <div className="space-y-5">
      {/* Header */}
      <PageHeader
        title="Payment Queue"
        description="Manual bank transfers uploaded by homeowners. Check the amount and reference against the bank statement, then verify to book the tradie or reject to ask for a corrected receipt."
        meta={
          data && (
            <>
              {data.totalCount > 0 && (
                <div className="stat-pill">
                  <Wallet size={13} aria-hidden="true" />
                  <strong>{data.totalCount.toLocaleString()}</strong> awaiting review
                </div>
              )}
              {items.length > 0 && (
                <div className="stat-pill">
                  <strong>{money(
                    items.reduce((sum, p) => sum + p.amount, 0),
                    items[0]?.currency ?? 'NZD',
                  )}</strong>{' '}
                  on this page
                </div>
              )}
              {urgentCount > 0 && (
                <div className="stat-pill" style={{ color: 'var(--red)' }}>
                  <strong>{urgentCount}</strong> waiting over {URGENT_MINUTES}m
                </div>
              )}
            </>
          )
        }
      />

      {urgentCount > 0 && (
        <Banner variant="warn">
          {urgentCount} payment{urgentCount === 1 ? '' : 's'} on this page{' '}
          {urgentCount === 1 ? 'has' : 'have'} been waiting over {URGENT_MINUTES} minutes — a
          tradie can't be booked until {urgentCount === 1 ? 'it is' : 'they are'} checked.
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
        getRowClassName={(p) => waitingCell(p).bandClass}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={
          data && data.totalCount > 0 && page > 1 ? (
            <>
              No payments left on this page.{' '}
              <button
                className="action-link"
                onClick={() => setPage(Math.max(1, data.totalPages))}
              >
                Go to page {Math.max(1, data.totalPages)}
              </button>
            </>
          ) : (
            <div className="flex flex-col items-center gap-2 py-8">
              <CheckCircle size={28} aria-hidden="true" className="text-[var(--green)]" />
              <span className="font-medium text-[var(--ink)]">
                No payments awaiting review.
              </span>
              <span className="text-xs">
                Check the{' '}
                <Link to="/payouts" className="action-link">payout queue</Link> or{' '}
                <Link to="/refunds" className="action-link">refund queue</Link>.
              </span>
            </div>
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

      <p className="flex items-center gap-1.5 text-xs text-[var(--ink-soft)]">
        <Receipt size={12} aria-hidden="true" />
        Receipt images are served from a private container; links expire 15 minutes after the queue was
        loaded. Verifying books the tradie and cannot be undone from this screen.
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
    </div>
  );
};
