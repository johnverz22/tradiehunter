/**
 * MobileDrawer — left slide-in navigation drawer for phone + tablet overlay.
 *
 * Triggered by the TopBar menu button on phone, and by the ≡ button on tablet.
 * Features:
 * - Full nav items list with active styling
 * - Focus trap while open
 * - Esc and scrim click to close
 * - Body scroll lock
 * - Closes on route change
 * - User menu in footer
 * - slide-in-left animation (respects prefers-reduced-motion)
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
    <div className="fixed inset-0 z-40 flex" aria-hidden="false">
      {/* Scrim */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Drawer panel */}
      <div
        ref={drawerRef}
        id="mobile-nav-drawer"
        role="dialog"
        aria-modal="true"
        aria-label="Navigation menu"
        className={[
          'relative z-10 flex flex-col h-full bg-[var(--brand-900)]',
          'motion-safe:animate-slide-in-left',
        ].join(' ')}
        style={{ width: 'var(--drawer-width)', paddingTop: 'var(--safe-top)' }}
      >
        {/* Drawer header */}
        <div className="flex items-center justify-between px-6 pt-4 pb-6">
          <BrandWordmark className="font-bold text-[22px] text-white" />
          <button
            onClick={onClose}
            aria-label="Close navigation"
            className="p-2 rounded text-white/70 hover:text-white hover:bg-white/10 transition-colors min-h-[44px] min-w-[44px] flex items-center justify-center"
          >
            <X size={20} aria-hidden="true" />
          </button>
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto" aria-label="Admin navigation">
          {navItems.map(({ to, label, Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                [
                  'flex items-center gap-3 px-6 py-3 text-sm font-medium transition-colors min-h-[44px]',
                  isActive
                    ? 'bg-white/15 text-white border-l-[3px] border-[var(--amber)]'
                    : 'text-white/90 hover:text-white hover:bg-white/10 border-l-[3px] border-transparent',
                ].join(' ')
              }
            >
              <Icon size={18} aria-hidden="true" className="shrink-0" />
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div
          className="border-t border-white/10 p-4"
          style={{ paddingBottom: 'max(var(--safe-bottom), 16px)' }}
        >
          <UserMenu adminName={adminName} onLogout={onLogout} variant="dark" />
        </div>
      </div>
    </div>
  );
};
