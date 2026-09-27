import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Search } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { useJobList } from '../hooks/useJobs';

const JOB_STATUSES = [
  'Draft', 'Requested', 'Matching', 'Matched',
  'Confirmed', 'InProgress', 'Complete', 'Cancelled',
];

export const JobListPage: React.FC = () => {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [sortDesc, setSortDesc] = useState(true);

  const { data, isLoading } = useJobList({
    search,
    status,
    page,
    pageSize: 20,
    sortBy: 'createdAt',
    sortDesc,
  });

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Jobs</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          {data ? `${data.totalCount.toLocaleString()} total` : ''}
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-soft)]" />
          <input
            type="search"
            placeholder="Search title or address…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full pl-8 pr-3 py-2 text-sm border border-[var(--paper-line)] rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)]"
          />
        </div>
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-[var(--paper-line)] rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)]"
        >
          <option value="">All statuses</option>
          {JOB_STATUSES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
        <button
          onClick={() => setSortDesc((d) => !d)}
          className="px-3 py-2 text-sm border border-[var(--paper-line)] rounded text-[var(--ink-soft)] hover:bg-[var(--paper-line)] transition-colors"
        >
          {sortDesc ? 'Newest first' : 'Oldest first'}
        </button>
      </div>

      {/* Table */}
      <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-[var(--paper-line)]/50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Title</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Category</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Homeowner</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Tradie</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-[var(--ink-soft)] uppercase tracking-wide">Created</th>
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
                  <td colSpan={7} className="px-4 py-8 text-center text-[var(--ink-soft)]">No jobs found.</td>
                </tr>
              ) : (
                data?.items.map((job) => (
                  <tr key={job.id} className="hover:bg-[var(--paper-line)]/30 transition-colors">
                    <td className="px-4 py-3 font-medium text-[var(--ink)] max-w-xs truncate">{job.title}</td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{job.category}</td>
                    <td className="px-4 py-3"><StatusBadge status={job.status} /></td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{job.homeownerName}</td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">{job.tradeName ?? '—'}</td>
                    <td className="px-4 py-3 text-[var(--ink-soft)]">
                      {new Date(job.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Link
                        to={`/jobs/${job.id}`}
                        className="text-xs text-[var(--brand-500)] hover:underline"
                      >
                        View
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
