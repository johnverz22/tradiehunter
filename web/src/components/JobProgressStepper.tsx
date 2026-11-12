/**
 * JobProgressStepper
 *
 * 4-step horizontal stepper mirroring the mobile CompactProgressBar.
 * Steps: Requested → Booked → In progress → Done.
 *
 * Visual rules
 * ───────────────────────────────────────────────────────────────────────────
 * • Connector for step i fills when step i+1 is reached.
 * • The last step (Done) has no right-hand connector.
 * • Terminal states (Cancelled / Expired / Disputed) recolour only the
 *   reached dot; completed-before-that connectors stay brand-filled.
 * • 200ms CSS transition on all state changes (skipped under
 *   prefers-reduced-motion).
 * • ARIA: role="list" / role="listitem" / aria-current="step" with an sr-only
 *   text summary.
 */

import React from 'react';
import { getJobProgress } from '../utils/jobProgress';
import type { AdminStatusHistory } from '../services/adminApi';

interface Props {
  status: string;
  statusHistory: AdminStatusHistory[];
  /** Optional "Updated X ago" caption rendered beneath the stepper. */
  updatedCaption?: React.ReactNode;
}

export const JobProgressStepper: React.FC<Props> = ({
  status,
  statusHistory,
  updatedCaption,
}) => {
  const progress = getJobProgress(status, statusHistory);
  const { steps, currentIndex, state, summary } = progress;

  return (
    <div className="stepper overflow-x-auto" aria-label="Job progress">
      {/* Screen-reader summary */}
      <span className="sr-only">{summary}</span>

      <ol
        role="list"
        className="flex items-start min-w-[320px] w-full"
        aria-label="Job progress steps"
      >
        {steps.map((step, i) => {
          const isActive   = i === currentIndex;
          const isPast     = i < currentIndex;
          const isLast     = i === steps.length - 1;

          // Determine dot / connector colouring.
          // A connector fills when the *next* step is reached (i.e. i < currentIndex
          // for active jobs, or i < currentIndex for terminal jobs — connector
          // doesn't go into the terminal dot).
          const connectorFilled = !isLast && i < currentIndex;

          // Dot state class
          let dotClass = 'step-dot';
          if (isPast || (isActive && state === 'done')) {
            dotClass += ' step-dot--done';
          } else if (isActive) {
            dotClass += ` step-dot--${state}`; // active | cancelled | expired | disputed
          }

          // Label state class
          let labelClass = 'step-label';
          if (isActive) {
            labelClass += ` step-label--${state}`;
          } else if (isPast || state === 'done') {
            labelClass += ' step-label--past';
          }

          return (
            <li
              key={step.label}
              role="listitem"
              aria-current={isActive ? 'step' : undefined}
              className="step"
            >
              {/* Connector line to the right (all steps except last) */}
              {!isLast && (
                <div
                  className={`step-line${connectorFilled ? ' step-line--filled' : ''}`}
                  aria-hidden="true"
                />
              )}

              {/* Dot */}
              <div className={dotClass} aria-hidden="true" />

              {/* Label + optional sublabel */}
              <div className={labelClass}>
                {isActive && (state === 'cancelled' || state === 'expired' || state === 'disputed')
                  ? status   // "Cancelled" / "Expired" / "Disputed"
                  : step.label}
                {isActive && progress.sublabel && (
                  <div className="step-sublabel">{progress.sublabel}</div>
                )}
              </div>
            </li>
          );
        })}
      </ol>

      {updatedCaption && (
        <div className="step-updated-caption">{updatedCaption}</div>
      )}
    </div>
  );
};
