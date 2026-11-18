/**
 * AuditDiffModal — shows before/after JSON for an audit log entry.
 * On phone: full-screen bottom sheet; horizontal scroll only inside the
 * <pre> blocks (not the page).
 */
import React from 'react';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
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
      <div className="stack">
        <DescriptionList>
          <InfoRow label="Timestamp" valueClassName="mono">
            {formatDate(entry.createdAtUtc)}
          </InfoRow>
          <InfoRow label="Actor" valueClassName="mono">
            {entry.userId ?? 'system'}
          </InfoRow>
          <InfoRow label="Entity" valueClassName="mono">
            {[entry.entityType, entry.entityId].filter(Boolean).join(' · ') || '—'}
          </InfoRow>
          {entry.ipAddress && (
            <InfoRow label="IP" valueClassName="mono">
              {entry.ipAddress}
            </InfoRow>
          )}
        </DescriptionList>

        {/* Code blocks: overflow-x is scoped to the pre, not the page */}
        <div className="grid c2">
          <div className="stack">
            <h3 className="diff-title">Before</h3>
            <pre className="diff-pre" tabIndex={0}>
              {prettyJson(entry.oldValues)}
            </pre>
          </div>
          <div className="stack">
            <h3 className="diff-title">After</h3>
            <pre className="diff-pre" tabIndex={0}>
              {prettyJson(entry.newValues)}
            </pre>
          </div>
        </div>
      </div>
    )}
  </Modal>
);
