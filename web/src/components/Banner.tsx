/**
 * Banner — shared alert/status banner replacing the 10+ inline alert divs.
 *
 * Maps variant to the design token colours. Uses role="alert" for
 * error and success variants so screen readers announce immediately.
 */
import React from 'react';
import { AlertTriangle, CheckCircle, Info, XCircle } from 'lucide-react';

type BannerVariant = 'info' | 'warn' | 'error' | 'success';

interface BannerAction {
  label: string;
  onClick: () => void;
}

interface BannerProps {
  variant: BannerVariant;
  children: React.ReactNode;
  /** Optional inline action button (e.g. "Retry"). */
  action?: BannerAction;
  className?: string;
}

const CONFIG: Record<
  BannerVariant,
  {
    Icon: React.FC<{ size: number; className?: string; 'aria-hidden'?: boolean | 'true' | 'false' }>;
    containerClass: string;
    iconClass: string;
    role?: string;
  }
> = {
  info: {
    Icon: Info,
    containerClass:
      'bg-[var(--brand-100)] border border-[var(--paper-line)] text-[var(--ink)]',
    iconClass: 'text-[var(--brand-500)]',
  },
  warn: {
    Icon: AlertTriangle,
    containerClass:
      'bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 text-[var(--amber-dark)] dark:text-[var(--amber-ink)]',
    iconClass: '',
  },
  error: {
    Icon: XCircle,
    containerClass:
      'bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-[var(--red-ink)]',
    iconClass: '',
    role: 'alert',
  },
  success: {
    Icon: CheckCircle,
    containerClass:
      'bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-400',
    iconClass: '',
    role: 'alert',
  },
};

export const Banner: React.FC<BannerProps> = ({
  variant,
  children,
  action,
  className = '',
}) => {
  const { Icon, containerClass, iconClass, role } = CONFIG[variant];

  return (
    <div
      role={role}
      className={`flex flex-wrap items-start gap-2 rounded-lg px-4 py-3 text-sm ${containerClass} ${className}`}
    >
      <Icon size={14} className={`mt-0.5 shrink-0 ${iconClass}`} aria-hidden="true" />
      <span className="flex-1 min-w-0">{children}</span>
      {action && (
        <button
          className="btn btn-ghost !py-1 !px-2.5 !text-xs shrink-0"
          onClick={action.onClick}
        >
          {action.label}
        </button>
      )}
    </div>
  );
};
