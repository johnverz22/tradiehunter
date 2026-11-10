/**
 * StatGrid — responsive grid container for StatCard components.
 *
 * phone/tablet: 2 columns
 * desktop:      4 columns
 */
import React from 'react';

interface StatGridProps {
  children: React.ReactNode;
  /** Override column count. Defaults: 2 on phone/tablet, 4 on desktop. */
  cols?: { phone?: number; desktop?: number };
}

export const StatGrid: React.FC<StatGridProps> = ({ children, cols }) => {
  const phoneCols   = cols?.phone   ?? 2;
  const desktopCols = cols?.desktop ?? 4;

  // Map column count to Tailwind classes
  const phoneClass   = `grid-cols-${phoneCols}`;
  const desktopClass = `lg:grid-cols-${desktopCols}`;

  return (
    <div className={`grid ${phoneClass} ${desktopClass} gap-4`}>
      {children}
    </div>
  );
};
