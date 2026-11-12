/**
 * TopBar — sticky top navigation bar for phone (<640px) and tablet (640-1023px).
 *
 * Height: 56px + env(safe-area-inset-top).
 * Phone:
 *   [≡] BrandWordmark [Page Title (truncated)] [Theme Toggle] [User avatar/logout]
 * Tablet:
 *   [≡] [Theme Toggle]
 */
import React from 'react';
import { useLocation } from 'react-router-dom';
import { Menu, UserRound, LogOut } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { ThemeToggle } from '../components/ThemeToggle';
import type { NavItem } from './SidebarNav';

interface TopBarProps {
  onOpenDrawer: () => void;
  isDrawerOpen: boolean;
  navItems: NavItem[];
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  adminName: string;
  onLogout: () => void;
  isPhone: boolean;
}

export const TopBar: React.FC<TopBarProps> = ({
  onOpenDrawer,
  isDrawerOpen,
  navItems,
  theme,
  onToggleTheme,
  adminName,
  onLogout,
  isPhone,
}) => {
  const location = useLocation();

  // Find matching nav title or fallback
  const currentNav = navItems.find((item) =>
    location.pathname === item.to || (item.to !== '/dashboard' && location.pathname.startsWith(item.to)),
  );
  const pageTitle = currentNav?.label ?? '';

  return (
    <header
      className="sticky top-0 z-30 flex items-center justify-between bg-[var(--surface)] border-b border-[var(--paper-line)] px-4 lg:hidden shrink-0 shadow-sm"
      style={{
        height: 'calc(var(--topbar-height) + var(--safe-top))',
        paddingTop: 'var(--safe-top)',
      }}
    >
      <div className="flex items-center gap-3 min-w-0">
        <button
          onClick={onOpenDrawer}
          aria-expanded={isDrawerOpen}
          aria-controls="mobile-nav-drawer"
          aria-label="Open navigation menu"
          className="p-2 -ml-2 rounded text-[var(--ink-soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)] transition-colors min-h-[44px] min-w-[44px] flex items-center justify-center shrink-0"
        >
          <Menu size={22} aria-hidden="true" />
        </button>

        {isPhone ? (
          <div className="flex items-center gap-2 min-w-0">
            <BrandWordmark className="font-bold text-[18px] text-[var(--brand-900)] dark:text-white shrink-0" />
            {pageTitle && (
              <>
                <span className="text-[var(--paper-line)] dark:text-white/20 select-none">/</span>
                <span className="text-sm font-semibold text-[var(--ink)] truncate max-w-[120px]">
                  {pageTitle}
                </span>
              </>
            )}
          </div>
        ) : (
          <div className="text-base font-semibold text-[var(--ink)] truncate">
            {pageTitle}
          </div>
        )}
      </div>

      <div className="flex items-center gap-1 shrink-0">
        <ThemeToggle theme={theme} onToggle={onToggleTheme} />

        {isPhone && (
          <details className="relative">
            <summary
              className="p-1 rounded-full list-none cursor-pointer flex items-center justify-center min-h-[44px] min-w-[44px]"
              aria-label={`User account: ${adminName}`}
            >
              <span
                className="w-8 h-8 rounded-full bg-[var(--brand-100)] flex items-center justify-center text-[var(--brand-700)]"
                aria-hidden="true"
              >
                <UserRound size={16} />
              </span>
            </summary>
            <div className="absolute right-0 top-full mt-2 w-48 surface shadow-[var(--shadow-pop)] rounded p-2 z-50">
              <div className="px-3 py-2 border-b border-[var(--paper-line)]">
                <p className="text-xs font-semibold text-[var(--ink)] truncate">{adminName}</p>
                <p className="text-[10px] text-[var(--ink-soft)]">Administrator</p>
              </div>
              <button
                onClick={onLogout}
                className="w-full flex items-center gap-2 px-3 py-2 text-sm text-[var(--red)] hover:bg-red-50 dark:hover:bg-red-900/20 rounded mt-1 min-h-[44px]"
              >
                <LogOut size={14} aria-hidden="true" />
                Logout
              </button>
            </div>
          </details>
        )}
      </div>
    </header>
  );
};
