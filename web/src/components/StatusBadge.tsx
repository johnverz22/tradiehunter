import React from 'react';
import { Badge, type BadgeTone } from './Badge';

interface StatusBadgeProps {
  status: string;
  /** `lg` is the page-header size. */
  size?: 'sm' | 'lg';
  className?: string;
}

/** Status map: docs/design/web/COMPONENTS.md "Status map". Unknown statuses are neutral. */
const statusTones: Record<string, BadgeTone> = {
  // ok
  Booked: 'ok',
  Active: 'ok',
  Verified: 'ok',
  Resolved: 'ok',
  // info
  Requested: 'info',
  InProgress: 'info',
  Superadmin: 'info',
  Staff: 'info',
  Tradie: 'info',
  // warn
  AwaitingPayment: 'warn',
  PaymentReview: 'warn',
  AwaitingConfirmation: 'warn',
  Unverified: 'warn',
  Open: 'warn',
  // danger
  Cancelled: 'danger',
  Disputed: 'danger',
  Escalated: 'danger',
  // neutral
  Completed: 'neutral',
  Expired: 'neutral',
  Homeowner: 'neutral',
  Inactive: 'neutral',
  None: 'neutral',
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  size = 'sm',
  className = '',
}) => (
  <Badge tone={statusTones[status] ?? 'neutral'} dot size={size} className={className}>
    {status}
  </Badge>
);
