import React from 'react';

interface InfoRowProps {
  label: string;
  value: string;
  mono?: boolean;
}

export const InfoRow: React.FC<InfoRowProps> = ({ label, value, mono }) => (
  <div className="flex items-start justify-between gap-4 text-sm">
    <span className="text-ink-soft shrink-0">{label}</span>
    <span
      className={`text-right text-ink break-all ${mono ? 'font-mono text-xs' : ''}`}
    >
      {value}
    </span>
  </div>
);
