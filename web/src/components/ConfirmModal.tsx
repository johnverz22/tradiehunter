import React from 'react';
import { AlertTriangle } from 'lucide-react';

interface ConfirmModalProps {
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  /** Keeps Confirm disabled until the caller's input is valid (e.g. a required reason). */
  confirmDisabled?: boolean;
  /** `lg` for content that needs room, e.g. an image preview. Defaults to the narrow confirm layout. */
  size?: 'sm' | 'lg';
  /** Optional extra content below the message, e.g. a reason field or an inline error. */
  children?: React.ReactNode;
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
  confirmDisabled = false,
  size = 'sm',
  children,
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
        className={`card-pop p-6 w-full ${size === 'lg' ? 'max-w-2xl' : 'max-w-sm'}`}
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

        {children}

        <div className="flex justify-end gap-3 mt-6">
          <button
            onClick={onCancel}
            className="btn btn-ghost"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            disabled={confirmDisabled}
            className={destructive ? 'btn' : 'btn btn-primary'}
            style={destructive ? { background: 'var(--red)', color: '#fff' } : undefined}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
};
