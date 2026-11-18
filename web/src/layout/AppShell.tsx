/**
 * AppShell — responsive application shell (kit `.app` > `.sidebar` + `.app-main`).
 *
 * Desktop (>=1024px):
 *   Full 240px SidebarNav; content is the kit `.page` (max 1280, gutters), theme
 *   toggle top-right of the content until TopBar renders on every width (task 2.18).
 * Tablet (640-1023px):
 *   64px icon rail SidebarNav, TopBar (56px), `.page`.
 * Phone (<640px):
 *   No persistent sidebar, sticky TopBar (56px + safe-area top), MobileDrawer overlay,
 *   `.page` with the phone gutters.
 *
 * The shell is locked to the viewport and `<main>` scrolls inside it, so the
 * sidebar and TopBar stay put (unchanged behaviour). SidebarNav, TopBar and
 * MobileDrawer still carry their legacy markup until tasks 2.17 and 2.18.
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
    <div className="app h-dvh overflow-hidden">
      {/* Skip to content link */}
      <a href="#main-content" className="skip-link">
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
      <div className="app-main h-full overflow-hidden">
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

        {/* Scroll container; the kit `.page` inside it sets width, gutters and spacing */}
        <div className="flex-1 overflow-auto pb-[var(--safe-bottom)]">
          <main id="main-content" tabIndex={-1} className="page">
            {isDesktop && (
              <div className="row end">
                <ThemeToggle theme={theme} onToggle={onToggleTheme} />
              </div>
            )}
            {children}
          </main>
        </div>
      </div>
    </div>
  );
};
