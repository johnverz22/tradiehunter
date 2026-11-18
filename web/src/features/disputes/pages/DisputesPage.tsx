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

const tabId = (status: string) => `dispute-tab-${status.toLowerCase()}`;

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

  const selectStatus = (s: string) => {
    setDisputeStatus(s);
    setPage(1);
  };

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
          <span className="block max-w-xs truncate">{d.jobTitle}</span>
          {d.flagReason && (
            <span className="block max-w-xs truncate t-meta muted">
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
      cell: (d) => <span className="muted">{d.homeownerName}</span>,
    },
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'detail',
      cell: (d) => <span className="muted">{d.tradieName ?? '—'}</span>,
    },
    {
      key: 'jobStatus',
      header: 'Job status',
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
        <span className="muted">
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

  const onTabKeyDown = (e: React.KeyboardEvent<HTMLButtonElement>, index: number) => {
    const last = DISPUTE_STATUSES.length - 1;
    let next = -1;
    if (e.key === 'ArrowRight') next = index === last ? 0 : index + 1;
    else if (e.key === 'ArrowLeft') next = index === 0 ? last : index - 1;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = last;
    if (next < 0) return;
    e.preventDefault();
    selectStatus(DISPUTE_STATUSES[next]);
    document.getElementById(tabId(DISPUTE_STATUSES[next]))?.focus();
  };

  return (
    <>
      <PageHeader title="Disputes" description="Flagged jobs under review" />

      {/* Status tabs (kit `.tabs`, scroll sideways on phones) */}
      <div className="tabs" role="tablist" aria-label="Dispute status">
        {DISPUTE_STATUSES.map((s, i) => (
          <button
            key={s}
            type="button"
            role="tab"
            id={tabId(s)}
            aria-selected={disputeStatus === s}
            aria-controls="disputes-panel"
            tabIndex={disputeStatus === s ? 0 : -1}
            onClick={() => selectStatus(s)}
            onKeyDown={(e) => onTabKeyDown(e, i)}
          >
            {s}
          </button>
        ))}
      </div>

      {/* Table */}
      <div role="tabpanel" id="disputes-panel" aria-labelledby={tabId(disputeStatus)}>
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
    </>
  );
};
