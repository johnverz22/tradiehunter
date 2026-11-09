import React, { useId, useRef, useState } from 'react';
import { AlertTriangle, Paperclip, X } from 'lucide-react';
import type { RefundSummary } from '../../../services/adminApi';

interface ProcessRefundModalProps {
  refund: RefundSummary;
  isSubmitting: boolean;
  onConfirm: (params: {
    finalAmount: number;
    penalty: number;
    hoursWorked: number;
    transferReference: string;
    proof?: File;
  }) => void;
  onCancel: () => void;
}

const money = (amount: number) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency: 'NZD' }).format(amount);

const MAX_PROOF_BYTES = 10 * 1024 * 1024; // 10 MB

export const ProcessRefundModal: React.FC<ProcessRefundModalProps> = ({
  refund,
  isSubmitting,
  onConfirm,
  onCancel,
}) => {
  const titleId = useId();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [finalAmount, setFinalAmount] = useState(String(refund.finalAmount));
  const [penalty, setPenalty] = useState(String(refund.penalty));
  const [hoursWorked, setHoursWorked] = useState(String(refund.hoursWorked));
  const [transferRef, setTransferRef] = useState('');
  const [proof, setProof] = useState<File | undefined>();
  const [fileError, setFileError] = useState<string | null>(null);

  // Close on Escape
  React.useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onCancel(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFileError(null);
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > MAX_PROOF_BYTES) {
      setFileError('File exceeds 10 MB limit.');
      return;
    }
    setProof(file);
  };

  const finalAmountNum = parseFloat(finalAmount) || 0;
  const penaltyNum = parseFloat(penalty) || 0;
  const hoursWorkedNum = parseFloat(hoursWorked) || 0;
  const canSubmit =
    finalAmountNum >= 0 && penaltyNum >= 0 && hoursWorkedNum >= 0 &&
    transferRef.trim().length > 0 && !isSubmitting;

  const handleSubmit = () => {
    if (!canSubmit) return;
    onConfirm({
      finalAmount: finalAmountNum,
      penalty: penaltyNum,
      hoursWorked: hoursWorkedNum,
      transferReference: transferRef.trim(),
      proof,
    });
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      onClick={onCancel}
    >
      <div
        className="card-pop p-6 w-full max-w-xl overflow-y-auto max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-start justify-between gap-4 mb-5">
          <div className="flex items-start gap-3">
            <AlertTriangle size={20} className="text-[var(--amber)] shrink-0 mt-0.5" aria-hidden="true" />
            <div>
              <h2 id={titleId} className="text-base font-semibold text-[var(--ink)]">
                Process Refund
              </h2>
              <p className="text-sm text-[var(--ink-soft)] mt-0.5">
                Job #{refund.jobId} — {refund.jobTitle}
              </p>
            </div>
          </div>
          <button
            onClick={onCancel}
            className="p-1.5 rounded text-[var(--ink-soft)] hover:text-[var(--ink)] hover:bg-[var(--paper-raised)] transition-colors shrink-0"
            aria-label="Close"
          >
            <X size={16} />
          </button>
        </div>

        {/* Summary row */}
        <dl className="rounded-lg border border-[var(--paper-line)] divide-y divide-[var(--paper-line)] mb-5">
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Homeowner</dt>
            <dd className="text-sm text-[var(--ink)] text-right">
              {refund.homeownerName}
              <span className="block text-xs text-[var(--ink-soft)]">{refund.homeownerEmail}</span>
            </dd>
          </div>
          <div className="flex items-baseline justify-between gap-3 px-3 py-2">
            <dt className="text-xs text-[var(--ink-soft)]">Suggested refund</dt>
            <dd className="font-mono text-sm font-semibold text-[var(--ink)]">
              {money(refund.suggestedAmount)}
            </dd>
          </div>
          {refund.cancelReasonCode && (
            <div className="flex items-baseline justify-between gap-3 px-3 py-2">
              <dt className="text-xs text-[var(--ink-soft)]">Cancel reason</dt>
              <dd className="text-sm text-[var(--ink)]">
                {refund.cancelReasonCode.replace(/_/g, ' ')}
              </dd>
            </div>
          )}
          {refund.hoursWorked > 0 && (
            <div className="flex items-baseline justify-between gap-3 px-3 py-2">
              <dt className="text-xs text-[var(--ink-soft)]">Hours worked (system est.)</dt>
              <dd className="font-mono text-sm text-[var(--ink)]">{refund.hoursWorked}h</dd>
            </div>
          )}
        </dl>

        {/* Editable fields */}
        <div className="space-y-4 mb-5">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm font-medium text-[var(--ink)] mb-1" htmlFor="rf-final">
                Final amount (NZD)
              </label>
              <input
                id="rf-final"
                type="number"
                min="0"
                step="0.01"
                value={finalAmount}
                onChange={(e) => setFinalAmount(e.target.value)}
                className="field w-full"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-[var(--ink)] mb-1" htmlFor="rf-penalty">
                Penalty (NZD)
              </label>
              <input
                id="rf-penalty"
                type="number"
                min="0"
                step="0.01"
                value={penalty}
                onChange={(e) => setPenalty(e.target.value)}
                className="field w-full"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-[var(--ink)] mb-1" htmlFor="rf-hours">
              Hours worked
            </label>
            <input
              id="rf-hours"
              type="number"
              min="0"
              step="0.25"
              value={hoursWorked}
              onChange={(e) => setHoursWorked(e.target.value)}
              className="field w-full"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-[var(--ink)] mb-1" htmlFor="rf-ref">
              Transfer reference <span className="text-[var(--red)]">*</span>
            </label>
            <input
              id="rf-ref"
              type="text"
              value={transferRef}
              onChange={(e) => setTransferRef(e.target.value)}
              maxLength={200}
              placeholder="e.g. BNZ TXN-20260929-001"
              className="field w-full"
              autoFocus
            />
            <p className="text-xs text-[var(--ink-soft)] mt-1">
              The bank transfer reference shown on the homeowner's statement.
            </p>
          </div>

          {/* Proof file upload */}
          <div>
            <p className="text-sm font-medium text-[var(--ink)] mb-1">Proof of transfer (optional)</p>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*,application/pdf"
              className="sr-only"
              onChange={handleFileChange}
              id="rf-proof-file"
            />
            {proof ? (
              <div className="flex items-center gap-2 rounded-lg border border-[var(--paper-line)] bg-[var(--paper-raised)] px-3 py-2">
                <Paperclip size={13} className="text-[var(--ink-soft)] shrink-0" aria-hidden="true" />
                <span className="text-sm text-[var(--ink)] truncate flex-1">{proof.name}</span>
                <button
                  type="button"
                  onClick={() => { setProof(undefined); if (fileInputRef.current) fileInputRef.current.value = ''; }}
                  className="p-1 rounded text-[var(--ink-soft)] hover:text-[var(--red)] transition-colors shrink-0"
                  aria-label="Remove file"
                >
                  <X size={13} />
                </button>
              </div>
            ) : (
              <label
                htmlFor="rf-proof-file"
                className="btn btn-ghost w-full justify-center cursor-pointer"
              >
                <Paperclip size={13} aria-hidden="true" />
                Attach receipt / screenshot
              </label>
            )}
            {fileError && (
              <p className="text-xs text-[var(--red)] mt-1">{fileError}</p>
            )}
          </div>
        </div>

        {/* Actions */}
        <div className="flex justify-end gap-3 pt-2 border-t border-[var(--paper-line)]">
          <button onClick={onCancel} className="btn btn-ghost" disabled={isSubmitting}>
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={!canSubmit}
            className="btn btn-primary"
          >
            {isSubmitting ? 'Processing…' : 'Process refund'}
          </button>
        </div>
      </div>
    </div>
  );
};
