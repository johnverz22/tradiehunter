import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { PageHeader } from '../../../components/PageHeader';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { useDisputeList } from '../hooks/useDisputes';
import type { AdminDisputeListItem } from '../../../services/adminApi';

const PAGE_SIZE = 20;

const DISPUTE_STATUSES = ['All', 'Open', 'Resolved', 'Escalated'];

const formatJobId = (id: number) => `JOB-${String(id).padStart(5, '0')}`;

export const DisputesPage: React.FC = () => {
  const navigate = useNavigate();
  const [disputeStatus, setDisputeStatus] = useState('Open');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useDisputeList({
    ...(disputeStatus === 'All' ? {} : { disputeStatus }),
    page,
    pageSize: PAGE_SIZE,
  });

  const columns: ColumnDef<AdminDisputeListItem>[] = [
    {
      key: 'jobId',
      header: 'Job ID',
      priority: 'detail',
      cell: (d) => (
        <span className="mono">
          <Link to={`/disputes/${d.jobId}`} className="cell-link">
            {formatJobId(d.jobId)}
          </Link>
        </span>
      ),
    },
    {
      key: 'job',
      header: 'Job',
      priority: 'primary',
      cell: (d) => (
        <div>
          <span className="block max-w-xs truncate font-medium text-[var(--ink)]">
            {d.jobTitle}
          </span>
          {d.flagReason && (
            <span className="block max-w-xs truncate text-xs cell-muted">
              {d.flagReason}
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (d) => <span className="cell-muted">{d.homeownerName}</span>,
    },
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'detail',
      cell: (d) => <span className="cell-muted">{d.tradieName ?? '—'}</span>,
    },
    {
      key: 'jobStatus',
      header: 'Job Status',
      priority: 'detail',
      cell: (d) => <StatusBadge status={d.status} />,
    },
    {
      key: 'disputeStatus',
      header: 'Dispute',
      priority: 'secondary',
      cell: (d) => <StatusBadge status={d.disputeStatus} />,
    },
    {
      key: 'flagged',
      header: 'Flagged',
      priority: 'secondary',
      cell: (d) => (
        <span className="cell-muted">
          {new Date(d.flaggedAtUtc).toLocaleDateString()}
        </span>
      ),
    },
  ];

  const rowActions = (d: AdminDisputeListItem): RowAction[] => [
    {
      label: 'Review',
      to: `/disputes/${d.jobId}`,
      variant: 'ghost',
      primary: true,
    },
  ];

  return (
    <div className="space-y-5">
      {/* Header */}
      <PageHeader
        title="Disputes"
        meta={
          data && (
            <>
              <div className="stat-pill">
                <strong>{data.totalCount.toLocaleString()}</strong> {disputeStatus.toLowerCase()}
              </div>
              <div className="stat-pill">
                <strong>{data.items.length}</strong> on this page
              </div>
            </>
          )
        }
      />

      {/* Status filter tabs - scrollable segmented control on mobile */}
      <div className="flex gap-1 border-b border-[var(--paper-line)] overflow-x-auto whitespace-nowrap">
        {DISPUTE_STATUSES.map((s) => (
          <button
            key={s}
            onClick={() => {
              setDisputeStatus(s);
              setPage(1);
            }}
            className={[
              'px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors min-h-[44px] shrink-0',
              disputeStatus === s
                ? 'border-[var(--brand-500)] text-[var(--brand-700)]'
                : 'border-transparent text-[var(--ink-soft)] hover:text-[var(--ink)]',
            ].join(' ')}
          >
            {s}
          </button>
        ))}
      </div>

      {/* Table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(d) => d.jobId}
        onRowClick={(d) => navigate(`/disputes/${d.jobId}`)}
        isLoading={isLoading}
        rowActions={rowActions}
        empty={`No disputes ${disputeStatus !== 'All' ? `with status "${disputeStatus}"` : ''}.`}
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="disputes"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />
    </div>
  );
};
