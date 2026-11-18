/**
 * StatCard — one headline number (design system: COMPONENTS.md "Stat", kit `.card.stat`).
 *
 * Merges the existing StatCard (with icon) and MetricsCard (without) into one.
 * `hint` makes it the attention variant: accent (or danger, with `accent="red"`) border plus a
 * warn/danger badge carrying the hint text, so attention is never colour-only.
 * When `to` is provided the card renders as a <Link> with a full text label.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';
import { Badge } from './Badge';

interface StatCardProps {
  label: string;
  value: number | string | undefined;
  icon?: LucideIcon;
  /** Icon tile tone: brand (default), green = ok, amber = warn, red = danger. */
  accent?: 'brand' | 'green' | 'amber' | 'red';
  /** Short attention text shown next to the value (e.g. "Needs action"). */
  hint?: string;
  /** Makes the whole card a navigation link. */
  to?: string;
  /** CSS colour value for the number, e.g. 'var(--danger)'. Prefer leaving unset. */
  color?: string;
  ariaLabel?: string;
}

const TILE: Record<NonNullable<StatCardProps['accent']>, string> = {
  brand: '',
  green: 'tile-ok',
  amber: 'tile-warn',
  red: 'tile-danger',
};

const CardBody: React.FC<StatCardProps> = ({ label, value, icon: Icon, accent = 'brand', hint, color }) => (
  <>
    <div className="stat-top">
      {Icon && (
        <span className={`tile tile-sm ${TILE[accent]}`.trim()} aria-hidden="true">
          <Icon size={20} />
        </span>
      )}
      <span className="stat-label grow truncate">{label}</span>
    </div>
    <div className="row between nowrap">
      <div
        className="stat-value truncate min-w-0"
        style={color ? { color } : undefined}
        title={value == null ? undefined : String(value)}
      >
        {value == null ? '—' : typeof value === 'number' ? value.toLocaleString() : value}
      </div>
      {hint && (
        <Badge tone={accent === 'red' ? 'danger' : 'warn'} dot>
          {hint}
        </Badge>
      )}
    </div>
  </>
);

export const StatCard: React.FC<StatCardProps> = (props) => {
  const tone = props.hint ? (props.accent === 'red' ? 'tone-danger' : 'tone-accent') : '';
  const cls = `card stat ${tone}`.trim();

  if (props.to) {
    return (
      <Link
        to={props.to}
        className={cls}
        aria-label={props.ariaLabel ?? `${props.label}: ${props.value ?? 'unavailable'}`}
      >
        <CardBody {...props} />
      </Link>
    );
  }

  return (
    <div className={cls}>
      <CardBody {...props} />
    </div>
  );
};
