/**
 * StatCard — unified stat/metric card.
 *
 * Merges the existing StatCard (with Icon) and MetricsCard (without) into one.
 * Value text scales down on phone and never overflows via truncate + min-w-0.
 * When `to` is provided the card renders as a <Link>.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';

interface StatCardProps {
  label: string;
  value: number | string | undefined;
  icon?: LucideIcon;
  accent?: 'brand' | 'green' | 'amber' | 'red';
  /** Small label shown top-right (e.g. "Needs action"). */
  hint?: string;
  /** Makes the whole card a navigation link. */
  to?: string;
  /** CSSvar string for value colour override, e.g. 'var(--red-ink)'. */
  color?: string;
  ariaLabel?: string;
}

const accentClasses: Record<string, string> = {
  brand: 'bg-[var(--brand-100)] text-[var(--brand-700)]',
  green: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
  amber: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
  red:   'bg-red-100 text-[var(--red)] dark:bg-red-900/30 dark:text-red-400',
};

const CardBody: React.FC<StatCardProps> = ({ label, value, icon: Icon, accent = 'brand', hint, color }) => (
  <>
    <div className="flex items-center justify-between mb-2 gap-2">
      {Icon && (
        <div className={`p-3 rounded-lg shrink-0 ${accentClasses[accent]}`}>
          <Icon size={20} aria-hidden="true" />
        </div>
      )}
      <div className="flex items-center justify-between flex-1 gap-2 min-w-0">
        <span className="text-[13px] text-[var(--ink)] opacity-60 truncate">{label}</span>
        {hint && (
          <span className="text-[11px] font-semibold uppercase text-[var(--amber-ink)] shrink-0">
            {hint}
          </span>
        )}
      </div>
    </div>
    <div
      className="text-[22px] sm:text-[28px] font-semibold leading-tight truncate min-w-0"
      style={{ fontFamily: 'var(--font-mono)', color: color ?? 'var(--ink)' }}
      title={value == null ? undefined : String(value)}
    >
      {value == null ? '—' : typeof value === 'number' ? value.toLocaleString() : value}
    </div>
  </>
);

export const StatCard: React.FC<StatCardProps> = (props) => {
  const baseClass =
    'card !p-5 block hover:shadow-md transition-shadow min-w-0';

  if (props.to) {
    return (
      <Link
        to={props.to}
        className={baseClass}
        aria-label={props.ariaLabel ?? `${props.label}: ${props.value ?? 'unavailable'}`}
      >
        <CardBody {...props} />
      </Link>
    );
  }

  return (
    <div className={baseClass}>
      <CardBody {...props} />
    </div>
  );
};
