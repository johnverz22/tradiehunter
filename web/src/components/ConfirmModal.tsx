/**
 * ConfirmModal — thin wrapper over the shared Modal primitive.
 *
 * All existing props, aria-labels and testids are preserved exactly.
 * On phone it renders as a bottom sheet (via Modal); on tablet/desktop
 * as the existing centered dialog — layout and labels unchanged.
 */
import React from 'react';
import { AlertTriangle } from 'lucide-react';
import { Modal } from './Modal';

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
}) => (
  <Modal
    open={open}
    onClose={onCancel}
    size={size}
    showCloseButton={false}
    ariaLabelledBy="modal-title"
    footer={
      <div className="flex justify-end gap-3">
        <button onClick={onCancel} className="btn btn-ghost">
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
    }
  >
    <div className="flex items-start gap-4 mb-4">
      <AlertTriangle
        size={22}
        className={
          destructive
            ? 'text-[var(--red)] shrink-0 mt-0.5'
            : 'text-[var(--amber)] shrink-0 mt-0.5'
        }
        aria-hidden="true"
      />
      <div>
        <h2 id="modal-title" className="text-base font-semibold text-[var(--ink)] mb-1 m-0">
          {title}
        </h2>
        <p className="text-sm text-[var(--ink-soft)]">{message}</p>
      </div>
    </div>
    {children}
  </Modal>
);
