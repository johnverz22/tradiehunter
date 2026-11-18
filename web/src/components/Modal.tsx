/**
 * Modal — accessible dialog primitive used by all overlays (design system: COMPONENTS.md "Modal").
 *
 * Markup is the kit's `.scrim > .modal > .modal-head / .modal-body / .modal-foot`.
 * Centered dialog from 640 px up; below 640 px the kit CSS turns it into a bottom sheet
 * (full width, rounded top, stacked footer buttons), so no breakpoint logic lives here.
 *
 * Provides: role=dialog, aria-modal, aria-labelledby, focus trap, Esc to close,
 * scrim click to close, body scroll lock, and focus restored to the opener.
 *
 * Initial focus: the element marked `data-autofocus` (destructive confirms mark Cancel),
 * else the first focusable element in the body, else the first one in the dialog.
 *
 * Usage:
 *   <Modal open={open} onClose={close} title="Verify payment"
 *          footer={<><Button kind="secondary" onClick={close}>Cancel</Button><Button kind="accent">Verify payment</Button></>}>
 *     <p>Check the transfer before you verify.</p>
 *   </Modal>
 */
import React, { useEffect, useId, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import { IconButton } from './Button';

export interface ModalProps {
  open: boolean;
  onClose: () => void;
  /** Sets aria-labelledby on the dialog element. */
  title?: string;
  /** Custom ID for aria-labelledby when title is rendered in children. */
  ariaLabelledBy?: string;
  /** 'sm' = narrow confirm dialog (default). 'lg' = wide content dialog. */
  size?: 'sm' | 'lg';
  children: React.ReactNode;
  /** Rendered in the footer (actions row). Cancel first, commit action last. */
  footer?: React.ReactNode;
  /** Show the ✕ close button in the header. Default true. */
  showCloseButton?: boolean;
}

// ── Focus helpers ─────────────────────────────────────────────────────────────

const FOCUSABLE = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

function getFocusable(el: HTMLElement): HTMLElement[] {
  return Array.from(el.querySelectorAll<HTMLElement>(FOCUSABLE));
}

// ── Component ─────────────────────────────────────────────────────────────────

export const Modal: React.FC<ModalProps> = ({
  open,
  onClose,
  title,
  ariaLabelledBy,
  size = 'sm',
  children,
  footer,
  showCloseButton = true,
}) => {
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const labelledBy = ariaLabelledBy || (title ? titleId : undefined);

  // Remember the opener and restore focus when the modal closes OR is unmounted by its parent.
  useEffect(() => {
    if (!open) return;
    const opener = document.activeElement as HTMLElement | null;
    return () => {
      if (opener?.isConnected && typeof opener.focus === 'function') {
        requestAnimationFrame(() => opener.focus());
      }
    };
  }, [open]);

  // Body scroll lock
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  // Keyboard handling: Esc + focus trap
  useEffect(() => {
    if (!open) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
        return;
      }

      if (e.key === 'Tab' && dialogRef.current) {
        const focusable = getFocusable(dialogRef.current);
        if (focusable.length === 0) {
          e.preventDefault();
          dialogRef.current.focus();
          return;
        }
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = document.activeElement;

        if (e.shiftKey) {
          if (active === first || active === dialogRef.current) {
            e.preventDefault();
            last.focus();
          }
        } else if (active === last) {
          e.preventDefault();
          first.focus();
        }
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  // Initial focus when the modal opens
  useEffect(() => {
    if (!open) return;
    const frame = requestAnimationFrame(() => {
      const dialog = dialogRef.current;
      if (!dialog) return;
      const target =
        dialog.querySelector<HTMLElement>('[data-autofocus]') ??
        getFocusable(dialog.querySelector<HTMLElement>('.modal-body') ?? dialog)[0] ??
        getFocusable(dialog)[0] ??
        dialog;
      target.focus();
    });
    return () => cancelAnimationFrame(frame);
  }, [open]);

  if (!open) return null;

  const sizeClass = size === 'lg' ? 'modal-lg' : 'modal-sm';

  return createPortal(
    <div
      className="scrim"
      onMouseDown={(e) => {
        // Only a press on the scrim itself closes; presses inside the dialog never do.
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        tabIndex={-1}
        className={`modal ${sizeClass}`}
      >
        {(title || showCloseButton) && (
          <div className="modal-head">
            {title && <h2 id={titleId}>{title}</h2>}
            {showCloseButton && (
              <IconButton label="Close" size="sm" className="ml-auto" onClick={onClose}>
                <X size={18} />
              </IconButton>
            )}
          </div>
        )}

        <div className="modal-body">{children}</div>

        {footer && (
          <div className="modal-foot" style={{ paddingBottom: 'calc(var(--sp-4) + var(--safe-bottom))' }}>
            {footer}
          </div>
        )}
      </div>
    </div>,
    document.body,
  );
};
