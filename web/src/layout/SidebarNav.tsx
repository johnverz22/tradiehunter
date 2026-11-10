/**
 * SidebarNav — desktop (240px fixed) + tablet icon rail (64px collapsed).
 * Renders nav items from the navItems array passed as a prop.
 * On desktop, also shows the theme toggle and user menu in the footer.
 */
import React from 'react';
import { NavLink } from 'react-router-dom';
import type { LucideIcon } from 'lucide-react';
import { Moon, Sun } from 'lucide-react';
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
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  onLogout: () => void;
}

export const SidebarNav: React.FC<SidebarNavProps> = ({
  navItems,
  adminName,
  theme,
  onToggleTheme,
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
    <div className="px-4 lg:px-6 pt-6 pb-8 overflow-hidden">
      {/* Desktop: full wordmark; tablet: just icon letter */}
      <BrandWordmark className="font-bold text-[22px] text-white hidden lg:block" />
      {/* Tablet icon placeholder */}
      <div className="lg:hidden flex justify-center">
        <span className="text-white font-bold text-xl" aria-hidden="true">F</span>
      </div>
    </div>

    {/* Nav items */}
    <nav className="flex-1 flex flex-col" aria-label="Admin navigation">
      {navItems.map(({ to, label, Icon }) => (
        <NavLink
          key={to}
          to={to}
          title={label}
          className={({ isActive }) =>
            [
              'flex items-center gap-3 py-3 text-sm font-medium transition-all',
              // Desktop: left padding; tablet: justify center, no label
              'px-4 lg:px-6 justify-center lg:justify-start',
              isActive
                ? 'bg-white/15 border-l-[3px] border-[var(--amber)] opacity-100'
                : 'opacity-70 hover:opacity-100 hover:bg-white/10 border-l-[3px] border-transparent',
            ].join(' ')
          }
        >
          <Icon size={18} aria-hidden="true" className="shrink-0" />
          <span className="hidden lg:inline">{label}</span>
        </NavLink>
      ))}
    </nav>

    {/* Footer — theme toggle + user menu (desktop only) */}
    <div className="border-t border-white/10 p-4">
      {/* Theme toggle — desktop inline, tablet icon only */}
      <div className="flex justify-center lg:justify-end mb-3">
        <button
          onClick={onToggleTheme}
          title={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
          aria-label={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
          className="p-2 rounded-full border border-white/20 bg-white/10 text-white/70 hover:text-white hover:bg-white/20 transition-colors min-h-[44px] min-w-[44px] flex items-center justify-center"
        >
          {theme === 'light' ? <Moon size={16} aria-hidden="true" /> : <Sun size={16} aria-hidden="true" />}
        </button>
      </div>

      {/* User menu — desktop only */}
      <div className="hidden lg:block">
        <UserMenu adminName={adminName} onLogout={onLogout} variant="dark" />
      </div>
    </div>
  </aside>
);
