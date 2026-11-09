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
  <div className="detail-row">
    <span className="detail-label">{label}</span>
    <span className="detail-value">{value}</span>
  </div>
);

export const MetricsCard: React.FC<MetricsCardProps> = ({ label, window: w }) => (
  <div className="card">
    <h3 className="card-title">{label}</h3>
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
