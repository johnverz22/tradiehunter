import React, { useState } from 'react';
import { PageHeader } from '../../../components/PageHeader';
import { FilterBar } from '../../../components/FilterBar';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { Field } from '../../../components/Field';
import { Pagination } from '../../../components/Pagination';
import { AuditDiffModal } from '../components/AuditDiffModal';
import { useAuditLogs } from '../hooks/useAuditLogs';
import type { AuditLogEntry } from '../../../services/adminApi';

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

export const AuditLogsPage: React.FC = () => {
  const [action, setAction] = useState('');
  const [userId, setUserId] = useState('');
  const [fromUtc, setFromUtc] = useState('');
  const [toUtc, setToUtc] = useState('');
  const [page, setPage] = useState(1);
  const [selected, setSelected] = useState<AuditLogEntry | null>(null);

  const { data, isLoading, isError, refetch } = useAuditLogs({
    action: action || undefined,
    userId: userId || undefined,
    fromUtc: fromUtc ? new Date(fromUtc).toISOString() : undefined,
    toUtc: toUtc ? new Date(toUtc).toISOString() : undefined,
    page,
    pageSize: 20,
  });

  const activeFiltersCount =
    (action ? 1 : 0) + (userId ? 1 : 0) + (fromUtc ? 1 : 0) + (toUtc ? 1 : 0);

  const handleClear = () => {
    setAction('');
    setUserId('');
    setFromUtc('');
    setToUtc('');
    setPage(1);
    refetch();
  };

  const columns: ColumnDef<AuditLogEntry>[] = [
    {
      key: 'action',
      header: 'Action',
      priority: 'primary',
      cell: (e) => <span className="mono">{e.action}</span>,
    },
    {
      key: 'timestamp',
      header: 'Timestamp',
      priority: 'secondary',
      cell: (e) => (
        <span className="mono muted">{formatDate(e.createdAtUtc)}</span>
      ),
    },
    {
      key: 'actor',
      header: 'Admin / User',
      priority: 'secondary',
      cell: (e) => <span className="mono">{e.userId ?? 'system'}</span>,
    },
    {
      key: 'entity',
      header: 'Entity',
      priority: 'detail',
      cell: (e) => (
        <span className="mono muted">
          {[e.entityType, e.entityId].filter(Boolean).join(' · ') || '—'}
        </span>
      ),
    },
  ];

  const rowActions = (entry: AuditLogEntry): RowAction[] => [
    {
      label: 'View diff',
      onClick: () => setSelected(entry),
      variant: 'ghost',
      primary: true,
    },
  ];

  return (
    <>
      <PageHeader title="Audit logs" description="Every staff action, newest first" />

      {/* Filters: labelled fields (the page has text and date filters, not a single search) */}
      <FilterBar activeFiltersCount={activeFiltersCount} onClear={handleClear}>
        <Field label="Action" className="flex-1 min-w-44">
          {(a11y) => (
            <input
              {...a11y}
              className="field"
              placeholder="e.g. credential.review"
              value={action}
              onChange={(e) => {
                setPage(1);
                setAction(e.target.value);
              }}
              aria-label="Filter by action"
            />
          )}
        </Field>
        <Field label="User ID" className="flex-1 min-w-44">
          {(a11y) => (
            <input
              {...a11y}
              className="field"
              placeholder="Admin / user id"
              value={userId}
              onChange={(e) => {
                setPage(1);
                setUserId(e.target.value);
              }}
              aria-label="Filter by user ID"
            />
          )}
        </Field>
        <Field label="From" className="flex-1 min-w-36">
          {(a11y) => (
            <input
              {...a11y}
              className="field"
              type="date"
              value={fromUtc}
              onChange={(e) => {
                setPage(1);
                setFromUtc(e.target.value);
              }}
              aria-label="Filter from date"
            />
          )}
        </Field>
        <Field label="To" className="flex-1 min-w-36">
          {(a11y) => (
            <input
              {...a11y}
              className="field"
              type="date"
              value={toUtc}
              onChange={(e) => {
                setPage(1);
                setToUtc(e.target.value);
              }}
              aria-label="Filter to date"
            />
          )}
        </Field>
      </FilterBar>

      {/* Table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(e) => e.id}
        isLoading={isLoading}
        error={isError ? 'Failed to load audit logs.' : undefined}
        rowActions={rowActions}
        empty="No audit entries match these filters."
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="entries"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

      <AuditDiffModal entry={selected} onClose={() => setSelected(null)} />
    </>
  );
};
