/**
 * StatGrid — responsive grid container for StatCard components (kit `.grid.cN`).
 *
 * Design system: stat rows are 4 columns, then 2 below 1024 px, then 1 below 640 px.
 * `cols.desktop` (2–4, default 4) sets the wide layout; `cols.phone` no longer applies
 * (the kit steps down on its own).
 */
import React from 'react';

interface StatGridProps {
  children: React.ReactNode;
  /** Override the wide column count (2, 3 or 4). Default 4. */
  cols?: { phone?: number; desktop?: number };
}

export const StatGrid: React.FC<StatGridProps> = ({ children, cols }) => {
  const desktop = cols?.desktop === 2 || cols?.desktop === 3 ? cols.desktop : 4;
  return <div className={`grid c${desktop}`}>{children}</div>;
};
