import React from 'react';

type Tone = 'green' | 'amber' | 'red' | 'blue' | 'gray' | 'brand';

interface StatusBadgeProps {
  status: string;
  /** `lg` matches the mockup's page-header badge. */
  size?: 'sm' | 'lg';
  className?: string;
}

const statusTones: Record<string, Tone> = {
  // Job statuses (v1.2)
  Requested: 'brand',
  AwaitingPayment: 'amber',
  PaymentReview: 'amber',
  Booked: 'green',
  InProgress: 'blue',
  AwaitingConfirmation: 'amber',
  Completed: 'gray',
  Cancelled: 'red',
  Expired: 'gray',
  Disputed: 'red',
  
  // User roles (v1.2)
  Superadmin: 'brand',
  Staff: 'brand',
  Homeowner: 'gray',
  Tradie: 'blue',
  
  // Account state
  Active: 'green',
  Inactive: 'gray',
  Verified: 'green',
  Unverified: 'amber',
  
  // Dispute statuses
  Open: 'amber',
  Resolved: 'green',
  Escalated: 'red',
  None: 'gray',
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  size = 'sm',
  className = '',
}) => {
  const tone = statusTones[status] ?? 'gray';

  return (
    <span
      className={`pill pill-${tone} ${size === 'lg' ? 'pill-lg' : ''} ${className}`.trim()}
    >
      {status}
    </span>
  );
};
