/**
 * SidebarNav — primary navigation (kit `.sidebar`).
 *
 * The kit CSS owns the responsive behaviour: full 240px sidebar from 1024px,
 * 64px icon rail from 640px (labels stay in the DOM, visually hidden), hidden
 * below 640px (the MobileDrawer takes over). The current page is marked with
 * `aria-current="page"` (set by NavLink) and drawn with the gold marker.
 * The footer shows who is signed in and the Logout action.
 */
import React from 'react';
import { NavLink } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';
import { LogOut } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { useBreakpoint } from '../hooks/useBreakpoint';

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

/** Up to two initials for the avatar ("Sam Harris" → "SH"). */
function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const letters = parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] ?? '').slice(0, 1);
  return (letters || 'A').toUpperCase();
}

export const SidebarNav: React.FC<SidebarNavProps> = ({
  navItems,
  adminName,
  onLogout,
}) => {
  // In the rail the labels are hidden, so give sighted pointer users a native tooltip.
  const { isDesktop } = useBreakpoint();

  return (
    <aside className="sidebar" aria-label="Admin navigation">
      <div className="sidebar-brand">
        <BrandWordmark className="wordmark wordmark-lg" />
        <span className="monogram" aria-hidden="true">TH</span>
      </div>

      <nav className="sidebar-nav">
        {navItems.map(({ to, label, Icon }) => (
          <NavLink
            key={to}
            to={to}
            title={isDesktop ? undefined : label}
            className="nav-item"
          >
            <Icon size={20} aria-hidden="true" />
            <span className="nav-label">{label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-foot">
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
          title={isDesktop ? undefined : 'Logout'}
        >
          <LogOut size={20} aria-hidden="true" />
          <span className="nav-label">Logout</span>
        </button>
      </div>
    </aside>
  );
};
