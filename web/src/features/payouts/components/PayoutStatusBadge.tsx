import React from 'react';
import type { PayoutBatchStatus, PayoutStatus } from '../../../services/adminApi';

const PAYOUT_TONE: Record<PayoutStatus, string> = {
  Pending: 'pill-amber',
  Scheduled: 'pill-blue',
  Processed: 'pill-green',
  Failed: 'pill-red',
};

const BATCH_TONE: Record<PayoutBatchStatus, string> = {
  Open: 'pill-blue',
  Processing: 'pill-amber',
  Completed: 'pill-green',
};

export const PayoutStatusBadge: React.FC<{ status: PayoutStatus }> = ({ status }) => (
  <span className={`pill ${PAYOUT_TONE[status] ?? 'pill-gray'}`}>{status}</span>
);

export const BatchStatusBadge: React.FC<{ status: PayoutBatchStatus }> = ({ status }) => (
  <span className={`pill ${BATCH_TONE[status] ?? 'pill-gray'}`}>{status}</span>
);
