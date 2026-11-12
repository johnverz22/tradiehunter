/**
 * SidebarNav — desktop (240px fixed) + tablet icon rail (64px collapsed).
 * Renders nav items from the navItems array passed as a prop.
 * On desktop, also shows the user menu in the footer. The theme switcher
 * lives in the content area, never in the sidebar.
 */
import React from 'react';
import { NavLink } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';
import { LogOut } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { UserMenu } from './UserMenu';

export interface NavItem {
  to: string;
  label: string;
  Icon: LucideIcon;
}

interface SidebarNavProps {
  navItems: NavItem[];
  adminName: string;
  onLogout: () => void;
}

export const SidebarNav: React.FC<SidebarNavProps> = ({
  navItems,
  adminName,
  onLogout,
}) => (
  <aside
    className={[
      // phone: hidden; tablet: 64px rail; desktop: 240px full
      'hidden sm:flex flex-col shrink-0',
      'bg-[var(--brand-900)] text-white',
      // tablet: w-16 (64px); desktop: w-60 (240px)
      'w-16 lg:w-60',
    ].join(' ')}
    aria-label="Admin navigation"
  >
    {/* Brand */}
    <div className="px-2 lg:px-6 pt-6 pb-8 overflow-hidden">
      {/* Desktop: full wordmark; tablet: amber monogram */}
      <BrandWordmark className="font-bold text-[22px] text-white hidden lg:block" />
      <div className="lg:hidden flex justify-center">
        <span
          className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--amber)] text-[13px] font-bold tracking-tight text-[var(--brand-900)]"
          aria-hidden="true"
        >
          TH
        </span>
      </div>
    </div>

    {/* Nav items */}
    <nav className="flex-1 flex flex-col" aria-label="Admin navigation">
      {navItems.map(({ to, label, Icon }) => (
        <NavLink
          key={to}
          to={to}
          aria-label={label}
          className={({ isActive }) =>
            [
              'group relative flex items-center gap-3 py-3 text-sm font-medium transition-colors',
              // Desktop: left padding; tablet: justify center, no label
              'px-4 lg:px-6 justify-center lg:justify-start',
              isActive
                ? 'bg-white/15 text-white border-l-[3px] border-[var(--amber)]'
                : 'text-white/90 hover:text-white hover:bg-white/10 border-l-[3px] border-transparent',
            ].join(' ')
          }
        >
          <Icon size={18} aria-hidden="true" className="shrink-0" />
          <span className="hidden lg:inline">{label}</span>

          {/* Tablet flyout label — high-contrast, readable alternative to the browser tooltip */}
          <span
            aria-hidden="true"
            className="lg:hidden pointer-events-none absolute left-full top-1/2 z-50 ml-2 -translate-y-1/2 whitespace-nowrap rounded bg-[var(--brand-900)] px-2.5 py-1.5 text-xs font-semibold text-white opacity-0 shadow-[var(--shadow-pop)] ring-1 ring-white/25 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
          >
            {label}
          </span>
        </NavLink>
      ))}
    </nav>

    {/* Footer — desktop user menu, tablet logout at the rail edge */}
    <div className="border-t border-white/10 p-2 lg:p-4">
      <div className="hidden lg:block">
        <UserMenu adminName={adminName} onLogout={onLogout} variant="dark" />
      </div>
      <div className="lg:hidden flex justify-center">
        <button
          type="button"
          onClick={onLogout}
          title="Logout"
          aria-label="Logout"
          className="p-2 rounded text-white/85 hover:text-white hover:bg-white/10 transition-colors min-h-[44px] min-w-[44px] flex items-center justify-center"
        >
          <LogOut size={18} aria-hidden="true" />
        </button>
      </div>
    </div>
  </aside>
);
