/**
 * AuditDiffModal — shows before/after JSON for an audit log entry.
 * On phone: full-screen bottom sheet; horizontal scroll only inside the
 * <pre> blocks (not the page).
 */
import React from 'react';
import { Modal } from '../../../components/Modal';
import type { AuditLogEntry } from '../../../services/adminApi';

function formatDate(iso: string): string {
  try { return new Date(iso).toLocaleString(); }
  catch { return iso; }
}

function prettyJson(raw?: string): string {
  if (!raw) return '—';
  try { return JSON.stringify(JSON.parse(raw), null, 2); }
  catch { return raw; }
}

interface AuditDiffModalProps {
  entry: AuditLogEntry | null;
  onClose: () => void;
}

export const AuditDiffModal: React.FC<AuditDiffModalProps> = ({ entry, onClose }) => (
  <Modal
    open={entry !== null}
    onClose={onClose}
    size="lg"
    title={entry ? `${entry.action} #${entry.id}` : undefined}
    aria-label="Audit log detail"
  >
    {entry && (
      <>
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

        {/* Code blocks: overflow-x-auto is scoped to the pre, not the page */}
        <div className="grid md:grid-cols-2 gap-4">
          <div>
            <h4 className="text-[13px] font-semibold mb-1">Before</h4>
            <pre className="mono text-[12px] bg-[var(--brand-100)] rounded p-3 overflow-x-auto max-h-64 m-0">
              {prettyJson(entry.oldValues)}
            </pre>
          </div>
          <div>
            <h4 className="text-[13px] font-semibold mb-1">After</h4>
            <pre className="mono text-[12px] bg-[var(--brand-100)] rounded p-3 overflow-x-auto max-h-64 m-0">
              {prettyJson(entry.newValues)}
            </pre>
          </div>
        </div>
      </>
    )}
  </Modal>
);
