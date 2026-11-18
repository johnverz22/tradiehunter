import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { Wallet } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Badge } from '../../../components/Badge';
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
          <Link to={`/users/${payout.tradieId}`} className="cell-link">
            {payout.tradieName}
          </Link>
          {!payout.hasBankDetails && (
            <span className="block t-meta c-danger">No bank details on file</span>
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
            <span className="block t-meta muted mono">
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
      cell: (payout) => <span className="money">{money(payout.grossAmount)}</span>,
    },
    {
      key: 'fee',
      header: 'Fee',
      priority: 'detail',
      cell: (payout) => (
        <span className="money muted">
          −{money(payout.commissionAmount)}
          <span className="block t-meta">{payout.commissionPercent}%</span>
        </span>
      ),
    },
    {
      key: 'net',
      header: 'Net',
      priority: 'secondary',
      cell: (payout) => (
        <span className="money">{money(payout.netAmount)}</span>
      ),
    },
    {
      key: 'bank',
      header: 'Bank',
      priority: 'detail',
      cell: (payout) => (
        <div className="mono">
          {payout.hasBankDetails ? (
            <>····{payout.bankAccountLast4 ?? '????'}</>
          ) : (
            <Badge tone="danger" dot>No details</Badge>
          )}
          {payout.bankAccountName && (
            <span className="block t-meta muted">{payout.bankAccountName}</span>
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
      cell: (payout) => <span className="muted">{createdAgo(payout.createdAtUtc)}</span>,
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
    <>
      <PageHeader
        title="Payout queue"
        description="Tradie payouts created when a job completed. Move the money in your banking platform, then record the transfer reference here so the tradie is notified and the row clears."
        actions={
          <Link to="/payouts/batches" className="btn btn-secondary">
            Payout batches
          </Link>
        }
        meta={
          data && allItems.length > 0 ? (
            <Badge>
              {money(allItems.reduce((sum, p) => sum + p.netAmount, 0))} owed on this page
            </Badge>
          ) : undefined
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
        <Banner
          variant="warn"
          action={{
            label: onlyMissing ? 'Show all' : 'Show missing only',
            onClick: () => setOnlyMissing((v) => !v),
          }}
        >
          {missingDetails} payout{missingDetails === 1 ? '' : 's'} on this page have no bank
          account on file. They're skipped by the weekly batch until the tradie supplies details.
        </Banner>
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
                    type="button"
                    className="cell-link"
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

      <p className="t-meta c-soft row">
        <Wallet size={16} aria-hidden="true" />
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
    </>
  );
};
