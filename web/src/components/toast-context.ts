import { createContext, useContext } from 'react';

export type ToastTone = 'info' | 'ok' | 'warn' | 'danger';

export interface ToastOptions {
  tone?: ToastTone;
  title: string;
  text?: string;
}

export interface ToastApi {
  /** Show a toast and return its id. Info and ok dismiss after 3 s; warn and danger stay until dismissed. */
  toast: (options: ToastOptions) => number;
  dismiss: (id: number) => void;
}

export const ToastContext = createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const api = useContext(ToastContext);
  if (!api) throw new Error('useToast must be used inside <ToastProvider>');
  return api;
}
