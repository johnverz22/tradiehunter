/**
 * TopBar — sticky glass bar (kit `.topbar`), shown at every width.
 *
 * Height: 56px + env(safe-area-inset-top).
 * Phone:   [≡ menu] wordmark ··· [theme] [account menu]
 * Tablet / desktop: ··· [theme]   (navigation and the signed-in user live in the sidebar)
 *
 * The menu button and wordmark are phone-only through the kit (`.menu-btn`,
 * `.phone-only`). The page title is the page's own `h1`, so the bar does not
 * repeat it.
 */
import React from 'react';
import { Menu } from 'lucide-react';
import { BrandWordmark } from '../features/branding/components/BrandWordmark';
import { IconButton } from '../components/Button';
import { ThemeToggle } from '../components/ThemeToggle';
import { UserMenu } from './UserMenu';
import type { NavItem } from './SidebarNav';

interface TopBarProps {
  onOpenDrawer: () => void;
  isDrawerOpen: boolean;
  /** Kept for API stability; the bar no longer shows the current page title. */
  navItems?: NavItem[];
  theme: 'light' | 'dark';
  onToggleTheme: () => void;
  adminName: string;
  onLogout: () => void;
  isPhone: boolean;
}

export const TopBar: React.FC<TopBarProps> = ({
  onOpenDrawer,
  isDrawerOpen,
  theme,
  onToggleTheme,
  adminName,
  onLogout,
  isPhone,
}) => (
  <header
    className="topbar"
    style={{
      height: 'calc(var(--sz-topbar) + var(--safe-top))',
      paddingTop: 'var(--safe-top)',
    }}
  >
    <IconButton
      className="menu-btn"
      label="Open navigation menu"
      aria-expanded={isDrawerOpen}
      aria-controls="mobile-nav-drawer"
      onClick={onOpenDrawer}
    >
      <Menu size={20} />
    </IconButton>

    <BrandWordmark className="wordmark phone-only" />

    <span className="grow" />

    <ThemeToggle theme={theme} onToggle={onToggleTheme} />

    {isPhone && <UserMenu adminName={adminName} onLogout={onLogout} variant="light" />}
  </header>
);
