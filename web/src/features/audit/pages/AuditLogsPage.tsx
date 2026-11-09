import React, { useState } from 'react';
import { useAuditLogs } from '../hooks/useAuditLogs';
import type { AuditLogEntry } from '../../../services/adminApi';

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString();
  } catch {
    return iso;
  }
}

function prettyJson(raw?: string): string {
  if (!raw) return '—';
  try {
    return JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    return raw;
  }
}

const DiffModal: React.FC<{ entry: AuditLogEntry | null; onClose: () => void }> = ({
  entry,
  onClose,
}) => {
  if (!entry) return null;
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Audit log detail"
    >
      <div
        className="card max-w-2xl w-full max-h-[80vh] overflow-auto !p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-4">
          <h3
            className="text-[16px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            {entry.action}{' '}
            <span className="text-[var(--ink-soft)] font-normal">
              #{entry.id}
            </span>
          </h3>
          <button onClick={onClose} className="btn btn-ghost !py-1 !px-3" aria-label="Close">
            ✕
          </button>
        </div>
        <dl className="text-[13px] space-y-2 mb-4">
          <div className="flex gap-2">
            <dt className="text-[var(--ink-soft)] w-24 shrink-0">Timestamp</dt>
            <dd className="mono">{formatDate(entry.createdAtUtc)}</dd>
          </div>
          <div className="flex gap-2">
            <dt className="text-[var(--ink-soft)] w-24 shrink-0">Actor</dt>
            <dd className="mono">{entry.userId ?? 'system'}</dd>
          </div>
          <div className="flex gap-2">
            <dt className="text-[var(--ink-soft)] w-24 shrink-0">Entity</dt>
            <dd className="mono">
              {[entry.entityType, entry.entityId].filter(Boolean).join(' · ') || '—'}
            </dd>
          </div>
          {entry.ipAddress && (
            <div className="flex gap-2">
              <dt className="text-[var(--ink-soft)] w-24 shrink-0">IP</dt>
              <dd className="mono">{entry.ipAddress}</dd>
            </div>
          )}
        </dl>
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <h4 className="text-[13px] font-semibold mb-1">Before</h4>
            <pre className="mono text-[12px] bg-[var(--brand-100)] rounded p-3 overflow-auto max-h-64">
              {prettyJson(entry.oldValues)}
            </pre>
          </div>
          <div>
            <h4 className="text-[13px] font-semibold mb-1">After</h4>
            <pre className="mono text-[12px] bg-[var(--brand-100)] rounded p-3 overflow-auto max-h-64">
              {prettyJson(entry.newValues)}
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
};

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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1
          className="text-[28px] font-bold text-[var(--ink)]"
          style={{ fontFamily: 'var(--font-display)' }}
        >
          Audit Logs
        </h1>
        <span className="pill pill-brand">Admin</span>
      </div>

      {/* ── Filters ─────────────────────────────────────────── */}
      <div className="card !p-4 flex flex-wrap gap-3 items-end">
        <label className="flex flex-col gap-1 text-[13px]">
          <span className="text-[var(--ink-soft)]">Action</span>
          <input
            className="field"
            placeholder="e.g. credential.review"
            value={action}
            onChange={(e) => {
              setPage(1);
              setAction(e.target.value);
            }}
            aria-label="Filter by action"
          />
        </label>
        <label className="flex flex-col gap-1 text-[13px]">
          <span className="text-[var(--ink-soft)]">User ID</span>
          <input
            className="field"
            placeholder="Admin / user id"
            value={userId}
            onChange={(e) => {
              setPage(1);
              setUserId(e.target.value);
            }}
            aria-label="Filter by user ID"
          />
        </label>
        <label className="flex flex-col gap-1 text-[13px]">
          <span className="text-[var(--ink-soft)]">From</span>
          <input
            className="field"
            type="date"
            value={fromUtc}
            onChange={(e) => {
              setPage(1);
              setFromUtc(e.target.value);
            }}
            aria-label="Filter from date"
          />
        </label>
        <label className="flex flex-col gap-1 text-[13px]">
          <span className="text-[var(--ink-soft)]">To</span>
          <input
            className="field"
            type="date"
            value={toUtc}
            onChange={(e) => {
              setPage(1);
              setToUtc(e.target.value);
            }}
            aria-label="Filter to date"
          />
        </label>
        <button
          className="btn btn-ghost"
          onClick={() => {
            setAction('');
            setUserId('');
            setFromUtc('');
            setToUtc('');
            setPage(1);
            refetch();
          }}
        >
          Clear
        </button>
      </div>

      {/* ── Table ───────────────────────────────────────────── */}
      <div className="table-container">
        <table className="table">
          <thead>
            <tr>
              {['Timestamp', 'Admin / User', 'Action', 'Entity', 'Detail'].map((h) => (
                <th key={h} className="th">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={5} className="td text-center cell-muted">
                  Loading audit logs…
                </td>
              </tr>
            ) : isError || !data ? (
              <tr>
                <td colSpan={5} className="td text-center cell-muted">
                  Failed to load audit logs.
                </td>
              </tr>
            ) : data.items.length === 0 ? (
              <tr>
                <td colSpan={5} className="td text-center cell-muted">
                  No audit entries match these filters.
                </td>
              </tr>
            ) : (
              data.items.map((e) => (
                <tr key={e.id}>
                  <td className="td mono cell-muted">{formatDate(e.createdAtUtc)}</td>
                  <td className="td mono">{e.userId ?? 'system'}</td>
                  <td className="td mono">{e.action}</td>
                  <td className="td mono cell-muted">
                    {[e.entityType, e.entityId].filter(Boolean).join(' · ') || '—'}
                  </td>
                  <td className="td">
                    <button className="action-link" onClick={() => setSelected(e)}>
                      View diff
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* ── Pagination ──────────────────────────────────────── */}
      {data && data.totalPages > 1 && (
        <div className="flex items-center gap-3 text-[13px]">
          <button
            className="btn btn-ghost !py-1 !px-3"
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
          >
            ← Prev
          </button>
          <span className="text-[var(--ink-soft)]">
            Page {data.page} of {data.totalPages} ({data.totalCount} entries)
          </span>
          <button
            className="btn btn-ghost !py-1 !px-3"
            disabled={page >= data.totalPages}
            onClick={() => setPage((p) => p + 1)}
          >
            Next →
          </button>
        </div>
      )}

      <DiffModal entry={selected} onClose={() => setSelected(null)} />
    </div>
  );
};
