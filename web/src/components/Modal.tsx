/**
 * Modal — accessible dialog primitive used by all overlays.
 *
 * Phone:          bottom sheet (full-width, rounded top, max-h 90dvh,
 *                 internal scroll, sticky footer, slide-up animation).
 * Tablet/desktop: centered dialog (max-h 85dvh, internal scroll).
 *
 * Provides: role=dialog, aria-modal, aria-labelledby, focus trap,
 * Esc to close, scrim click to close, body scroll lock, restore focus.
 * Animated with translate-y; respects prefers-reduced-motion.
 *
 * Usage:
 *   <Modal open={open} onClose={close} title="Confirm action"
 *          footer={<><button onClick={close}>Cancel</button><button>OK</button></>}>
 *     <p>Are you sure?</p>
 *   </Modal>
 */
import React, { useEffect, useId, useRef } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';

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
  /** Rendered in a sticky footer area (actions row). */
  footer?: React.ReactNode;
  /** Show the ✕ close button in the header. Default true. */
  showCloseButton?: boolean;
}

// ── Focus trap helpers ────────────────────────────────────────────────────────

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
  const { isPhone } = useBreakpoint();
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<Element | null>(null);
  const labelledBy = ariaLabelledBy || (title ? titleId : undefined);

  // Remember the element that opened the modal so we can restore focus.
  useEffect(() => {
    if (open) {
      triggerRef.current = document.activeElement;
    } else {
      // Restore focus after the portal unmounts (next frame).
      const el = triggerRef.current as HTMLElement | null;
      if (el?.focus) requestAnimationFrame(() => el.focus());
    }
  }, [open]);

  // Body scroll lock
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => { document.body.style.overflow = prev; };
  }, [open]);

  // Keyboard handling: Esc + focus trap
  useEffect(() => {
    if (!open) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { e.preventDefault(); onClose(); return; }

      if (e.key === 'Tab' && dialogRef.current) {
        const focusable = getFocusable(dialogRef.current);
        if (focusable.length === 0) { e.preventDefault(); return; }
        const first = focusable[0];
        const last  = focusable[focusable.length - 1];

        if (e.shiftKey) {
          if (document.activeElement === first) { e.preventDefault(); last.focus(); }
        } else {
          if (document.activeElement === last)  { e.preventDefault(); first.focus(); }
        }
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  // Auto-focus first focusable element when modal opens
  useEffect(() => {
    if (!open || !dialogRef.current) return;
    requestAnimationFrame(() => {
      const first = getFocusable(dialogRef.current!)[0];
      first?.focus();
    });
  }, [open]);

  if (!open) return null;

  // ── Phone: bottom sheet ────────────────────────────────────────────────────
  if (isPhone) {
    return createPortal(
      <div
        className="fixed inset-0 z-50 flex flex-col justify-end"
        aria-hidden="false"
      >
        {/* Scrim */}
        <div
          className="absolute inset-0 bg-black/50"
          onClick={onClose}
          aria-hidden="true"
        />

        {/* Sheet */}
        <div
          ref={dialogRef}
          role="dialog"
          aria-modal="true"
          aria-labelledby={labelledBy}
          className={[
            'relative z-10 w-full bg-[var(--surface)] rounded-t-2xl',
            'flex flex-col max-h-[90dvh]',
            'motion-safe:animate-slide-up',
            // safe-area bottom padding applied in footer
          ].join(' ')}
          style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
        >
          {/* Handle bar */}
          <div className="flex justify-center pt-3 pb-1 shrink-0">
            <div className="w-10 h-1 rounded-full bg-[var(--paper-line)]" aria-hidden="true" />
          </div>

          {/* Header */}
          {(title || showCloseButton) && (
            <div className="flex items-center justify-between gap-3 px-5 py-3 border-b border-[var(--paper-line)] shrink-0">
              {title && (
                <h2 id={titleId} className="text-base font-semibold text-[var(--ink)] m-0">
                  {title}
                </h2>
              )}
              {showCloseButton && (
                <button
                  onClick={onClose}
                  aria-label="Close"
                  className="p-2 rounded text-[var(--ink-soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)] transition-colors -mr-1 shrink-0"
                >
                  <X size={18} aria-hidden="true" />
                </button>
              )}
            </div>
          )}

          {/* Scrollable content */}
          <div className="flex-1 overflow-y-auto px-5 py-4 min-h-0">
            {children}
          </div>

          {/* Sticky footer */}
          {footer && (
            <div className="shrink-0 px-5 py-4 border-t border-[var(--paper-line)] bg-[var(--surface)]">
              {footer}
            </div>
          )}
        </div>
      </div>,
      document.body,
    );
  }

  // ── Tablet / desktop: centered dialog ─────────────────────────────────────
  const maxWidth = size === 'lg' ? 'max-w-2xl' : 'max-w-sm';

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      aria-hidden="false"
    >
      {/* Scrim */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Dialog panel */}
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        className={[
          'relative z-10 w-full card-pop flex flex-col',
          maxWidth,
          'max-h-[85dvh]',
        ].join(' ')}
      >
        {/* Header */}
        {(title || showCloseButton) && (
          <div className="flex items-center justify-between gap-3 p-6 pb-0 shrink-0">
            {title && (
              <h2 id={titleId} className="text-base font-semibold text-[var(--ink)] m-0">
                {title}
              </h2>
            )}
            {showCloseButton && (
              <button
                onClick={onClose}
                aria-label="Close"
                className="p-2 rounded text-[var(--ink-soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)] transition-colors -mr-2 shrink-0"
              >
                <X size={16} aria-hidden="true" />
              </button>
            )}
          </div>
        )}

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto p-6 min-h-0">
          {children}
        </div>

        {/* Footer */}
        {footer && (
          <div className="shrink-0 px-6 pb-6 pt-0">
            {footer}
          </div>
        )}
      </div>
    </div>,
    document.body,
  );
};
