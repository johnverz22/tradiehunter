import React from 'react';

interface StatusBadgeProps {
  status: string;
  className?: string;
}

const statusStyles: Record<string, string> = {
  // Job statuses
  Draft:       'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
  Requested:   'bg-[var(--brand-100)] text-[var(--brand-700)]',
  Matching:    'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  Matched:     'bg-[var(--brand-100)] text-[var(--brand-700)]',
  Confirmed:   'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  InProgress:  'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
  Complete:    'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300',
  Cancelled:   'bg-red-100 text-[var(--red)] dark:bg-red-900/30 dark:text-red-400',
  // User roles
  Admin:       'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400',
  Homeowner:   'bg-[var(--brand-100)] text-[var(--brand-700)]',
  Tradie:      'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  // Dispute statuses
  Open:        'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  Resolved:    'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  Escalated:   'bg-red-100 text-[var(--red)] dark:bg-red-900/30 dark:text-red-400',
  None:        'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400',
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({ status, className = '' }) => {
  const style = statusStyles[status] ?? 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400';
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${style} ${className}`}
    >
      {status}
    </span>
  );
};
