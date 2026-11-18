/**
 * UserMenu — who is signed in, and how to sign out.
 *
 * variant="dark" (sidebar / drawer footer): an identity row (avatar with
 *   initials, name, "Administrator") and a Logout button, both drawn with the
 *   kit `.nav-item` so they sit on the dark sidebar. Rendered inside a
 *   `.sidebar-foot` supplied by the parent.
 * variant="light" (top bar): an avatar button that opens the kit `.menu`
 *   (`role="menu"`, `menuitem`): arrow keys, Home/End, Esc closes and returns
 *   focus to the button, Tab or a click outside closes.
 */
import React, { useEffect, useId, useRef, useState } from 'react';
import { LogOut } from 'lucide-react';
import { IconButton } from '../components/Button';

interface UserMenuProps {
  adminName: string;
  onLogout: () => void;
  /** 'dark' (sidebar/drawer footer) or 'light' (top bar menu). */
  variant?: 'dark' | 'light';
  /** dark only: add native tooltips (the labels are hidden in the rail). */
  showTitles?: boolean;
}

/** Up to two initials for the avatar ("Sam Harris" → "SH"). */
function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const letters =
    parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] ?? '').slice(0, 1);
  return (letters || 'A').toUpperCase();
}

const DarkUserMenu: React.FC<Omit<UserMenuProps, 'variant'>> = ({
  adminName,
  onLogout,
  showTitles,
}) => (
  <>
    <div className="nav-item nav-item-static">
      <span className="avatar avatar-sm" aria-hidden="true">{initials(adminName)}</span>
      <span className="nav-label" title={adminName}>
        {adminName}
        <small>Administrator</small>
      </span>
    </div>
    <button
      type="button"
      className="nav-item"
      onClick={onLogout}
      title={showTitles ? 'Logout' : undefined}
    >
      <LogOut size={20} aria-hidden="true" />
      <span className="nav-label">Logout</span>
    </button>
  </>
);

const LightUserMenu: React.FC<Omit<UserMenuProps, 'variant'>> = ({ adminName, onLogout }) => {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const menuId = useId();

  const items = () =>
    Array.from(menuRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);

  // Move focus into the menu when it opens.
  useEffect(() => {
    if (open) items()[0]?.focus();
  }, [open]);

  // Close on a press outside.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent | TouchEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('touchstart', onDown);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('touchstart', onDown);
    };
  }, [open]);

  const close = (returnFocus: boolean) => {
    setOpen(false);
    if (returnFocus) triggerRef.current?.focus();
  };

  const onMenuKeyDown = (e: React.KeyboardEvent) => {
    const list = items();
    const i = list.indexOf(document.activeElement as HTMLElement);
    switch (e.key) {
      case 'Escape':
        e.preventDefault();
        e.stopPropagation();
        close(true);
        break;
      case 'ArrowDown':
        e.preventDefault();
        list[(i + 1) % list.length]?.focus();
        break;
      case 'ArrowUp':
        e.preventDefault();
        list[(i - 1 + list.length) % list.length]?.focus();
        break;
      case 'Home':
        e.preventDefault();
        list[0]?.focus();
        break;
      case 'End':
        e.preventDefault();
        list[list.length - 1]?.focus();
        break;
      case 'Tab':
        setOpen(false);
        break;
    }
  };

  return (
    <div ref={rootRef} className="relative">
      <IconButton
        ref={triggerRef}
        label={`User account: ${adminName}`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((o) => !o)}
      >
        <span className="avatar avatar-sm">{initials(adminName)}</span>
      </IconButton>

      {open && (
        <div className="menu absolute right-0 top-full z-50 mt-2" onKeyDown={onMenuKeyDown}>
          <div className="px-3 py-2">
            <strong className="block truncate" title={adminName}>{adminName}</strong>
            <small className="muted">Administrator</small>
          </div>
          <div ref={menuRef} id={menuId} role="menu" aria-label="Account">
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                setOpen(false);
                onLogout();
              }}
            >
              <LogOut size={16} aria-hidden="true" />
              Logout
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export const UserMenu: React.FC<UserMenuProps> = ({
  adminName,
  onLogout,
  variant = 'dark',
  showTitles,
}) =>
  variant === 'light' ? (
    <LightUserMenu adminName={adminName} onLogout={onLogout} />
  ) : (
    <DarkUserMenu adminName={adminName} onLogout={onLogout} showTitles={showTitles} />
  );
