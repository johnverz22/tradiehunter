/**
 * Badge — short status or count (design system: COMPONENTS.md "Badge").
 * Text carries the meaning; the dot and colour only reinforce it.
 */
import React from 'react';

export type BadgeTone = 'neutral' | 'info' | 'ok' | 'warn' | 'danger';

interface BadgeProps {
  tone?: BadgeTone;
  /** Leading status dot. Used on status badges in tables and headers. */
  dot?: boolean;
  /** `lg` is the page-header size. */
  size?: 'sm' | 'lg';
  className?: string;
  children: React.ReactNode;
}

export const Badge: React.FC<BadgeProps> = ({
  tone = 'neutral',
  dot = false,
  size = 'sm',
  className = '',
  children,
}) => (
  <span
    className={[
      'badge',
      tone === 'neutral' ? '' : `badge-${tone}`,
      dot ? 'dot' : '',
      size === 'lg' ? 'badge-lg' : '',
      className,
    ]
      .filter(Boolean)
      .join(' ')}
  >
    {children}
  </span>
);
