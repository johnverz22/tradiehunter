import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { RotateCcw } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
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

  const columns: ColumnDef<RefundSummary>[] = [
    {
      key: 'job',
      header: 'Job',
      priority: 'primary',
      cell: (refund) => (
        <div>
          <Link to={`/jobs/${refund.jobId}`} className="cell-link">
            {refund.jobTitle}
          </Link>
          <span className="block text-xs cell-muted">Job #{refund.jobId}</span>
        </div>
      ),
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (refund) => (
        <div>
          {refund.homeownerName}
          <span className="block text-xs cell-muted">{refund.homeownerEmail}</span>
        </div>
      ),
    },
    {
      key: 'suggested',
      header: 'Suggested',
      priority: 'secondary',
      cell: (refund) => (
        <span className="font-mono">{money(refund.suggestedAmount)}</span>
      ),
    },
    {
      key: 'penalty',
      header: 'Penalty',
      priority: 'detail',
      cell: (refund) => (
        <span className="font-mono text-[var(--amber-dark)]">
          {refund.penalty > 0 ? money(refund.penalty) : '—'}
        </span>
      ),
    },
    {
      key: 'reason',
      header: 'Reason',
      priority: 'detail',
      cell: (refund) => (
        <span className="text-xs cell-muted">
          {refund.cancelReasonCode
            ? refund.cancelReasonCode.replace(/_/g, ' ')
            : '—'}
        </span>
      ),
    },
    {
      key: 'createdAt',
      header: 'Created',
      priority: 'secondary',
      cell: (refund) => (
        <span className="cell-muted">{createdAgo(refund.createdAtUtc)}</span>
      ),
    },
  ];

  const rowActions = (refund: RefundSummary): RowAction[] => [
    {
      label: 'Process',
      onClick: () => openModal(refund),
      variant: 'primary',
      disabled: isPending,
      primary: true,
    },
  ];

  return (
    <div className="space-y-5">
      {/* Header */}
      <PageHeader
        title="Refund Queue"
        description="Jobs cancelled after payment is collected. Review the suggested amounts, adjust if needed, record your bank transfer reference, and optionally attach proof."
        meta={
          data && (
            <>
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
          Could not load the refund queue: {describeError(queryError)}
        </Banner>
      )}

      {/* Queue table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(r) => r.id}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={
          data && data.totalCount > 0 && page > 1 ? (
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
          )
        }
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="refunds"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

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
