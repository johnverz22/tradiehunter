import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CircleAlert, Layers, Wallet } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { Pagination } from '../../../components/Pagination';
import { ProcessPayoutModal } from '../components/ProcessPayoutModal';
import { PayoutStatusBadge } from '../components/PayoutStatusBadge';
import { createdAgo, money } from '../format';
import { usePayoutQueue, useProcessPayout } from '../hooks/usePayouts';
import type { PayoutQueueItem } from '../../../services/adminApi';

const PAGE_SIZE = 20;

/** Matches the backend's `ProcessPayoutRequest.TransferReference`. */
const REFERENCE_MAX = 64;

function describePayoutError(error: unknown): string {
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
      return 'Your session is not authorized to process payouts (401/403). Try logging in again.';
    if (status === 404) return 'That payout no longer exists (404). Reload the queue.';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

export const PayoutQueue: React.FC = () => {
  const [page, setPage] = useState(1);
  const [pending, setPending] = useState<PayoutQueueItem | null>(null);
  const [reference, setReference] = useState('');
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [onlyMissing, setOnlyMissing] = useState(false);

  const { data, isLoading, isError, error: queryError, refetch } = usePayoutQueue({
    page,
    pageSize: PAGE_SIZE,
  });
  const processPayout = useProcessPayout();

  const allItems = data?.items ?? [];
  const missingDetails = allItems.filter((p) => !p.hasBankDetails).length;
  const items = onlyMissing ? allItems.filter((p) => !p.hasBankDetails) : allItems;

  const openProcess = (payout: PayoutQueueItem) => {
    setSuccessMessage(null);
    setActionError(null);
    setReference('');
    setPending(payout);
  };

  const closeProcess = () => {
    setPending(null);
    setReference('');
  };

  const handleConfirm = async () => {
    if (!pending) return;
    const payout = pending;
    setActionError(null);

    try {
      await processPayout.mutateAsync({ id: payout.id, transferReference: reference.trim() });
      setSuccessMessage(
        `Marked ${money(payout.netAmount)} to ${payout.tradieName} as processed. They've been notified.`,
      );
      if (allItems.length === 1 && page > 1) setPage(page - 1);
    } catch (err) {
      setActionError(
        `Could not process ${money(payout.netAmount)} for ${payout.tradieName}: ${describePayoutError(err)}`,
      );
    } finally {
      closeProcess();
    }
  };

  const columns: ColumnDef<PayoutQueueItem>[] = [
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'primary',
      cell: (payout) => (
        <div>
          <Link to={`/users/${payout.tradieId}`} className="cell-link font-medium">
            {payout.tradieName}
          </Link>
          {!payout.hasBankDetails && (
            <span className="block text-xs text-[var(--red)] font-normal mt-0.5">
              No bank details on file
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'job',
      header: 'Job',
      priority: 'detail',
      cell: (payout) => (
        <div>
          <Link to={`/jobs/${payout.jobId}`} className="cell-link">
            {payout.jobTitle}
          </Link>
          {payout.jobReferenceCode && (
            <span className="block text-xs cell-muted font-mono">
              {payout.jobReferenceCode}
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'gross',
      header: 'Gross',
      priority: 'detail',
      cell: (payout) => <span className="font-mono">{money(payout.grossAmount)}</span>,
    },
    {
      key: 'fee',
      header: 'Fee',
      priority: 'detail',
      cell: (payout) => (
        <span className="font-mono cell-muted">
          −{money(payout.commissionAmount)}
          <span className="block text-xs">{payout.commissionPercent}%</span>
        </span>
      ),
    },
    {
      key: 'net',
      header: 'Net',
      priority: 'secondary',
      cell: (payout) => (
        <span className="font-mono font-semibold">{money(payout.netAmount)}</span>
      ),
    },
    {
      key: 'bank',
      header: 'Bank',
      priority: 'detail',
      cell: (payout) => (
        <div className="font-mono">
          {payout.hasBankDetails ? (
            <>····{payout.bankAccountLast4 ?? '????'}</>
          ) : (
            <span className="pill pill-red">No details</span>
          )}
          {payout.bankAccountName && (
            <span className="block text-xs cell-muted">{payout.bankAccountName}</span>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (payout) => <PayoutStatusBadge status={payout.status} />,
    },
    {
      key: 'createdAt',
      header: 'Age',
      priority: 'detail',
      cell: (payout) => <span className="cell-muted">{createdAgo(payout.createdAtUtc)}</span>,
    },
  ];

  const rowActions = (payout: PayoutQueueItem): RowAction[] => [
    {
      label: 'Process',
      onClick: () => openProcess(payout),
      variant: 'primary',
      disabled: processPayout.isPending,
      primary: true,
    },
  ];

  return (
    <div className="space-y-5">
      <PageHeader
        title="Payout Queue"
        description="Tradie payouts created when a job completed. Move the money in your banking platform, then record the transfer reference here so the tradie is notified and the row clears."
        meta={
          data && (
            <>
              <div className="stat-pill">
                <Wallet size={13} aria-hidden="true" />
                <strong>{data.totalCount.toLocaleString()}</strong> awaiting payout
              </div>
              <div className="stat-pill">
                <strong>
                  {money(allItems.reduce((sum, p) => sum + p.netAmount, 0))}
                </strong>{' '}
                owed on this page
              </div>
              <Link to="/payouts/batches" className="stat-pill action-link">
                <Layers size={13} aria-hidden="true" />
                Payout batches
              </Link>
            </>
          )
        }
      />

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
          Could not load the payout queue: {describePayoutError(queryError)}
        </Banner>
      )}

      {missingDetails > 0 && (
        <div className="flex items-start gap-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg px-4 py-3 text-sm text-[var(--amber-dark)]">
          <CircleAlert size={14} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span className="flex-1 min-w-0">
            {missingDetails} payout{missingDetails === 1 ? '' : 's'} on this page have no bank
            account on file. They're skipped by the weekly batch until the tradie supplies details.
          </span>
          <button
            type="button"
            className="action-link shrink-0 cursor-pointer"
            aria-pressed={onlyMissing}
            onClick={() => setOnlyMissing((v) => !v)}
          >
            {onlyMissing ? 'Show all' : 'Show missing only'}
          </button>
        </div>
      )}

      <DataTable
        columns={columns}
        rows={items}
        getRowKey={(p) => p.id}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={
          data && allItems.length > 0 && items.length === 0
            ? 'No payouts on this page are missing bank details.'
            : data && data.totalCount > 0 && page > 1
              ? (
                <>
                  No payouts left on this page.{' '}
                  <button
                    className="action-link"
                    onClick={() => setPage(Math.max(1, data.totalPages))}
                  >
                    Go to page {Math.max(1, data.totalPages)}
                  </button>
                </>
              )
              : 'No payouts awaiting payout.'
        }
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="payouts"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      <p className="flex items-center gap-1.5 text-xs text-[var(--ink-soft)]">
        <Wallet size={12} aria-hidden="true" />
        Only the last four digits of each account are shown. A payout created without bank details
        stays in the queue and is excluded from the weekly batch until the tradie supplies them.
      </p>

      {pending && (
        <ProcessPayoutModal
          payout={pending}
          reference={reference.slice(0, REFERENCE_MAX)}
          onReferenceChange={setReference}
          isSubmitting={processPayout.isPending}
          onConfirm={handleConfirm}
          onCancel={closeProcess}
        />
      )}
    </div>
  );
};
