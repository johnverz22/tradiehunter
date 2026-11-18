/**
 * Banner — persistent inline message (design system: COMPONENTS.md "Banner").
 *
 * Flat surface with a small tone icon tile; warn and danger add a tone border (kit CSS).
 * No side stripe, no tinted fill. Tone is never colour-only: the icon tile always renders,
 * and an optional `title` states what happened. `role="alert"` for errors, `role="status"`
 * for everything else.
 *
 * Variants keep their original names (`info | warn | error | success`) so call sites do not change.
 */
import React from 'react';
import { AlertTriangle, CheckCircle2, Info, XCircle } from 'lucide-react';
import { Button } from './Button';

type BannerVariant = 'info' | 'warn' | 'error' | 'success';

interface BannerAction {
  label: string;
  onClick: () => void;
}

interface BannerProps {
  variant: BannerVariant;
  children: React.ReactNode;
  /** Optional short heading above the text (what happened). */
  title?: string;
  /** Optional inline action button (e.g. "Retry"). */
  action?: BannerAction;
  className?: string;
}

const CONFIG: Record<
  BannerVariant,
  {
    Icon: React.ElementType;
    /** Kit class suffix on `.banner-*`. */
    tone: 'info' | 'ok' | 'warn' | 'danger';
    tile: string;
    role: 'alert' | 'status';
  }
> = {
  info: { Icon: Info, tone: 'info', tile: 'tile tile-xs', role: 'status' },
  warn: { Icon: AlertTriangle, tone: 'warn', tile: 'tile tile-xs tile-warn', role: 'status' },
  error: { Icon: XCircle, tone: 'danger', tile: 'tile tile-xs tile-danger', role: 'alert' },
  success: { Icon: CheckCircle2, tone: 'ok', tile: 'tile tile-xs tile-ok', role: 'status' },
};

export const Banner: React.FC<BannerProps> = ({
  variant,
  children,
  title,
  action,
  className = '',
}) => {
  const { Icon, tone, tile, role } = CONFIG[variant];

  return (
    <div role={role} className={`banner banner-${tone} ${className}`.trim()}>
      <span className={tile} aria-hidden="true">
        <Icon size={18} />
      </span>
      <div className="banner-body">
        {title ? <div className="banner-title">{title}</div> : null}
        {/* With a title the message is secondary copy; without one it is the message itself. */}
        {title ? <div className="banner-text">{children}</div> : children}
      </div>
      {action ? (
        <div className="banner-actions">
          <Button kind="ghost" size="sm" onClick={action.onClick}>
            {action.label}
          </Button>
        </div>
      ) : null}
    </div>
  );
};
