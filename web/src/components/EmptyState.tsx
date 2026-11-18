/**
 * EmptyState — say what is empty and what to do next
 * (design system: COMPONENTS.md "Empty state").
 */
import React from 'react';

interface EmptyStateProps {
  title: string;
  /** One short sentence: why it is empty or what happens next. */
  children?: React.ReactNode;
  /** Decorative icon shown in a tile, e.g. `<Inbox size={26} />`. */
  icon?: React.ReactNode;
  /** Optional next step, usually a `Button`. */
  action?: React.ReactNode;
  className?: string;
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  title,
  children,
  icon,
  action,
  className = '',
}) => (
  <div className={`empty ${className}`.trim()}>
    {icon ? (
      <span className="tile" aria-hidden="true">
        {icon}
      </span>
    ) : null}
    <h3>{title}</h3>
    {children ? <p>{children}</p> : null}
    {action ? <div className="mt-2">{action}</div> : null}
  </div>
);
