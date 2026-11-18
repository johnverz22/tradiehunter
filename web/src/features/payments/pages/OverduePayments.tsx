import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { AlarmClock, CheckCircle } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Badge } from '../../../components/Badge';
import { Banner } from '../../../components/Banner';
import { EmptyState } from '../../../components/EmptyState';
import { DataTable, type ColumnDef } from '../../../components/DataTable';
import { Pagination } from '../../../components/Pagination';
import { formatDate } from '../../../utils/format';
import { useOverduePayments } from '../hooks/usePayments';
import type { OverduePayment } from '../../../services/adminApi';

const PAGE_SIZE = 20;
const DAY_MS = 86_400_000;

const money = (amount: number, currency: string) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(amount);

/**
 * Days past the payment due date. Prefers the server-computed count so every
 * staff member sees the same number, falling back to client maths from
 * `paymentDueAtUtc` when an older payload omits it.
 */
function daysOverdue(row: OverduePayment, now: number = Date.now()): number {
  if (typeof row.daysOverdue === 'number') return Math.max(0, row.daysOverdue);
  if (!row.paymentDueAtUtc) return 0;
  const due = new Date(row.paymentDueAtUtc).getTime();
  if (Number.isNaN(due)) return 0;
  return Math.max(0, Math.floor((now - due) / DAY_MS));
}

/** P12-12 escalation ladder: reminders go out at 24h/72h, then the account is flagged. */
type OverdueBand = 'ok' | 'warn' | 'urgent';

function overdueBand(days: number): OverdueBand {
  if (days >= 3) return 'urgent';
  if (days >= 1) return 'warn';
  return 'ok';
}

/**
 * Most overdue first — the payment the tradie has been waiting on longest is
 * the one to chase. The backend already pages by due date; re-sorting the page
 * keeps the order stable when rows clear mid-scroll.
 */
const mostOverdueFirst = (items: OverduePayment[]) =>
  [...items].sort((a, b) => daysOverdue(b) - daysOverdue(a));

function describeOverdueError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    if (!error.response) {
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. Check the backend is running and VITE_API_URL is correct.`;
    }
    const data: unknown = error.response.data;
    if (typeof data === 'object' && data !== null && 'message' in data) {
      return String((data as { message: unknown }).message);
    }
    return `Request failed with status ${error.response.status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

/**
 * v1.7 (P12-16): jobs sitting in AwaitingPayment past their due date. Work is
 * already done — payment is the last step — so this is a follow-up list, not a
 * cancellation queue: reminders go out (24h/72h), then the homeowner account is
 * flagged. Renders defensively: the feed degrades to an empty state when the
 * endpoint has no rows or hasn't shipped on this backend yet.
 */
export const OverduePayments: React.FC = () => {
  const [page, setPage] = useState(1);

  const {
    data,
    isLoading,
    isError,
    error: queryError,
    refetch,
  } = useOverduePayments({ page, pageSize: PAGE_SIZE });

  const items = data ? mostOverdueFirst(data.items) : [];
  const flaggedCount = items.filter((p) => overdueBand(daysOverdue(p)) === 'urgent').length;
  const endpointMissing =
    isError && axios.isAxiosError(queryError) && queryError.response?.status === 404;

  const columns: ColumnDef<OverduePayment>[] = [
    {
      key: 'job',
      header: 'Job',
      priority: 'primary',
      cell: (row) => (
        <div>
          <Link to={`/jobs/${row.jobId}`} className="cell-link">
            {row.jobTitle ?? `Job #${row.jobId}`}
          </Link>
          {row.completionSubmittedAtUtc && (
            <span className="block t-meta muted">
              Work completed on {formatDate(row.completionSubmittedAtUtc)}
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (row) => (
        <div>
          {row.homeownerName ?? '—'}
          {row.homeownerEmail && (
            <span className="block t-meta muted">{row.homeownerEmail}</span>
          )}
        </div>
      ),
    },
    {
      key: 'amount',
      header: 'Amount',
      priority: 'secondary',
      cell: (row) => (
        <span className="mono">
          {row.amount != null ? money(row.amount, row.currency || 'NZD') : '—'}
        </span>
      ),
    },
    {
      key: 'due',
      header: 'Due',
      priority: 'secondary',
      cell: (row) => {
        const days = daysOverdue(row);
        const band = overdueBand(days);
        return (
          <div>
            <span className={band === 'ok' ? 'muted' : undefined}>
              {formatDate(row.paymentDueAtUtc)}
            </span>
            <span
              className={[
                'block t-meta',
                band === 'urgent' ? 'c-danger' : band === 'warn' ? 'c-accent' : 'muted',
              ].join(' ')}
            >
              {days === 0 ? 'Due today' : `Overdue by ${days} day${days === 1 ? '' : 's'}`}
            </span>
          </div>
        );
      },
    },
  ];

  return (
    <>
      <PageHeader
        title="Overdue payments"
        description="Completed work the homeowner hasn't paid by the due date. Follow up with the homeowner — the job stays unfinished on their side and the tradie's payout waits on this payment."
        actions={
          <Link to="/payments" className="btn btn-secondary">
            Payment queue
          </Link>
        }
        meta={
          data && items.length > 0 ? (
            <>
              <Badge>
                {money(
                  items.reduce((sum, p) => sum + (p.amount != null ? p.amount : 0), 0),
                  items[0]?.currency ?? 'NZD',
                )}{' '}
                outstanding on this page
              </Badge>
              {flaggedCount > 0 && (
                <Badge tone="danger" dot>
                  {flaggedCount} over 3 days
                </Badge>
              )}
            </>
          ) : undefined
        }
      />

      {flaggedCount > 0 && (
        <Banner variant="warn">
          {flaggedCount} payment{flaggedCount === 1 ? ' is' : 's are'} more than 3 days past due.
          Reminders have run their 24h/72h window — chase the homeowner directly; the posting block
          lifts once the payment is verified.
        </Banner>
      )}

      {endpointMissing && (
        <Banner variant="info" action={{ label: 'Retry', onClick: () => refetch() }}>
          The overdue-payments feed isn't available on this backend yet (404). This view fills in
          automatically once GET /api/admin/payments/overdue ships.
        </Banner>
      )}

      {isError && !endpointMissing && (
        <Banner variant="error" action={{ label: 'Retry', onClick: () => refetch() }}>
          Could not load overdue payments: {describeOverdueError(queryError)}
        </Banner>
      )}

      <DataTable
        columns={columns}
        rows={items}
        getRowKey={(row) => row.paymentId ?? row.jobId}
        isLoading={isLoading}
        empty={
          data && data.totalCount > 0 && page > 1 ? (
            <>
              No overdue payments on this page.{' '}
              <button
                type="button"
                className="cell-link"
                onClick={() => setPage(Math.max(1, data.totalPages))}
              >
                Go to page {Math.max(1, data.totalPages)}
              </button>
            </>
          ) : (
            <EmptyState
              icon={<CheckCircle size={26} />}
              title="No overdue payments — every awaiting payment is inside its window."
            >
              Finished work still waiting on a receipt review lives in the{' '}
              <Link to="/payments" className="cell-link">
                payment queue
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
              itemLabel="overdue payments"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      <p className="t-meta c-soft row">
        <AlarmClock size={16} aria-hidden="true" />
        Work is never cancelled for late payment — the overdue flow reminds the homeowner (24h/72h),
        then flags the account so no new jobs can be posted until the payment is verified.
      </p>
    </>
  );
};
