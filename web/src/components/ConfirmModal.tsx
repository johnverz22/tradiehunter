/**
 * ConfirmModal — confirm dialog on the shared Modal (design system: COMPONENTS.md "Modal",
 * DESIGN_GUIDE "Confirm dialog").
 *
 * Props are unchanged. Footer is Cancel (secondary) then the commit button: gold `accent`,
 * or filled `danger` when `destructive`. Destructive dialogs put initial focus on Cancel.
 * Below 640 px it is a bottom sheet (via Modal).
 */
import React from 'react';
import { Modal } from './Modal';
import { Button } from './Button';

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
    title={title}
    showCloseButton={false}
    footer={
      <>
        <Button
          kind="secondary"
          onClick={onCancel}
          data-autofocus={destructive ? '' : undefined}
        >
          {cancelLabel}
        </Button>
        <Button
          kind={destructive ? 'danger' : 'accent'}
          onClick={onConfirm}
          disabled={confirmDisabled}
        >
          {confirmLabel}
        </Button>
      </>
    }
  >
    <p>{message}</p>
    {children}
  </Modal>
);
