/**
 * MobileDrawer — left slide-in navigation drawer for phone + tablet overlay.
 *
 * Triggered by the TopBar menu button on phone, and by the ≡ button on tablet.
 * Features:
 * - Full nav items list with active styling (kit `.sidebar.is-drawer` + `.scrim`)
 * - Focus trap while open
 * - Esc and scrim click to close
 * - Body scroll lock
 * - Closes on route change
 * - User menu in footer
 * - slide-in animation from the kit (reduced under prefers-reduced-motion)
 */
import React, { useEffect, useRef } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import { X } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { UserMenu } from './UserMenu';
import type { NavItem } from './SidebarNav';

const FOCUSABLE = [
  'a[href]',
  'button:not([disabled])',
  '[tabindex]:not([tabindex="-1"])',
].join(',');

function getFocusable(el: HTMLElement): HTMLElement[] {
  return Array.from(el.querySelectorAll<HTMLElement>(FOCUSABLE));
}

interface MobileDrawerProps {
  open: boolean;
  onClose: () => void;
  navItems: NavItem[];
  adminName: string;
  onLogout: () => void;
}

export const MobileDrawer: React.FC<MobileDrawerProps> = ({
  open,
  onClose,
  navItems,
  adminName,
  onLogout,
}) => {
  const drawerRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<Element | null>(null);
  const location = useLocation();

  // Close on route change
  useEffect(() => { onClose(); }, [location.pathname]); // eslint-disable-line react-hooks/exhaustive-deps

  // Remember opener + restore focus
  useEffect(() => {
    if (open) {
      triggerRef.current = document.activeElement;
      requestAnimationFrame(() => {
        const first = drawerRef.current && getFocusable(drawerRef.current)[0];
        first?.focus();
      });
    } else {
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
      if (e.key === 'Tab' && drawerRef.current) {
        const focusable = getFocusable(drawerRef.current);
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

  if (!open) return null;

  return (
    <>
      {/* Scrim: a press outside the drawer closes it */}
      <div className="scrim" onClick={onClose} aria-hidden="true" />

      {/* Drawer panel (a div, not an aside: role="dialog" is not allowed on aside) */}
      <div
        ref={drawerRef}
        id="mobile-nav-drawer"
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
        className="sidebar is-drawer"
        style={{ height: '100dvh', paddingTop: 'var(--safe-top)' }}
      >
        <div className="sidebar-brand">
          <div className="row between nowrap">
            <BrandWordmark className="wordmark wordmark-lg" />
            <button
              type="button"
              className="nav-item nav-item-icon"
              onClick={onClose}
              aria-label="Close navigation"
            >
              <X size={20} aria-hidden="true" />
            </button>
          </div>
        </div>

        <nav className="sidebar-nav" aria-label="Admin navigation">
          {navItems.map(({ to, label, Icon }) => (
            <NavLink key={to} to={to} className="nav-item">
              <Icon size={20} aria-hidden="true" />
              <span className="nav-label">{label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot" style={{ paddingBottom: 'max(var(--safe-bottom), var(--sp-4))' }}>
          <UserMenu adminName={adminName} onLogout={onLogout} variant="dark" />
        </div>
      </div>
    </>
  );
};
