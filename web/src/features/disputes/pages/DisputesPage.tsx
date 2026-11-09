import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { useDisputeList } from '../hooks/useDisputes';

const PAGE_SIZE = 20;

const DISPUTE_STATUSES = ['All', 'Open', 'Resolved', 'Escalated'];

const formatJobId = (id: number) => `JOB-${String(id).padStart(5, '0')}`;

export const DisputesPage: React.FC = () => {
  const [disputeStatus, setDisputeStatus] = useState('Open');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useDisputeList({
    ...(disputeStatus === 'All' ? {} : { disputeStatus }),
    page,
    pageSize: PAGE_SIZE,
  });

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Disputes</h1>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <strong>{data.totalCount.toLocaleString()}</strong> {disputeStatus.toLowerCase()}
            </div>
            <div className="stat-pill">
              <strong>{data.items.length}</strong> on this page
            </div>
          </div>
        )}
      </div>

      {/* Status filter tabs */}
      <div className="flex gap-1 border-b border-[var(--paper-line)]">
        {DISPUTE_STATUSES.map((s) => (
          <button
            key={s}
            onClick={() => { setDisputeStatus(s); setPage(1); }}
            className={[
              'px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors',
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
      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Job ID</th>
                <th className="th">Job</th>
                <th className="th">Homeowner</th>
                <th className="th">Tradie</th>
                <th className="th">Job Status</th>
                <th className="th">Dispute</th>
                <th className="th">Flagged</th>
                <th className="th" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="td text-center cell-muted">Loading…</td>
                </tr>
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={8} className="td text-center cell-muted">
                    No disputes {disputeStatus !== 'All' ? `with status "${disputeStatus}"` : ''}.
                  </td>
                </tr>
              ) : (
                data?.items.map((d) => (
                  <tr key={d.jobId}>
                    <td className="td mono">
                      <Link to={`/disputes/${d.jobId}`} className="cell-link">
                        {formatJobId(d.jobId)}
                      </Link>
                    </td>
                    <td className="td">
                      <span className="block max-w-xs truncate">{d.jobTitle}</span>
                      {d.flagReason && (
                        <span className="block max-w-xs truncate text-xs cell-muted">
                          {d.flagReason}
                        </span>
                      )}
                    </td>
                    <td className="td cell-muted">{d.homeownerName}</td>
                    <td className="td cell-muted">{d.tradieName ?? '—'}</td>
                    <td className="td"><StatusBadge status={d.status} /></td>
                    <td className="td"><StatusBadge status={d.disputeStatus} /></td>
                    <td className="td cell-muted">
                      {new Date(d.flaggedAtUtc).toLocaleDateString()}
                    </td>
                    <td className="td text-right">
                      <Link to={`/disputes/${d.jobId}`} className="action-link">
                        Review
                      </Link>
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
            itemLabel="disputes"
            onPageChange={setPage}
          />
        )}
      </div>
    </div>
  );
};
