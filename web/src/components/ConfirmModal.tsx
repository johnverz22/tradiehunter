import React from 'react';
import { AlertTriangle } from 'lucide-react';

interface ConfirmModalProps {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export const ConfirmModal: React.FC<ConfirmModalProps> = ({
  open,
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  destructive = false,
  onConfirm,
  onCancel,
}) => {
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onCancel]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      onClick={onCancel}
    >
      <div
        className="bg-paper border border-paper-line rounded-lg shadow-xl p-6 max-w-sm w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start gap-4 mb-4">
          <AlertTriangle
            size={22}
            className={destructive ? 'text-[var(--red)] shrink-0 mt-0.5' : 'text-[var(--amber)] shrink-0 mt-0.5'}
            aria-hidden="true"
          />
          <div>
            <h2 id="modal-title" className="text-base font-semibold text-[var(--ink)] mb-1">
              {title}
            </h2>
            <p className="text-sm text-[var(--ink-soft)]">{message}</p>
          </div>
        </div>

        <div className="flex justify-end gap-3 mt-6">
          <button
            onClick={onCancel}
            className="px-4 py-2 text-sm rounded border border-[var(--paper-line)] text-[var(--ink-soft)] hover:bg-[var(--paper-line)] transition-colors"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            className={
              destructive
                ? 'px-4 py-2 text-sm rounded bg-[var(--red)] text-white hover:opacity-90 transition-opacity'
                : 'px-4 py-2 text-sm rounded bg-[var(--brand-500)] text-white hover:bg-[var(--brand-700)] transition-colors'
            }
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
};
