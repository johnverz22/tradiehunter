import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle, CircleAlert, Layers, Wallet } from 'lucide-react';
import { Pagination } from '../../../components/Pagination';
import { ProcessPayoutModal } from '../components/ProcessPayoutModal';
import { PayoutStatusBadge } from '../components/PayoutStatusBadge';
import { createdAgo, money } from '../format';
import { usePayoutQueue, useProcessPayout } from '../hooks/usePayouts';
import type { PayoutQueueItem } from '../../../services/adminApi';

const PAGE_SIZE = 20;

/** Matches the backend's `ProcessPayoutRequest.TransferReference`. */
const REFERENCE_MAX = 64;

/**
 * The backend answers 400/404 with `{ message }` — surface it rather than a
 * bare status code, because the payout endpoints explain exactly why they
 * refused (not found, or already processed by someone else).
 */
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
    if (status === 404)
      return 'That payout no longer exists (404). Reload the queue.';
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

  const { data, isLoading, isError, error: queryError, refetch } = usePayoutQueue({
    page,
    pageSize: PAGE_SIZE,
  });
  const processPayout = useProcessPayout();

  const items = data?.items ?? [];
  const missingDetails = items.filter((p) => !p.hasBankDetails).length;

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
      // Reviewing the only row left on a page would leave it empty — step back.
      if (items.length === 1 && page > 1) setPage(page - 1);
    } catch (err) {
      setActionError(
        `Could not process ${money(payout.netAmount)} for ${payout.tradieName}: ${describePayoutError(err)}`,
      );
    } finally {
      closeProcess();
    }
  };

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Payout Queue</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          Tradie payouts created when a job completed. Move the money in your banking platform,
          then record the transfer reference here so the tradie is notified and the row clears.
        </p>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <Wallet size={13} aria-hidden="true" />
              <strong>{data.totalCount.toLocaleString()}</strong> awaiting payout
            </div>
            <div className="stat-pill">
              <strong>
                {money(items.reduce((sum, p) => sum + p.netAmount, 0))}
              </strong>{' '}
              owed on this page
            </div>
            <Link to="/payouts/batches" className="stat-pill action-link">
              <Layers size={13} aria-hidden="true" />
              Payout batches
            </Link>
          </div>
        )}
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

      {isError && (
        <div className="flex flex-wrap items-center justify-between gap-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          <span>Could not load the payout queue: {describePayoutError(queryError)}</span>
          <button className="btn btn-ghost !py-1 !px-2.5 !text-xs" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      )}

      {missingDetails > 0 && (
        <div className="flex items-start gap-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg px-4 py-3 text-sm text-[var(--amber-dark)]">
          <CircleAlert size={14} className="mt-0.5 shrink-0" aria-hidden="true" />
          <span>
            {missingDetails} payout{missingDetails === 1 ? '' : 's'} on this page have no bank
            account on file. They're skipped by the weekly batch until the tradie supplies details.
          </span>
        </div>
      )}

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
                <th className="th">Age</th>
                <th className="th" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={9} className="td text-center cell-muted">
                    Loading…
                  </td>
                </tr>
              ) : data && data.items.length === 0 ? (
                <tr>
                  <td colSpan={9} className="td text-center cell-muted">
                    {data.totalCount > 0 && page > 1 ? (
                      <>
                        No payouts left on this page.{' '}
                        <button
                          className="action-link"
                          onClick={() => setPage(Math.max(1, data.totalPages))}
                        >
                          Go to page {Math.max(1, data.totalPages)}
                        </button>
                      </>
                    ) : (
                      'No payouts awaiting payout.'
                    )}
                  </td>
                </tr>
              ) : (
                items.map((payout) => (
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
                    <td className="td font-mono cell-muted">
                      −{money(payout.commissionAmount)}
                      <span className="block text-xs">{payout.commissionPercent}%</span>
                    </td>
                    <td className="td font-mono font-semibold">{money(payout.netAmount)}</td>
                    <td className="td font-mono">
                      {payout.hasBankDetails ? (
                        <>····{payout.bankAccountLast4 ?? '????'}</>
                      ) : (
                        <span className="pill pill-red">No details</span>
                      )}
                      {payout.bankAccountName && (
                        <span className="block text-xs cell-muted">{payout.bankAccountName}</span>
                      )}
                    </td>
                    <td className="td">
                      <PayoutStatusBadge status={payout.status} />
                    </td>
                    <td className="td cell-muted">{createdAgo(payout.createdAtUtc)}</td>
                    <td className="td">
                      <div className="flex items-center justify-end">
                        <button
                          className="btn btn-primary !py-1 !px-2.5 !text-xs"
                          disabled={processPayout.isPending}
                          onClick={() => openProcess(payout)}
                        >
                          Process
                        </button>
                      </div>
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
            itemLabel="payouts"
            onPageChange={setPage}
          />
        )}
      </div>

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
