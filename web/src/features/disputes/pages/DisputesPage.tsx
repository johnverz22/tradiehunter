import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { useDisputeList } from '../hooks/useDisputes';

const DISPUTE_STATUSES = ['All', 'Open', 'Resolved', 'Escalated'];

export const DisputesPage: React.FC = () => {
  const [disputeStatus, setDisputeStatus] = useState('Open');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useDisputeList({
    disputeStatus: disputeStatus === 'All' ? undefined : disputeStatus,
    page,
    pageSize: 20,
  });

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Disputes</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          {data ? `${data.totalCount} dispute${data.totalCount !== 1 ? 's' : ''}` : ''}
        </p>
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
      <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-[var(--paper-line)]/50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Job</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Homeowner</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Tradie</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Job Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Dispute</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Flagged</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--paper-line)]">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-[var(--ink-soft)]">Loading…</td>
                </tr>
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-[var(--ink-soft)]">
                    No disputes {disputeStatus !== 'All' ? `with status "${disputeStatus}"` : ''}.
                  </td>
                </tr>
              ) : (
                data?.items.map((d) => (
                  <tr key={d.jobId} className="hover:bg-[var(--paper-line)]/30 transition-colors">
                    <td className="px-4 py-3">
                      <span className="font-medium text-[var(--ink)] block max-w-xs truncate">
                        {d.jobTitle}
                      </span>
                      {d.flagReason && (
                        <span className="text-xs text-[var(--ink-soft)] block truncate max-w-xs">
                          {d.flagReason}
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{d.homeownerName}</td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{d.tradieName ?? '—'}</td>
                    <td className="px-4 py-3"><StatusBadge status={d.status} /></td>
                    <td className="px-4 py-3"><StatusBadge status={d.disputeStatus} /></td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">
                      {new Date(d.flaggedAtUtc).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Link
                        to={`/disputes/${d.jobId}`}
                        className="text-xs text-[var(--brand-500)] hover:underline"
                      >
                        Review
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {data && (
        <Pagination page={data.page} totalPages={data.totalPages} onPageChange={setPage} />
      )}
    </div>
  );
};
