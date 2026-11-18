/**
 * Button — the one button component (design system: COMPONENTS.md "Button").
 *
 * Kinds: `accent` is the single gold commit action per view or dialog; the rest
 * are `primary`, `secondary`, `ghost`, `danger` (filled) and `danger-outline`.
 * Label says what will happen ("Verify payment", not "Submit").
 * `loading` shows the spinner, sets aria-busy and blocks clicks while keeping focus.
 */
import React from 'react';

export type ButtonKind =
  | 'accent'
  | 'primary'
  | 'secondary'
  | 'ghost'
  | 'danger'
  | 'danger-outline';
export type ButtonSize = 'sm' | 'md' | 'lg';

interface BaseProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  kind?: ButtonKind;
  size?: ButtonSize;
  loading?: boolean;
  /** Stretch to the container width. */
  block?: boolean;
}

export interface ButtonProps extends BaseProps {
  /** Leading icon (decorative; the label carries the meaning). */
  icon?: React.ReactNode;
  children: React.ReactNode;
}

export interface IconButtonProps extends BaseProps {
  /** Required: an icon-only button has no visible text. */
  label: string;
  children: React.ReactNode;
}

function classes({ kind, size, loading, block, className }: BaseProps, iconOnly: boolean) {
  return [
    'btn',
    `btn-${kind}`,
    size === 'sm' ? 'btn-sm' : size === 'lg' ? 'btn-lg' : '',
    iconOnly ? 'btn-icon' : '',
    block ? 'btn-block' : '',
    loading ? 'is-loading' : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ');
}

function guard(
  loading: boolean | undefined,
  onClick: React.MouseEventHandler<HTMLButtonElement> | undefined,
): React.MouseEventHandler<HTMLButtonElement> | undefined {
  if (!loading) return onClick;
  return (e) => e.preventDefault();
}

export const Button: React.FC<ButtonProps> = ({
  kind = 'primary',
  size = 'md',
  loading,
  block,
  icon,
  className,
  type = 'button',
  onClick,
  children,
  ...rest
}) => (
  <button
    {...rest}
    type={type}
    aria-busy={loading || undefined}
    onClick={guard(loading, onClick)}
    className={classes({ kind, size, loading, block, className }, false)}
  >
    {icon ? <span aria-hidden="true" className="inline-flex">{icon}</span> : null}
    {children}
  </button>
);

export const IconButton: React.FC<IconButtonProps> = ({
  kind = 'ghost',
  size = 'md',
  loading,
  label,
  className,
  type = 'button',
  onClick,
  children,
  ...rest
}) => (
  <button
    {...rest}
    type={type}
    aria-label={label}
    aria-busy={loading || undefined}
    onClick={guard(loading, onClick)}
    className={classes({ kind, size, loading, className }, true)}
  >
    <span aria-hidden="true" className="inline-flex">{children}</span>
  </button>
);
