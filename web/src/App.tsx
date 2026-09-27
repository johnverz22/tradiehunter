import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { jwtDecode } from 'jwt-decode';

import AdminLayout from './layout/AdminLayout';
import { AdminLogin } from './features/auth/AdminLogin';
import Forbidden from './pages/Forbidden';

// ── Lazy-loaded feature pages ─────────────────────────────────────────────────
const Dashboard = React.lazy(() =>
  import('./features/dashboard/pages/DashboardPage').then((m) => ({ default: m.DashboardPage })),
);
const UserList = React.lazy(() =>
  import('./features/users/pages/UserListPage').then((m) => ({ default: m.UserListPage })),
);
const UserDetail = React.lazy(() =>
  import('./features/users/pages/UserDetailPage').then((m) => ({ default: m.UserDetailPage })),
);
const JobList = React.lazy(() =>
  import('./features/jobs/pages/JobListPage').then((m) => ({ default: m.JobListPage })),
);
const JobDetail = React.lazy(() =>
  import('./features/jobs/pages/JobDetailPage').then((m) => ({ default: m.JobDetailPage })),
);
const Disputes = React.lazy(() =>
  import('./features/disputes/pages/DisputesPage').then((m) => ({ default: m.DisputesPage })),
);
const DisputeDetail = React.lazy(() =>
  import('./features/disputes/pages/DisputeDetailPage').then((m) => ({
    default: m.DisputeDetailPage,
  })),
);
const Settings = React.lazy(() =>
  import('./features/settings/pages/SettingsPage').then((m) => ({ default: m.SettingsPage })),
);

// ── Auth helpers ──────────────────────────────────────────────────────────────

interface JwtClaims {
  role: string;
  exp: number;
}

export function getTokenClaims(): JwtClaims | null {
  const token = localStorage.getItem('jwt_token');
  if (!token) return null;
  try {
    return jwtDecode<JwtClaims>(token);
  } catch {
    return null;
  }
}

export function isAdminAuthenticated(): boolean {
  const claims = getTokenClaims();
  if (!claims) return false;
  if (claims.exp * 1000 < Date.now()) return false;
  return claims.role === 'Admin';
}

// ── Route guards ──────────────────────────────────────────────────────────────

/**
 * Requires a valid, non-expired JWT with the Admin role.
 * - No token / expired token → redirect to /login.
 * - Valid token but wrong role → show 403.
 */
const RequireAdmin: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const token = localStorage.getItem('jwt_token');

  if (!token) return <Navigate to="/login" replace />;

  let claims: JwtClaims;
  try {
    claims = jwtDecode<JwtClaims>(token);
  } catch {
    return <Navigate to="/login" replace />;
  }

  // Expired token
  if (claims.exp * 1000 < Date.now()) {
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('refresh_token');
    return <Navigate to="/login" replace />;
  }

  // Authenticated but not admin
  if (claims.role !== 'Admin') return <Navigate to="/403" replace />;

  return <>{children}</>;
};

// ── App ───────────────────────────────────────────────────────────────────────

function App() {
  return (
    <React.Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center bg-[var(--paper)]">
          <span className="text-[var(--ink-soft)] text-sm">Loading…</span>
        </div>
      }
    >
      <Routes>
        {/* Public */}
        <Route path="/login" element={<AdminLogin />} />
        <Route path="/403" element={<Forbidden />} />
        <Route path="/" element={<Navigate to="/dashboard" replace />} />

        {/* Protected admin routes */}
        <Route
          element={
            <RequireAdmin>
              <AdminLayout />
            </RequireAdmin>
          }
        >
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="users" element={<UserList />} />
          <Route path="users/:id" element={<UserDetail />} />
          <Route path="jobs" element={<JobList />} />
          <Route path="jobs/:id" element={<JobDetail />} />
          <Route path="disputes" element={<Disputes />} />
          <Route path="disputes/:jobId" element={<DisputeDetail />} />
          <Route path="settings" element={<Settings />} />
        </Route>

        {/* Catch-all */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </React.Suspense>
  );
}

export default App;
