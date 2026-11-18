import React from 'react';
import type { PayoutBatchStatus, PayoutStatus } from '../../../services/adminApi';
import { Badge, type BadgeTone } from '../../../components/Badge';

const PAYOUT_TONE: Record<PayoutStatus, BadgeTone> = {
  Pending: 'warn',
  Scheduled: 'info',
  Processed: 'ok',
  Failed: 'danger',
};

const BATCH_TONE: Record<PayoutBatchStatus, BadgeTone> = {
  Open: 'info',
  Processing: 'warn',
  Completed: 'ok',
};

export const PayoutStatusBadge: React.FC<{ status: PayoutStatus }> = ({ status }) => (
  <Badge tone={PAYOUT_TONE[status] ?? 'neutral'} dot>
    {status}
  </Badge>
);

export const BatchStatusBadge: React.FC<{ status: PayoutBatchStatus }> = ({ status }) => (
  <Badge tone={BATCH_TONE[status] ?? 'neutral'} dot>
    {status}
  </Badge>
);
