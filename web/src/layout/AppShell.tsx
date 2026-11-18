/**
 * AppShell — responsive application shell (kit `.app` > `.sidebar` + `.app-main`).
 *
 * Desktop (>=1024px): full 240px SidebarNav; TopBar with the theme toggle; `.page` content (max 1280).
 * Tablet (640-1023px): 64px icon rail SidebarNav; same TopBar.
 * Phone (<640px): no persistent sidebar; TopBar with menu button, wordmark, theme and account
 *   menu (+ safe-area top); MobileDrawer overlay; `.page` with the phone gutters.
 *
 * The shell is locked to the viewport and `<main>` scrolls inside it, so the
 * sidebar and TopBar stay put (unchanged behaviour). The widths and what shows
 * where are decided by the kit CSS; `useBreakpoint` only tells the TopBar when to
 * show the account menu.
 */
import React, { useState } from 'react';
import { useBreakpoint } from '../hooks/useBreakpoint';
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
  const { isPhone } = useBreakpoint();
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
        <TopBar
          onOpenDrawer={() => setDrawerOpen(true)}
          isDrawerOpen={drawerOpen}
          theme={theme}
          onToggleTheme={onToggleTheme}
          adminName={adminName}
          onLogout={onLogout}
          isPhone={isPhone}
        />

        {/* Scroll container; the kit `.page` inside it sets width, gutters and spacing */}
        <div className="flex-1 overflow-auto pb-[var(--safe-bottom)]">
          <main id="main-content" tabIndex={-1} className="page">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
};
