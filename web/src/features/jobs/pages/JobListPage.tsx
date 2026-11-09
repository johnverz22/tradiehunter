import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Search } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { useJobList } from '../hooks/useJobs';

const PAGE_SIZE = 20;

const JOB_STATUSES = [
  'Draft', 'Requested', 'Matching', 'Matched',
  'Confirmed', 'InProgress', 'Complete', 'Cancelled',
];

const formatJobId = (id: number) => `JOB-${String(id).padStart(5, '0')}`;

export const JobListPage: React.FC = () => {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [sortDesc, setSortDesc] = useState(true);

  const { data, isLoading } = useJobList({
    search,
    status,
    page,
    pageSize: PAGE_SIZE,
    sortBy: 'createdAt',
    sortDesc,
  });

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Jobs</h1>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <strong>{data.totalCount.toLocaleString()}</strong> {status || 'All statuses'}
            </div>
            <div className="stat-pill">
              <strong>{data.items.length}</strong> on this page
            </div>
          </div>
        )}
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--ink-soft)]" />
          <input
            type="search"
            className="field field-search"
            placeholder="Search title or address…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>
        <span className="select-wrap">
          <select
            className="select-field"
            value={status}
            onChange={(e) => { setStatus(e.target.value); setPage(1); }}
            aria-label="Filter by status"
          >
            <option value="">All statuses</option>
            {JOB_STATUSES.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </span>
        <button className="btn btn-ghost" onClick={() => setSortDesc((d) => !d)}>
          {sortDesc ? 'Newest first' : 'Oldest first'}
        </button>
      </div>

      {/* Table */}
      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Job ID</th>
                <th className="th">Title</th>
                <th className="th">Category</th>
                <th className="th">Status</th>
                <th className="th">Homeowner</th>
                <th className="th">Tradie</th>
                <th className="th">Posted</th>
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
                  <td colSpan={8} className="td text-center cell-muted">No jobs found.</td>
                </tr>
              ) : (
                data?.items.map((job) => (
                  <tr key={job.id}>
                    <td className="td mono">
                      <Link to={`/jobs/${job.id}`} className="cell-link">
                        {formatJobId(job.id)}
                      </Link>
                    </td>
                    <td className="td">{job.title}</td>
                    <td className="td cell-muted">{job.category}</td>
                    <td className="td"><StatusBadge status={job.status} /></td>
                    <td className="td cell-muted">{job.homeownerName}</td>
                    <td className="td cell-muted">{job.tradeName ?? '—'}</td>
                    <td className="td cell-muted">
                      {new Date(job.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="td text-right">
                      <Link to={`/jobs/${job.id}`} className="action-link">
                        View
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
            itemLabel="jobs"
            onPageChange={setPage}
          />
        )}
      </div>
    </div>
  );
};
