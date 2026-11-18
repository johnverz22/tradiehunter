/**
 * Toast — short confirmation on an inverse surface (design system: COMPONENTS.md "Toast").
 * Always has a dismiss button. Success and info auto-dismiss after 3 s; warnings and
 * errors persist (WCAG 2.2.1) and must ALSO be shown inline next to the cause.
 */
import React, { useCallback, useMemo, useRef, useState } from 'react';
import { AlertCircle, AlertTriangle, CheckCircle2, Info, X } from 'lucide-react';
import { IconButton } from './Button';
import { ToastContext, type ToastApi, type ToastOptions, type ToastTone } from './toast-context';

const AUTO_DISMISS_MS = 3000;

const TONE: Record<ToastTone, { Icon: React.ElementType; tile: string; cls: string; role: 'status' | 'alert' }> = {
  info: { Icon: Info, tile: 'tile-xs', cls: '', role: 'status' },
  ok: { Icon: CheckCircle2, tile: 'tile-xs tile-ok', cls: 'toast-ok', role: 'status' },
  warn: { Icon: AlertTriangle, tile: 'tile-xs tile-warn', cls: 'toast-warn', role: 'alert' },
  danger: { Icon: AlertCircle, tile: 'tile-xs tile-danger', cls: 'toast-danger', role: 'alert' },
};

interface ToastProps {
  tone?: ToastTone;
  title: string;
  text?: string;
  onDismiss: () => void;
}

export const Toast: React.FC<ToastProps> = ({ tone = 'info', title, text, onDismiss }) => {
  const { Icon, tile, cls, role } = TONE[tone];
  return (
    <div className={`toast ${cls}`.trim()} role={role}>
      <span className={`tile ${tile}`} aria-hidden="true">
        <Icon size={18} />
      </span>
      <div className="toast-body">
        <div className="toast-title">{title}</div>
        {text ? <div className="toast-text">{text}</div> : null}
      </div>
      <IconButton label="Dismiss" size="sm" onClick={onDismiss}>
        <X size={18} />
      </IconButton>
    </div>
  );
};

interface Item extends ToastOptions {
  id: number;
}

/** Mount once near the app root. Use `useToast()` from `./toast-context` to show toasts. */
export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [items, setItems] = useState<Item[]>([]);
  const nextId = useRef(1);
  const timers = useRef(new Map<number, ReturnType<typeof setTimeout>>());

  const dismiss = useCallback((id: number) => {
    const t = timers.current.get(id);
    if (t) clearTimeout(t);
    timers.current.delete(id);
    setItems((cur) => cur.filter((i) => i.id !== id));
  }, []);

  const toast = useCallback(
    (options: ToastOptions) => {
      const id = nextId.current++;
      const tone = options.tone ?? 'info';
      setItems((cur) => [...cur, { ...options, tone, id }]);
      if (tone === 'info' || tone === 'ok') {
        timers.current.set(id, setTimeout(() => dismiss(id), AUTO_DISMISS_MS));
      }
      return id;
    },
    [dismiss],
  );

  const api = useMemo<ToastApi>(() => ({ toast, dismiss }), [toast, dismiss]);

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div
        className="pointer-events-none fixed inset-x-0 bottom-0 z-50 flex flex-col items-center gap-2 px-4"
        style={{ paddingBottom: 'calc(var(--sp-4) + var(--safe-bottom))' }}
      >
        {items.map((i) => (
          <div key={i.id} className="pointer-events-auto">
            <Toast tone={i.tone} title={i.title} text={i.text} onDismiss={() => dismiss(i.id)} />
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
};
