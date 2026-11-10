/**
 * DescriptionList / InfoRow — responsive label-value pairs.
 *
 * Phone:  label above value (flex-col)
 * sm+:    label left, value right (matches existing .detail-row behaviour)
 *
 * Usage:
 *   <DescriptionList>
 *     <InfoRow label="Email">{user.email}</InfoRow>
 *     <InfoRow label="Joined">{date}</InfoRow>
 *   </DescriptionList>
 */
import React from 'react';

interface InfoRowProps {
  label: string;
  children: React.ReactNode;
  /** Extra class on the value span. */
  valueClassName?: string;
}

export const InfoRow: React.FC<InfoRowProps> = ({ label, children, valueClassName = '' }) => (
  <div className="flex flex-col sm:flex-row sm:items-baseline sm:justify-between gap-1 sm:gap-4 py-[10px] border-b border-[var(--paper-line)] last:border-b-0">
    <span className="text-[13px] text-[var(--ink)] opacity-60 shrink-0">{label}</span>
    <span className={`text-[14px] font-medium text-[var(--ink)] sm:text-right ${valueClassName}`}>
      {children}
    </span>
  </div>
);

interface DescriptionListProps {
  children: React.ReactNode;
  className?: string;
}

export const DescriptionList: React.FC<DescriptionListProps> = ({ children, className = '' }) => (
  <div className={className}>
    {children}
  </div>
);
