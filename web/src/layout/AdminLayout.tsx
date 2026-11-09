import api from "../services/api";
import { useAppName } from "../features/branding/hooks/useBrandConfig";
import { BrandWordmark } from "../features/branding/components/BrandWordmark";

import React, { useCallback, useEffect, useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Briefcase,
  ShieldCheck,
  AlertTriangle,
  Wallet,
  RotateCcw,
  ScrollText,
  Settings,
  LogOut,
  UserRound,
  Sun,
  Moon,
  Banknote,
} from 'lucide-react';

type ThemeMode = 'light' | 'dark';

function getInitialTheme(): ThemeMode {
  const stored = localStorage.getItem('fixo-theme');
  if (stored === 'light' || stored === 'dark') return stored;
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

const navItems = [
  { to: '/dashboard', label: 'Dashboard', Icon: LayoutDashboard },
  { to: '/users', label: 'Users', Icon: Users },
  { to: '/jobs', label: 'Jobs', Icon: Briefcase },
  { to: '/credentials', label: 'Credentials', Icon: ShieldCheck },
  { to: '/payments', label: 'Payments', Icon: Wallet },
  { to: '/payouts', label: 'Payouts', Icon: Banknote },
  { to: '/refunds', label: 'Refunds', Icon: RotateCcw },
  { to: '/disputes', label: 'Disputes', Icon: AlertTriangle },
  { to: '/audit-logs', label: 'Audit Logs', Icon: ScrollText },
  { to: '/settings', label: 'Settings', Icon: Settings },
];
const AdminLayout: React.FC = () => {
  const navigate = useNavigate();
  const [theme, setTheme] = useState<ThemeMode>(getInitialTheme);
  const appName = useAppName();

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("fixo-theme", theme);
  }, [theme]);

  // The static <title> in index.html is the pre-config paint; once the brand
  // name is known it takes over so the tab matches a partner's rebrand.
  useEffect(() => {
    document.title = `${appName} Admin`;
  }, [appName]);


  const [adminName, setAdminName] = useState<string>('Admin');

  useEffect(() => {
    // Fetch profile instead of parsing JWT
    api.get('/auth/admin-me').then(res => {
      if (res.data.name) setAdminName(res.data.name);
    }).catch(() => {});
  }, []);

  const handleLogout = useCallback(async () => {
    try {
      await api.post('/auth/admin-logout');
    } finally {
      navigate('/login', { replace: true });
    }
  }, [navigate]);

  return (
    <div className="flex h-screen bg-[var(--paper)] text-[var(--ink)]">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:z-[60] focus:top-2 focus:left-2 focus:px-4 focus:py-2 focus:rounded focus:bg-[var(--brand-700)] focus:text-white focus:text-sm"
      >
        Skip to content
      </a>

      <aside className="w-60 bg-[var(--brand-900)] text-white flex flex-col shrink-0">
        <div className="px-6 pt-6 pb-8">
          <BrandWordmark
            className="font-bold text-[22px] text-white"
          />
        </div>

        <nav className="flex-1 flex flex-col" aria-label="Admin navigation">
          {navItems.map(({ to, label, Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                [
                  'flex items-center gap-3 px-6 py-3 text-sm font-medium transition-all',
                  isActive
                    ? 'bg-white/15 border-l-[3px] border-[var(--amber)] opacity-100'
                    : 'opacity-70 hover:opacity-100 hover:bg-white/10 border-l-[3px] border-transparent',
                ].join(' ')
              }
            >
              <Icon size={16} aria-hidden="true" />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-white/10 p-4">
          {/* Profile + logout combined */}
          <div className="flex items-center gap-3 px-1">
            <span
              className="w-9 h-9 rounded-full bg-white/15 flex items-center justify-center shrink-0"
              aria-hidden="true"
            >
              <UserRound size={16} className="text-white" />
            </span>
            <span className="min-w-0 flex-1">
              <span
                className="block text-[13px] font-medium text-white truncate"
                title={adminName ?? 'Admin'}
              >
                {adminName ?? 'Admin'}
              </span>
              <span className="block text-[11px] text-white/60">Administrator</span>
            </span>
            <button
              onClick={handleLogout}
              title="Logout"
              aria-label="Logout"
              className="p-2 rounded text-white/70 hover:text-white hover:bg-white/10 transition-colors shrink-0"
            >
              <LogOut size={15} aria-hidden="true" />
            </button>
          </div>
        </div>
      </aside>

      <main id="main-content" tabIndex={-1} className="relative flex-1 overflow-auto p-8 focus:outline-none">
        <button
          onClick={() => setTheme((t) => (t === 'light' ? 'dark' : 'light'))}
          title={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
          aria-label={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
          className="absolute top-4 right-6 p-2 rounded-full border border-[var(--paper-line)] bg-[var(--paper)] text-[var(--ink-soft)] hover:text-[var(--ink)] shadow-sm transition-colors"
        >
          {theme === 'light' ? <Moon size={16} /> : <Sun size={16} />}
        </button>
        <div className="max-w-6xl mx-auto">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default AdminLayout;
