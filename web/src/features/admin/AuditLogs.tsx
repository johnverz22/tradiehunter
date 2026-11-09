import React from 'react';
import { AuditLogsPage } from '../audit/pages/AuditLogsPage';

/**
 * P8-07: spec path (`src/features/admin/AuditLogs.tsx`).
 * Thin re-export so the audit page lives with the other feature slices
 * while the spec-referenced path stays valid.
 */
export const AuditLogs: React.FC = () => <AuditLogsPage />;

export default AuditLogs;
