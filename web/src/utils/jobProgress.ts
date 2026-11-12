/**
 * jobProgress.ts
 *
 * Maps the backend JobStatus enum to the 4-step progress stepper shown on
 * the Job Detail page.  This file is the single source of truth for the
 * mapping, mirroring mobile/lib/views/widgets/compact_progress_bar.dart.
 *
 * Steps (1-based):
 *   1 → Requested   (also covers AwaitingPayment, PaymentReview)
 *   2 → Booked
 *   3 → In progress (also covers AwaitingConfirmation)
 *   4 → Done        (Completed)
 *
 * Terminal statuses (Cancelled, Expired, Disputed) derive their reached step
 * from the status history: the last non-terminal `toStatus` before the
 * terminal transition.  Falls back to step 1 if the history is empty.
 */

import type { AdminStatusHistory } from '../services/adminApi';

// ── Types ─────────────────────────────────────────────────────────────────────

export interface StepInfo {
  label: string;
  /** 0-based index of this step. */
  index: number;
}

export type StepState =
  | 'pending'    // not yet reached
  | 'done'       // completed and passed
  | 'active'     // currently at this step
  | 'cancelled'  // reached, but job cancelled here
  | 'expired'    // reached, but job expired here
  | 'disputed';  // reached, but job is disputed here

export interface JobProgressResult {
  /** The 4 ordered steps. */
  steps: StepInfo[];
  /** 0-based index of the step the job is currently at. */
  currentIndex: number;
  /** State of the *active/terminal* step (all others are 'done' or 'pending'). */
  state: StepState;
  /** Short label for the active state, e.g. "Booked", "Cancelled". */
  label: string;
  /**
   * Optional sub-label surfaced under the active step dot, e.g.
   * "Awaiting payment", "Payment review", "Awaiting confirmation".
   * null for the common case where no sub-label is needed.
   */
  sublabel: string | null;
  /** Screen-reader summary: "Step 3 of 4, In progress". */
  summary: string;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const STEPS: StepInfo[] = [
  { label: 'Requested',   index: 0 },
  { label: 'Booked',      index: 1 },
  { label: 'In progress', index: 2 },
  { label: 'Done',        index: 3 },
];

const TERMINAL_STATUSES = new Set(['Cancelled', 'Expired', 'Disputed']);

/** Maps each active backend status to a 0-based step index. */
const ACTIVE_STEP: Record<string, number> = {
  Requested:            0,
  AwaitingPayment:      0,
  PaymentReview:        0,
  Booked:               1,
  InProgress:           2,
  AwaitingConfirmation: 2,
  Completed:            3,
};

/** Human sublabel for substatus stages (shown under the active dot). */
const SUBLABEL: Record<string, string> = {
  AwaitingPayment:      'Awaiting payment',
  PaymentReview:        'Payment review',
  AwaitingConfirmation: 'Awaiting confirmation',
};

// ── Helper: derive reached step from history ──────────────────────────────────

/**
 * For a terminal job, find the step index it had *reached* just before the
 * terminal transition by scanning the status history for the last non-terminal
 * `toStatus`.
 */
function reachedStepFromHistory(history: AdminStatusHistory[]): number {
  if (!history.length) return 0;

  const sorted = [...history].sort(
    (a, b) => new Date(a.changedAtUtc).getTime() - new Date(b.changedAtUtc).getTime(),
  );

  // Walk backwards to find the last non-terminal toStatus.
  for (let i = sorted.length - 1; i >= 0; i--) {
    const toStatus = sorted[i].toStatus;
    if (!TERMINAL_STATUSES.has(toStatus) && ACTIVE_STEP[toStatus] !== undefined) {
      return ACTIVE_STEP[toStatus];
    }
  }

  return 0;
}

// ── Main export ────────────────────────────────────────────────────────────────

export function getJobProgress(
  status: string,
  history: AdminStatusHistory[],
): JobProgressResult {
  // --- Terminal statuses ---
  if (TERMINAL_STATUSES.has(status)) {
    const reachedIndex = reachedStepFromHistory(history);
    const stepLabel = STEPS[reachedIndex]?.label ?? 'Requested';
    const terminalState: StepState =
      status === 'Cancelled' ? 'cancelled'
      : status === 'Expired'    ? 'expired'
      : 'disputed';

    return {
      steps:        STEPS,
      currentIndex: reachedIndex,
      state:        terminalState,
      label:        status,                       // "Cancelled" / "Expired" / "Disputed"
      sublabel:     null,
      summary:      `${stepLabel}, ${status}`,
    };
  }

  // --- Active / normal statuses ---
  if (ACTIVE_STEP[status] === undefined) {
    if (import.meta.env.DEV) {
      console.warn(`[jobProgress] Unknown JobStatus: "${status}" — falling back to step 1.`);
    }
  }

  const idx = ACTIVE_STEP[status] ?? 0;
  const isCompleted = status === 'Completed';
  const stepLabel = STEPS[idx]?.label ?? 'Requested';

  return {
    steps:        STEPS,
    currentIndex: idx,
    state:        isCompleted ? 'done' : 'active',
    label:        stepLabel,
    sublabel:     SUBLABEL[status] ?? null,
    summary:      isCompleted
      ? 'Step 4 of 4, Done'
      : `Step ${idx + 1} of 4, ${SUBLABEL[status] ?? stepLabel}`,
  };
}
