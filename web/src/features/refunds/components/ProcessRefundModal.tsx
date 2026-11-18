import React, { useRef, useState } from 'react';
import { AlertCircle, Paperclip, X } from 'lucide-react';
import { Button, IconButton } from '../../../components/Button';
import { Field } from '../../../components/Field';
import { Modal } from '../../../components/Modal';
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
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [finalAmount, setFinalAmount] = useState(String(refund.finalAmount));
  const [penalty, setPenalty] = useState(String(refund.penalty));
  const [hoursWorked, setHoursWorked] = useState(String(refund.hoursWorked));
  const [transferRef, setTransferRef] = useState('');
  const [proof, setProof] = useState<File | undefined>();
  const [fileError, setFileError] = useState<string | null>(null);

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
    finalAmountNum >= 0 &&
    penaltyNum >= 0 &&
    hoursWorkedNum >= 0 &&
    transferRef.trim().length > 0 &&
    !isSubmitting;

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
    <Modal
      open
      onClose={onCancel}
      size="lg"
      title={`Process refund — job #${refund.jobId}`}
      footer={
        <>
          <Button kind="secondary" onClick={onCancel} disabled={isSubmitting}>
            Cancel
          </Button>
          <Button kind="accent" onClick={handleSubmit} disabled={!canSubmit}>
            {isSubmitting ? 'Processing…' : 'Process refund'}
          </Button>
        </>
      }
    >
      <div className="stack">
        <div>
          <p className="t-title">{refund.jobTitle}</p>
          <p className="t-meta c-soft">Review amounts and provide the bank transfer reference.</p>
        </div>

        {/* Summary row */}
        <dl className="dl">
          <div>
            <dt>Homeowner</dt>
            <dd>
              {refund.homeownerName}
              <span className="block t-meta muted">{refund.homeownerEmail}</span>
            </dd>
          </div>
          <div>
            <dt>Suggested refund</dt>
            <dd>
              <span className="money">{money(refund.suggestedAmount)}</span>
            </dd>
          </div>
          {refund.cancelReasonCode && (
            <div>
              <dt>Cancel reason</dt>
              <dd>{refund.cancelReasonCode.replace(/_/g, ' ')}</dd>
            </div>
          )}
          {refund.hoursWorked > 0 && (
            <div>
              <dt>Hours worked (system est.)</dt>
              <dd className="mono">{refund.hoursWorked}h</dd>
            </div>
          )}
        </dl>

        {/* Editable fields */}
        <div className="grid c2">
          <Field label="Final amount (NZD)">
            {(a11y) => (
              <input
                {...a11y}
                type="number"
                min="0"
                step="0.01"
                value={finalAmount}
                onChange={(e) => setFinalAmount(e.target.value)}
                className="field"
              />
            )}
          </Field>
          <Field label="Penalty (NZD)">
            {(a11y) => (
              <input
                {...a11y}
                type="number"
                min="0"
                step="0.01"
                value={penalty}
                onChange={(e) => setPenalty(e.target.value)}
                className="field"
              />
            )}
          </Field>
        </div>

        <Field label="Hours worked">
          {(a11y) => (
            <input
              {...a11y}
              type="number"
              min="0"
              step="0.25"
              value={hoursWorked}
              onChange={(e) => setHoursWorked(e.target.value)}
              className="field"
            />
          )}
        </Field>

        <Field
          label="Transfer reference"
          help="Required. The bank transfer reference shown on the homeowner's statement."
        >
          {(a11y) => (
            <input
              {...a11y}
              type="text"
              value={transferRef}
              onChange={(e) => setTransferRef(e.target.value)}
              maxLength={200}
              placeholder="e.g. BNZ TXN-20260929-001"
              className="field"
              autoFocus
              data-autofocus
            />
          )}
        </Field>

        {/* Proof file upload */}
        <div className="form-row">
          <span className="label">
            Proof of transfer<span className="opt">Optional</span>
          </span>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,application/pdf"
            className="sr-only"
            onChange={handleFileChange}
            id="rf-proof-file"
          />
          {proof ? (
            <div className="row nowrap">
              <Paperclip size={16} className="shrink-0 c-soft" aria-hidden="true" />
              <span className="truncate flex-1">{proof.name}</span>
              <IconButton
                kind="ghost"
                size="sm"
                label="Remove file"
                onClick={() => {
                  setProof(undefined);
                  if (fileInputRef.current) fileInputRef.current.value = '';
                }}
              >
                <X size={16} aria-hidden="true" />
              </IconButton>
            </div>
          ) : (
            <label htmlFor="rf-proof-file" className="btn btn-secondary btn-block">
              <Paperclip size={20} aria-hidden="true" />
              Attach receipt / screenshot
            </label>
          )}
          {fileError && (
            <div className="error" role="alert">
              <AlertCircle size={16} aria-hidden="true" className="shrink-0" />
              <span>{fileError}</span>
            </div>
          )}
        </div>
      </div>
    </Modal>
  );
};
