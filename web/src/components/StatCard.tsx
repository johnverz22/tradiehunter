import React from 'react';
import type { LucideIcon } from 'lucide-react';

interface StatCardProps {
  label: string;
  value: number | string;
  Icon: LucideIcon;
  accent?: 'brand' | 'green' | 'amber' | 'red';
}

const accentClasses: Record<string, string> = {
  brand: 'bg-[var(--brand-100)] text-[var(--brand-700)]',
  green: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  amber: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  red: 'bg-red-100 text-[var(--red)] dark:bg-red-900/30 dark:text-red-400',
};

export const StatCard: React.FC<StatCardProps> = ({
  label,
  value,
  Icon,
  accent = 'brand',
}) => (
  <div className="bg-paper border border-paper-line rounded-lg p-5 flex items-center gap-4 shadow-sm hover:shadow transition-shadow">
    <div className={`p-3 rounded-lg shrink-0 ${accentClasses[accent]}`}>
      <Icon size={20} aria-hidden="true" />
    </div>
    <div className="min-w-0">
      <p className="text-sm text-ink-soft truncate">{label}</p>
      <p className="text-2xl font-bold text-ink leading-tight tabular-nums">{value}</p>
    </div>
  </div>
);
