import React from 'react';
import type { MetricsWindow } from '../../../services/adminApi';

interface MetricsCardProps {
  label: string;
  window: MetricsWindow;
}

interface MetricRowProps {
  label: string;
  value: string;
}

const MetricRow: React.FC<MetricRowProps> = ({ label, value }) => (
  <div className="flex items-center justify-between py-2 border-b border-[var(--paper-line)] last:border-0">
    <span className="text-sm text-[var(--ink-soft)]">{label}</span>
    <span className="text-sm font-semibold text-[var(--ink)]">{value}</span>
  </div>
);

export const MetricsCard: React.FC<MetricsCardProps> = ({ label, window: w }) => (
  <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded-lg p-5">
    <h3 className="text-sm font-semibold text-[var(--ink)] mb-3">{label}</h3>
    <MetricRow label="Activation rate" value={`${w.activationRatePct}%`} />
    <MetricRow
      label="Avg match→confirm"
      value={`${w.avgMatchToConfirmationHours.toFixed(1)} h`}
    />
    <MetricRow label="Tradie response rate" value={`${w.tradieResponseRatePct}%`} />
    <MetricRow label="Review completion" value={`${w.reviewCompletionRatePct}%`} />
    <MetricRow label="Total jobs" value={w.totalJobs.toLocaleString()} />
    <MetricRow label="Total signups" value={w.totalSignups.toLocaleString()} />
  </div>
);
