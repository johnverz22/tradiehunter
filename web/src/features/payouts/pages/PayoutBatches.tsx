import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Layers, Wallet } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { Pagination } from '../../../components/Pagination';
import { BatchStatusBadge } from '../components/PayoutStatusBadge';
import { money, periodLabel } from '../format';
import { usePayoutBatches } from '../hooks/usePayouts';
import type { PayoutBatchSummary } from '../../../services/adminApi';

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
  const navigate = useNavigate();
  const [page, setPage] = useState(1);

  const { data, isLoading, isError, error: queryError, refetch } = usePayoutBatches({
    page,
    pageSize: PAGE_SIZE,
  });

  const columns: ColumnDef<PayoutBatchSummary>[] = [
    {
      key: 'period',
      header: 'Period',
      priority: 'primary',
      cell: (batch) => (
        <div>
          <Link to={`/payouts/batches/${batch.id}`} className="cell-link">
            {periodLabel(batch.periodStartUtc, batch.periodEndUtc)}
          </Link>
          <span className="block text-xs cell-muted font-mono">{batch.id}</span>
        </div>
      ),
    },
    {
      key: 'payouts',
      header: 'Payouts',
      priority: 'secondary',
      cell: (batch) => batch.payoutCount,
    },
    {
      key: 'progress',
      header: 'Progress',
      priority: 'detail',
      cell: (batch) => (
        <div>
          <span className="font-mono">
            {batch.processedCount}/{batch.payoutCount}
          </span>{' '}
          processed
          {batch.payoutCount > 0 && (
            <span className="block text-xs cell-muted">
              {Math.round((batch.processedCount / batch.payoutCount) * 100)}%
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'total',
      header: 'Total (net)',
      priority: 'detail',
      cell: (batch) => <span className="font-mono">{money(batch.totalAmount)}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (batch) => <BatchStatusBadge status={batch.status} />,
    },
    {
      key: 'completed',
      header: 'Completed',
      priority: 'detail',
      cell: (batch) => (
        <span className="cell-muted">
          {batch.completedAtUtc
            ? new Date(batch.completedAtUtc).toLocaleDateString('en-NZ', {
                dateStyle: 'medium',
              })
            : '—'}
        </span>
      ),
    },
  ];

  const rowActions = (batch: PayoutBatchSummary): RowAction[] => [
    {
      label: 'View batch',
      onClick: () => navigate(`/payouts/batches/${batch.id}`),
      variant: 'ghost',
      primary: true,
    },
  ];

  return (
    <div className="space-y-5">
      <PageHeader
        title="Payout Batches"
        description="Weekly batches created by the scheduled payout job. Open a batch to work through its individual tradie payouts."
        actions={
          <Link to="/payouts" className="btn btn-ghost shrink-0">
            <Wallet size={14} aria-hidden="true" />
            Payout queue
          </Link>
        }
      />

      {isError && (
        <Banner
          variant="error"
          action={{ label: 'Retry', onClick: () => refetch() }}
        >
          Could not load payout batches: {describeBatchesError(queryError)}
        </Banner>
      )}

      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(b) => b.id}
        onRowClick={(b) => navigate(`/payouts/batches/${b.id}`)}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={
          data && data.totalCount > 0 && page > 1 ? (
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
          )
        }
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="batches"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      <p className="flex items-center gap-1.5 text-xs text-[var(--ink-soft)]">
        <Layers size={12} aria-hidden="true" />
        A batch closes itself once its last payout is processed — the manual action is there for the
        case where the automatic close didn't land.
      </p>
    </div>
  );
};
