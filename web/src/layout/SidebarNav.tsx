/**
 * SidebarNav — primary navigation (kit `.sidebar`).
 *
 * The kit CSS owns the responsive behaviour: full 240px sidebar from 1024px,
 * 64px icon rail from 640px (labels stay in the DOM, visually hidden), hidden
 * below 640px (the MobileDrawer takes over). The current page is marked with
 * `aria-current="page"` (set by NavLink).
 * The footer shows who is signed in.
 */
import React from 'react';
import { NavLink } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { UserMenu } from './UserMenu';

export interface NavItem {
  to: string;
  label: string;
  Icon: LucideIcon;
}

interface SidebarNavProps {
  navItems: NavItem[];
  adminName: string;
}

export const SidebarNav: React.FC<SidebarNavProps> = ({ navItems, adminName }) => {
  // In the rail the labels are hidden, so give sighted pointer users a native tooltip.
  const { isDesktop } = useBreakpoint();

  return (
    <aside className="sidebar" aria-label="Admin navigation">
      <div className="sidebar-brand">
        <BrandWordmark className="wordmark-lg" />
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
        <UserMenu adminName={adminName} />
      </div>
    </aside>
  );
};
