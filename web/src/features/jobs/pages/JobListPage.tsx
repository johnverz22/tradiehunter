import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Search } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { FilterBar } from '../../../components/FilterBar';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { StatusBadge } from '../../../components/StatusBadge';
import { Pagination } from '../../../components/Pagination';
import { Button } from '../../../components/Button';
import { useJobList } from '../hooks/useJobs';
import type { AdminJobSummary } from '../../../services/adminApi';

const PAGE_SIZE = 20;

const JOB_STATUSES = [
  'Draft', 'Requested', 'Matching', 'Matched',
  'Confirmed', 'InProgress', 'Complete', 'Cancelled',
];

const formatJobId = (id: number) => `JOB-${String(id).padStart(5, '0')}`;

export const JobListPage: React.FC = () => {
  const navigate = useNavigate();
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

  const activeFiltersCount = status ? 1 : 0;

  const columns: ColumnDef<AdminJobSummary>[] = [
    {
      key: 'id',
      header: 'Job ID',
      priority: 'detail',
      cell: (job) => (
        <span className="mono">
          <Link to={`/jobs/${job.id}`} className="cell-link">
            {formatJobId(job.id)}
          </Link>
        </span>
      ),
    },
    {
      key: 'title',
      header: 'Title',
      priority: 'primary',
      cell: (job) => (
        <Link to={`/jobs/${job.id}`} className="cell-link">
          {job.title}
        </Link>
      ),
    },
    {
      key: 'category',
      header: 'Category',
      priority: 'detail',
      cell: (job) => <span className="muted">{job.category}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (job) => <StatusBadge status={job.status} />,
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (job) => <span className="muted">{job.homeownerName}</span>,
    },
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'detail',
      cell: (job) => <span className="muted">{job.tradeName ?? '—'}</span>,
    },
    {
      key: 'createdAt',
      header: 'Posted',
      priority: 'secondary',
      cell: (job) => (
        <span className="muted">
          {new Date(job.createdAtUtc).toLocaleDateString()}
        </span>
      ),
    },
  ];

  const rowActions = (job: AdminJobSummary): RowAction[] => [
    {
      label: 'View',
      onClick: () => navigate(`/jobs/${job.id}`),
      variant: 'ghost',
      primary: true,
    },
  ];

  return (
    <>
      <PageHeader title="Jobs" description="Job list and status monitoring" />

      {/* Filters */}
      <FilterBar
        activeFiltersCount={activeFiltersCount}
        onClear={() => {
          setStatus('');
          setPage(1);
        }}
      >
        <label className="input-icon">
          <span className="sr-only">Search jobs by title or address</span>
          <Search size={20} aria-hidden="true" />
          <input
            type="search"
            className="field"
            placeholder="Search title or address…"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
          />
        </label>
        <span className="select-wrap">
          <select
            className="select"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            aria-label="Filter by status"
          >
            <option value="">All statuses</option>
            {JOB_STATUSES.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </span>
        <Button kind="ghost" onClick={() => setSortDesc((d) => !d)}>
          {sortDesc ? 'Newest first' : 'Oldest first'}
        </Button>
      </FilterBar>

      {/* Table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(j) => j.id}
        onRowClick={(j) => navigate(`/jobs/${j.id}`)}
        isLoading={isLoading}
        rowActions={rowActions}
        empty="No jobs found."
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="jobs"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />
    </>
  );
};
