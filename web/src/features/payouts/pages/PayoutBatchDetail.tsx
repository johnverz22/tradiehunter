import React, { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import axios from 'axios';
import { ArrowLeft, CheckCircle, Layers } from 'lucide-react';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { BatchStatusBadge, PayoutStatusBadge } from '../components/PayoutStatusBadge';
import { createdAgo, money, periodLabel } from '../format';
import { useCompletePayoutBatch, usePayoutBatch } from '../hooks/usePayouts';

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
      <div className="space-y-5">
        <p className="text-sm text-[var(--ink-soft)]">Loading batch…</p>
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="space-y-5">
        <div
          className="flex flex-wrap items-center justify-between gap-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]"
          role="alert"
        >
          <span>Could not load this batch: {describeBatchError(queryError)}</span>
          <button className="btn btn-ghost !py-1 !px-2.5 !text-xs" onClick={() => refetch()}>
            Retry
          </button>
        </div>
        <Link to="/payouts/batches" className="action-link inline-flex items-center gap-1.5">
          <ArrowLeft size={13} aria-hidden="true" />
          Back to payout batches
        </Link>
      </div>
    );
  }

  const unprocessed = data.payouts.filter((p) => p.status !== 'Processed').length;

  return (
    <div className="space-y-5">
      <div>
        <Link to="/payouts/batches" className="action-link inline-flex items-center gap-1.5">
          <ArrowLeft size={13} aria-hidden="true" />
          Payout batches
        </Link>
        <h1 className="text-xl font-bold text-[var(--ink)] mt-2">
          {periodLabel(data.periodStartUtc, data.periodEndUtc)}
        </h1>
        <p className="text-sm text-[var(--ink-soft)]">
          Batch <span className="font-mono">{data.id}</span>
        </p>

        <div className="flex flex-wrap gap-4 mt-3">
          <div className="stat-pill">
            <Layers size={13} aria-hidden="true" />
            <strong>
              {data.processedCount}/{data.payoutCount}
            </strong>{' '}
            processed
          </div>
          <div className="stat-pill">
            <strong>{money(data.totalAmount)}</strong> net total
          </div>
          <div className="stat-pill">
            <BatchStatusBadge status={data.status} />
          </div>
        </div>
      </div>

      {successMessage && (
        <div className="flex items-center gap-2 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg px-4 py-3 text-sm text-green-700 dark:text-green-400">
          <CheckCircle size={14} aria-hidden="true" />
          {successMessage}
        </div>
      )}

      {actionError && (
        <div
          className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]"
          role="alert"
        >
          {actionError}
        </div>
      )}

      <div className="flex flex-wrap items-center gap-3">
        <Link to="/payouts" className="btn btn-ghost">
          Process from the queue
        </Link>
        <button
          className="btn btn-primary"
          // The backend refuses while any payout is outstanding, so don't offer it.
          disabled={unprocessed > 0 || data.status === 'Completed' || completeBatch.isPending}
          onClick={() => setConfirming(true)}
        >
          {data.status === 'Completed' ? 'Batch complete' : 'Mark Batch Complete'}
        </button>
        {unprocessed > 0 && (
          <span className="text-xs text-[var(--ink-soft)]">
            {unprocessed} payout{unprocessed === 1 ? '' : 's'} still to process.
          </span>
        )}
      </div>

      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Tradie</th>
                <th className="th">Job</th>
                <th className="th">Gross</th>
                <th className="th">Fee</th>
                <th className="th">Net</th>
                <th className="th">Bank</th>
                <th className="th">Status</th>
                <th className="th">Transfer ref</th>
                <th className="th">Age</th>
              </tr>
            </thead>
            <tbody>
              {data.payouts.length === 0 ? (
                <tr>
                  <td colSpan={9} className="td text-center cell-muted">
                    This batch has no payouts.
                  </td>
                </tr>
              ) : (
                data.payouts.map((payout) => (
                  <tr key={payout.id}>
                    <td className="td">
                      <Link to={`/users/${payout.tradieId}`} className="cell-link">
                        {payout.tradieName}
                      </Link>
                    </td>
                    <td className="td">
                      <Link to={`/jobs/${payout.jobId}`} className="cell-link">
                        {payout.jobTitle}
                      </Link>
                      {payout.jobReferenceCode && (
                        <span className="block text-xs cell-muted font-mono">
                          {payout.jobReferenceCode}
                        </span>
                      )}
                    </td>
                    <td className="td font-mono">{money(payout.grossAmount)}</td>
                    <td className="td font-mono cell-muted">−{money(payout.commissionAmount)}</td>
                    <td className="td font-mono font-semibold">{money(payout.netAmount)}</td>
                    <td className="td font-mono">
                      {payout.hasBankDetails ? (
                        <>····{payout.bankAccountLast4 ?? '????'}</>
                      ) : (
                        <span className="pill pill-red">No details</span>
                      )}
                    </td>
                    <td className="td">
                      <PayoutStatusBadge status={payout.status} />
                    </td>
                    <td className="td font-mono cell-muted">{payout.transferReference ?? '—'}</td>
                    <td className="td cell-muted">{createdAgo(payout.createdAtUtc)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

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
