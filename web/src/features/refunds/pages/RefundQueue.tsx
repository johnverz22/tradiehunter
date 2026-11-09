import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle, RotateCcw } from 'lucide-react';
import { Pagination } from '../../../components/Pagination';
import { useRefundQueue, useProcessRefund } from '../hooks/useRefunds';
import { ProcessRefundModal } from '../components/ProcessRefundModal';
import type { RefundSummary } from '../../../services/adminApi';

const PAGE_SIZE = 20;

const money = (amount: number) =>
  new Intl.NumberFormat('en-NZ', { style: 'currency', currency: 'NZD' }).format(amount);

const createdAgo = (iso: string) => {
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  return hours < 24 ? `${hours}h ago` : `${Math.round(hours / 24)}d ago`;
};

function describeError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    if (!error.response)
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}.`;
    const data: unknown = error.response.data;
    if (Array.isArray(data)) {
      const first = data.find(
        (e) => typeof e === 'object' && e !== null && 'errorMessage' in e,
      ) as { errorMessage?: unknown } | undefined;
      if (first?.errorMessage) return String(first.errorMessage);
    }
    if (typeof data === 'object' && data !== null && 'message' in data)
      return String((data as { message: unknown }).message);
    return `Request failed with status ${error.response.status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

export const RefundQueue: React.FC = () => {
  const [page, setPage] = useState(1);
  const [selectedRefund, setSelectedRefund] = useState<RefundSummary | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const { data, isLoading, isError, error: queryError, refetch } = useRefundQueue({
    page,
    pageSize: PAGE_SIZE,
  });

  const { mutateAsync: process, isPending } = useProcessRefund();

  const openModal = (refund: RefundSummary) => {
    setSuccessMessage(null);
    setActionError(null);
    setSelectedRefund(refund);
  };

  const closeModal = () => setSelectedRefund(null);

  const handleProcess = async (params: {
    finalAmount: number;
    penalty: number;
    hoursWorked: number;
    transferReference: string;
    proof?: File;
  }) => {
    if (!selectedRefund) return;
    setActionError(null);

    try {
      await process({
        id: selectedRefund.id,
        body: {
          finalAmount: params.finalAmount,
          penalty: params.penalty,
          hoursWorked: params.hoursWorked,
          transferReference: params.transferReference,
          proof: params.proof,
        },
      });
      setSuccessMessage(
        `Refund of ${money(params.finalAmount)} for "${selectedRefund.jobTitle}" processed. ` +
          `The homeowner has been notified. Ref: ${params.transferReference}.`,
      );
      if (data && data.items.length === 1 && page > 1) setPage(page - 1);
    } catch (err) {
      setActionError(`Could not process refund for "${selectedRefund.jobTitle}": ${describeError(err)}`);
    } finally {
      closeModal();
    }
  };

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Refund Queue</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          Jobs cancelled after payment is collected. Review the suggested amounts, adjust if needed,
          record your bank transfer reference, and optionally attach proof.
        </p>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <RotateCcw size={13} aria-hidden="true" />
              <strong>{data.totalCount.toLocaleString()}</strong> pending refunds
            </div>
            {data.items.length > 0 && (
              <div className="stat-pill">
                <strong>
                  {money(data.items.reduce((sum, r) => sum + r.suggestedAmount, 0))}
                </strong>{' '}
                suggested on this page
              </div>
            )}
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
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          {actionError}
        </div>
      )}

      {isError && (
        <div className="flex flex-wrap items-center justify-between gap-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          <span>Could not load the refund queue: {describeError(queryError)}</span>
          <button className="btn btn-ghost !py-1 !px-2.5 !text-xs" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      )}

      {/* Queue table */}
      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Job</th>
                <th className="th">Homeowner</th>
                <th className="th">Suggested</th>
                <th className="th">Penalty</th>
                <th className="th">Reason</th>
                <th className="th">Created</th>
                <th className="th" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="td text-center cell-muted">
                    Loading…
                  </td>
                </tr>
              ) : data && data.items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="td text-center cell-muted">
                    {data.totalCount > 0 && page > 1 ? (
                      <>
                        No refunds on this page.{' '}
                        <button
                          className="action-link"
                          onClick={() => setPage(Math.max(1, data.totalPages))}
                        >
                          Go to page {Math.max(1, data.totalPages)}
                        </button>
                      </>
                    ) : (
                      'No pending refunds — all caught up.'
                    )}
                  </td>
                </tr>
              ) : (
                data?.items.map((refund) => (
                  <tr key={refund.id}>
                    <td className="td">
                      <Link to={`/jobs/${refund.jobId}`} className="cell-link">
                        {refund.jobTitle}
                      </Link>
                      <span className="block text-xs cell-muted">Job #{refund.jobId}</span>
                    </td>
                    <td className="td">
                      {refund.homeownerName}
                      <span className="block text-xs cell-muted">{refund.homeownerEmail}</span>
                    </td>
                    <td className="td font-mono">{money(refund.suggestedAmount)}</td>
                    <td className="td font-mono text-[var(--amber-dark)]">
                      {refund.penalty > 0 ? money(refund.penalty) : '—'}
                    </td>
                    <td className="td text-xs cell-muted">
                      {refund.cancelReasonCode
                        ? refund.cancelReasonCode.replace(/_/g, ' ')
                        : '—'}
                    </td>
                    <td className="td cell-muted">{createdAgo(refund.createdAtUtc)}</td>
                    <td className="td">
                      <button
                        className="btn btn-primary !py-1 !px-2.5 !text-xs"
                        onClick={() => openModal(refund)}
                        disabled={isPending}
                      >
                        Process
                      </button>
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
            itemLabel="refunds"
            onPageChange={setPage}
          />
        )}
      </div>

      {/* Processing modal */}
      {selectedRefund && (
        <ProcessRefundModal
          refund={selectedRefund}
          isSubmitting={isPending}
          onConfirm={handleProcess}
          onCancel={closeModal}
        />
      )}
    </div>
  );
};
