/**
 * AppShell — responsive application shell.
 *
 * Desktop (>=1024px):
 *   Fixed 240px SidebarNav, main p-8 + max-w-6xl, theme toggle top-right of content.
 * Tablet (640-1023px):
 *   64px icon rail SidebarNav, TopBar (56px), main p-6.
 * Phone (<640px):
 *   No persistent sidebar, sticky TopBar (56px + safe-area top), MobileDrawer overlay, main p-4.
 */
import React, { useState } from 'react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { ThemeToggle } from '../components/ThemeToggle';
import { SidebarNav, type NavItem } from './SidebarNav';
import { TopBar } from './TopBar';
import { MobileDrawer } from './MobileDrawer';

interface AppShellProps {
  navItems: NavItem[];
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  adminName: string;
  onLogout: () => void;
  children: React.ReactNode;
}

export const AppShell: React.FC<AppShellProps> = ({
  navItems,
  theme,
  onToggleTheme,
  adminName,
  onLogout,
  children,
}) => {
  const { isPhone, isDesktop } = useBreakpoint();
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    <div className="flex h-dvh bg-[var(--paper)] text-[var(--ink)] overflow-hidden">
      {/* Skip to content link */}
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:z-[60] focus:top-2 focus:left-2 focus:px-4 focus:py-2 focus:rounded focus:bg-[var(--brand-700)] focus:text-white focus:text-sm shadow-md"
      >
        Skip to content
      </a>

      {/* Desktop / Tablet Sidebar (hidden on phone) */}
      <SidebarNav
        navItems={navItems}
        adminName={adminName}
        onLogout={onLogout}
      />

      {/* Mobile Drawer (phone + tablet overlay) */}
      <MobileDrawer
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        navItems={navItems}
        adminName={adminName}
        onLogout={onLogout}
      />

      {/* Main column */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
        {/* TopBar on phone and tablet (hidden on desktop) */}
        {!isDesktop && (
          <TopBar
            onOpenDrawer={() => setDrawerOpen(true)}
            isDrawerOpen={drawerOpen}
            navItems={navItems}
            theme={theme}
            onToggleTheme={onToggleTheme}
            adminName={adminName}
            onLogout={onLogout}
            isPhone={isPhone}
          />
        )}

        {/* Scrollable main content */}
        <main
          id="main-content"
          tabIndex={-1}
          className={[
            'relative flex-1 overflow-auto focus:outline-none',
            isPhone ? 'p-4' : !isDesktop ? 'p-6' : 'p-8',
          ].join(' ')}
          style={isPhone ? { paddingBottom: 'max(var(--safe-bottom), 16px)' } : undefined}
        >
          <div className="max-w-6xl mx-auto w-full">
            {isDesktop && (
              <div className="flex justify-end mb-4">
                <ThemeToggle theme={theme} onToggle={onToggleTheme} />
              </div>
            )}
            {children}
          </div>
        </main>
      </div>
    </div>
  );
};
