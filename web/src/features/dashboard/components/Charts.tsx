import React from 'react';

interface BarChartProps {
  data: Record<string, number>;
  label?: string;
  colorVar?: string;
}

/**
 * Minimal bar chart built with CSS only — no external charting library required.
 * Sorts entries by value descending.
 */
export const BarChart: React.FC<BarChartProps> = ({
  data,
  label,
  colorVar = '--brand-500',
}) => {
  const entries = Object.entries(data);
  const max = Math.max(...entries.map(([, v]) => v), 1);

  return (
    <div>
      {label && (
        <p className="text-xs font-medium text-[var(--ink-soft)] mb-3">{label}</p>
      )}
      <div className="flex flex-col gap-2">
        {entries.map(([key, value]) => (
          <div key={key} className="flex items-center gap-3 text-sm">
            <span className="w-24 shrink-0 text-xs text-[var(--ink-soft)] truncate">{key}</span>
            <div className="flex-1 h-5 bg-[var(--paper-line)] rounded overflow-hidden">
              <div
                className="h-full rounded transition-all duration-300"
                style={{
                  width: `${(value / max) * 100}%`,
                  backgroundColor: `var(${colorVar})`,
                }}
                role="meter"
                aria-valuenow={value}
                aria-valuemin={0}
                aria-valuemax={max}
                aria-label={`${key}: ${value}`}
              />
            </div>
            <span className="w-8 text-right text-xs font-medium text-[var(--ink)]">{value}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

/**
 * Spark-line style chart for signups over time.
 * Renders a simple time series using inline SVG.
 */
export const SparkLine: React.FC<{ data: Record<string, number>; label?: string }> = ({
  data,
  label,
}) => {
  const values = Object.values(data);
  const max = Math.max(...values, 1);
  const width = 400;
  const height = 60;
  const padding = 4;

  const points = values
    .map((v, i) => {
      const x = padding + (i / (values.length - 1)) * (width - padding * 2);
      const y = height - padding - ((v / max) * (height - padding * 2));
      return `${x},${y}`;
    })
    .join(' ');

  return (
    <div>
      {label && (
        <p className="text-xs font-medium text-[var(--ink-soft)] mb-2">{label}</p>
      )}
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full h-16"
        aria-hidden="true"
        preserveAspectRatio="none"
      >
        <polyline
          points={points}
          fill="none"
          stroke="var(--brand-500)"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <div className="flex justify-between text-xs text-[var(--ink-soft)] mt-1">
        <span>{Object.keys(data)[0]?.slice(5) ?? ''}</span>
        <span>{Object.keys(data).at(-1)?.slice(5) ?? ''}</span>
      </div>
    </div>
  );
};
