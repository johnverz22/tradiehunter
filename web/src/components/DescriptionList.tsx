/**
 * DescriptionList / InfoRow — label-value pairs as a real <dl> (design system: kit `.dl`).
 *
 * Label left and value right of it from 640 px up; stacked below 640 px (kit CSS).
 * `total` marks the summed row (bolder, used in money lists).
 *
 * Usage:
 *   <DescriptionList>
 *     <InfoRow label="Email">{user.email}</InfoRow>
 *     <InfoRow label="Total" total>{amount}</InfoRow>
 *   </DescriptionList>
 */
import React from 'react';

interface InfoRowProps {
  label: string;
  children: React.ReactNode;
  /** Extra class on the value element (e.g. `mono`, `money`). */
  valueClassName?: string;
  /** The summed row of a money list. */
  total?: boolean;
}

export const InfoRow: React.FC<InfoRowProps> = ({ label, children, valueClassName = '', total }) => (
  <div className={total ? 'total' : undefined}>
    <dt>{label}</dt>
    <dd className={valueClassName || undefined}>{children}</dd>
  </div>
);

interface DescriptionListProps {
  children: React.ReactNode;
  className?: string;
}

export const DescriptionList: React.FC<DescriptionListProps> = ({ children, className = '' }) => (
  <dl className={`dl ${className}`.trim()}>{children}</dl>
);
