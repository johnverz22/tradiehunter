import api from "../services/api";
import { useAppName } from "../features/branding/hooks/useBrandConfig";

import React, { useCallback, useEffect, useState } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import { AppShell } from './AppShell';
import { navItems } from './navItems';

type ThemeMode = 'light' | 'dark';

function getInitialTheme(): ThemeMode {
  const stored = localStorage.getItem('fixo-theme');
  if (stored === 'light' || stored === 'dark') return stored;
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

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

  const toggleTheme = useCallback(() => {
    setTheme((t) => (t === 'light' ? 'dark' : 'light'));
  }, []);

  return (
    <AppShell
      navItems={navItems}
      theme={theme}
      onToggleTheme={toggleTheme}
      adminName={adminName}
      onLogout={handleLogout}
    >
      <Outlet />
    </AppShell>
  );
};

export default AdminLayout;
