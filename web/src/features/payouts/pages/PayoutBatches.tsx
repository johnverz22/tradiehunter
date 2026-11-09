import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { Layers, Wallet } from 'lucide-react';
import { Pagination } from '../../../components/Pagination';
import { BatchStatusBadge } from '../components/PayoutStatusBadge';
import { money, periodLabel } from '../format';
import { usePayoutBatches } from '../hooks/usePayouts';

const PAGE_SIZE = 20;

function describeBatchesError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    if (!error.response) {
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. Check the backend is running and VITE_API_URL is correct.`;
    }

    const data: unknown = error.response.data;
    if (typeof data === 'object' && data !== null && 'message' in data) {
      return String((data as { message: unknown }).message);
    }

    const status = error.response.status;
    if (status === 401 || status === 403)
      return 'Your session is not authorized to view payouts (401/403). Try logging in again.';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

export const PayoutBatches: React.FC = () => {
  const [page, setPage] = useState(1);

  const { data, isLoading, isError, error: queryError, refetch } = usePayoutBatches({
    page,
    pageSize: PAGE_SIZE,
  });

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Payout Batches</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          Weekly batches created by the scheduled payout job. Open a batch to work through its
          individual tradie payouts.
        </p>
        <div className="flex flex-wrap gap-4 mt-3">
          <Link to="/payouts" className="stat-pill action-link">
            <Wallet size={13} aria-hidden="true" />
            Payout queue
          </Link>
        </div>
      </div>

      {isError && (
        <div className="flex flex-wrap items-center justify-between gap-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          <span>Could not load payout batches: {describeBatchesError(queryError)}</span>
          <button className="btn btn-ghost !py-1 !px-2.5 !text-xs" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      )}

      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Period</th>
                <th className="th">Payouts</th>
                <th className="th">Progress</th>
                <th className="th">Total (net)</th>
                <th className="th">Status</th>
                <th className="th">Completed</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    Loading…
                  </td>
                </tr>
              ) : data && data.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    {data.totalCount > 0 && page > 1 ? (
                      <>
                        No batches left on this page.{' '}
                        <button
                          className="action-link"
                          onClick={() => setPage(Math.max(1, data.totalPages))}
                        >
                          Go to page {Math.max(1, data.totalPages)}
                        </button>
                      </>
                    ) : (
                      'No payout batches yet. The weekly job creates one when there are payouts due.'
                    )}
                  </td>
                </tr>
              ) : (
                data?.items.map((batch) => (
                  <tr key={batch.id}>
                    <td className="td">
                      <Link to={`/payouts/batches/${batch.id}`} className="cell-link">
                        {periodLabel(batch.periodStartUtc, batch.periodEndUtc)}
                      </Link>
                      <span className="block text-xs cell-muted font-mono">{batch.id}</span>
                    </td>
                    <td className="td">{batch.payoutCount}</td>
                    <td className="td">
                      <span className="font-mono">
                        {batch.processedCount}/{batch.payoutCount}
                      </span>{' '}
                      processed
                      {batch.payoutCount > 0 && (
                        <span className="block text-xs cell-muted">
                          {Math.round((batch.processedCount / batch.payoutCount) * 100)}%
                        </span>
                      )}
                    </td>
                    <td className="td font-mono">{money(batch.totalAmount)}</td>
                    <td className="td">
                      <BatchStatusBadge status={batch.status} />
                    </td>
                    <td className="td cell-muted">
                      {batch.completedAtUtc
                        ? new Date(batch.completedAtUtc).toLocaleDateString('en-NZ', {
                            dateStyle: 'medium',
                          })
                        : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {data && (
          <Pagination
            page={data.page}
            totalPages={data.totalPages}
            pageSize={data.pageSize}
            totalCount={data.totalCount}
            itemLabel="batches"
            onPageChange={setPage}
          />
        )}
      </div>

      <p className="flex items-center gap-1.5 text-xs text-[var(--ink-soft)]">
        <Layers size={12} aria-hidden="true" />
        A batch closes itself once its last payout is processed — the manual action is there for the
        case where the automatic close didn't land.
      </p>
    </div>
  );
};
