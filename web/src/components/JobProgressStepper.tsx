/**
 * JobProgressStepper
 *
 * 4-step stepper mirroring the mobile CompactProgressBar.
 * Steps: Requested → Booked → In progress → Done.
 *
 * Renders the design-system kit stepper (`.stepper`, COMPONENTS.md):
 * • Item states: `done` (check icon), `current`, `halt` (cross icon), and
 *   no class for steps not yet reached. Each step draws one connector back to
 *   the previous step, so a connector is coloured by the state of the step it
 *   leads into (success into done/current, danger into a halted step).
 * • Terminal states (Cancelled / Expired / Disputed) halt the step the job
 *   had reached; the label shows the status text, so state is never colour
 *   alone.
 * • The kit switches to a vertical layout below 768 px.
 * • ARIA: `<ol role="list">` (keeps list semantics when list-style is none),
 *   `aria-current="step"` on the active item, and an sr-only text summary.
 */

import React from 'react';
import { Check, X } from 'lucide-react';
import { getJobProgress } from '../utils/jobProgress';
import type { AdminStatusHistory } from '../services/adminApi';

interface Props {
  status: string;
  statusHistory: AdminStatusHistory[];
}

export const JobProgressStepper: React.FC<Props> = ({
  status,
  statusHistory,
}) => {
  const progress = getJobProgress(status, statusHistory);
  const { steps, currentIndex, state, summary } = progress;
  const isHalted = state === 'cancelled' || state === 'expired' || state === 'disputed';

  return (
    // The card keeps the surface the legacy shim used to give this component;
    // the job_detail frame also places the stepper in a card.
    <div className="card">
      <div className="card-body">
        {/* Screen-reader summary */}
        <span className="sr-only">{summary}</span>

        <ol role="list" className="stepper" aria-label="Job progress">
          {steps.map((step, i) => {
            const isActive = i === currentIndex;
            const isPast = i < currentIndex;

            // Kit item state: done | current | halt | (none = not reached).
            // A completed job marks its last step done, not current.
            let itemState = '';
            if (isPast || (isActive && state === 'done')) itemState = 'done';
            else if (isActive && isHalted) itemState = 'halt';
            else if (isActive) itemState = 'current';

            return (
              <li
                key={step.label}
                className={itemState || undefined}
                aria-current={isActive ? 'step' : undefined}
              >
                <span className="dot">
                  {itemState === 'done' && <Check size={12} strokeWidth={2} aria-hidden="true" />}
                  {itemState === 'halt' && <X size={12} strokeWidth={2} aria-hidden="true" />}
                </span>
                <span>
                  {isActive && isHalted
                    ? status // "Cancelled" / "Expired" / "Disputed"
                    : step.label}
                  {isActive && progress.sublabel && <small>{progress.sublabel}</small>}
                </span>
              </li>
            );
          })}
        </ol>

      </div>
    </div>
  );
};
