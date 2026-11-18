import React, { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import axios from 'axios';
import { PageHeader } from '../../../components/PageHeader';
import { Badge } from '../../../components/Badge';
import { Banner } from '../../../components/Banner';
import { Button } from '../../../components/Button';
import { DataTable, type ColumnDef } from '../../../components/DataTable';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { BatchStatusBadge, PayoutStatusBadge } from '../components/PayoutStatusBadge';
import { createdAgo, money, periodLabel } from '../format';
import { useCompletePayoutBatch, usePayoutBatch } from '../hooks/usePayouts';
import type { PayoutQueueItem } from '../../../services/adminApi';

function describeBatchError(error: unknown): string {
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
    if (status === 404) return 'That batch no longer exists (404).';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

export const PayoutBatchDetail: React.FC = () => {
  const { id = '' } = useParams<{ id: string }>();

  const { data, isLoading, isError, error: queryError, refetch } = usePayoutBatch(id);
  const completeBatch = useCompletePayoutBatch();

  const [confirming, setConfirming] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const handleComplete = async () => {
    setActionError(null);
    try {
      await completeBatch.mutateAsync(id);
      setSuccessMessage('Batch marked complete.');
      setConfirming(false);
    } catch (err) {
      setActionError(describeBatchError(err));
    }
  };

  if (isLoading) {
    return (
      <p className="muted" role="status" aria-busy="true">
        Loading batch…
      </p>
    );
  }

  if (isError || !data) {
    return (
      <div className="stack">
        <Banner
          variant="error"
          action={{ label: 'Retry', onClick: () => refetch() }}
        >
          Could not load this batch: {describeBatchError(queryError)}
        </Banner>
        <Link to="/payouts/batches" className="cell-link">
          ← Back to payout batches
        </Link>
      </div>
    );
  }

  const unprocessed = data.payouts.filter((p) => p.status !== 'Processed').length;

  const columns: ColumnDef<PayoutQueueItem>[] = [
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'primary',
      cell: (payout) => (
        <Link to={`/users/${payout.tradieId}`} className="cell-link">
          {payout.tradieName}
        </Link>
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
        <span className="money muted">−{money(payout.commissionAmount)}</span>
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
        <span className="mono">
          {payout.hasBankDetails ? (
            <>····{payout.bankAccountLast4 ?? '????'}</>
          ) : (
            <Badge tone="danger" dot>
              No details
            </Badge>
          )}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (payout) => <PayoutStatusBadge status={payout.status} />,
    },
    {
      key: 'ref',
      header: 'Transfer ref',
      priority: 'detail',
      cell: (payout) => (
        <span className="mono muted">{payout.transferReference ?? '—'}</span>
      ),
    },
    {
      key: 'createdAt',
      header: 'Age',
      priority: 'detail',
      cell: (payout) => <span className="muted">{createdAgo(payout.createdAtUtc)}</span>,
    },
  ];

  return (
    <div className="stack">
      <PageHeader
        backLink={{ to: '/payouts/batches', label: 'Payout batches' }}
        title={periodLabel(data.periodStartUtc, data.periodEndUtc)}
        description={`Batch ${data.id}`}
        meta={
          <>
            <Badge>
              {data.processedCount}/{data.payoutCount} processed
            </Badge>
            <Badge>{money(data.totalAmount)} net total</Badge>
            <BatchStatusBadge status={data.status} />
          </>
        }
        actions={
          <>
            <Link to="/payouts" className="btn btn-secondary">
              Process from queue
            </Link>
            <Button
              kind="accent"
              disabled={unprocessed > 0 || data.status === 'Completed' || completeBatch.isPending}
              onClick={() => setConfirming(true)}
            >
              {data.status === 'Completed' ? 'Batch complete' : 'Mark Batch Complete'}
            </Button>
          </>
        }
      />

      {unprocessed > 0 && (
        <p className="t-meta muted">
          {unprocessed} payout{unprocessed === 1 ? '' : 's'} still to process.
        </p>
      )}

      {successMessage && (
        <Banner variant="success">{successMessage}</Banner>
      )}

      {actionError && (
        <Banner variant="error">{actionError}</Banner>
      )}

      <DataTable
        columns={columns}
        rows={data.payouts}
        getRowKey={(p) => p.id}
        empty="This batch has no payouts."
      />

      {confirming && (
        <ConfirmModal
          open
          title="Mark this batch complete?"
          message={`Close out the ${data.payoutCount}-payout batch for ${periodLabel(data.periodStartUtc, data.periodEndUtc)}. Every payout in it is already processed.`}
          confirmLabel="Mark batch complete"
          confirmDisabled={completeBatch.isPending}
          onConfirm={handleComplete}
          onCancel={() => setConfirming(false)}
        />
      )}
    </div>
  );
};
