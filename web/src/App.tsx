import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';

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
const CredentialQueue = React.lazy(() =>
  import('./features/credentials/pages/CredentialQueue').then((m) => ({
    default: m.CredentialQueue,
  })),
);
const DisputeDetail = React.lazy(() =>
  import('./features/disputes/pages/DisputeDetailPage').then((m) => ({
    default: m.DisputeDetailPage,
  })),
);
const PaymentQueue = React.lazy(() =>
  import('./features/payments/pages/PaymentQueue').then((m) => ({
    default: m.PaymentQueue,
  })),
);
const Settings = React.lazy(() =>
  import('./features/settings/pages/SettingsPage').then((m) => ({ default: m.SettingsPage })),
);
const RefundQueue = React.lazy(() =>
  import('./features/refunds/pages/RefundQueue').then((m) => ({ default: m.RefundQueue })),
);
const PayoutQueue = React.lazy(() =>
  import('./features/payouts/pages/PayoutQueue').then((m) => ({ default: m.PayoutQueue })),
);
const PayoutBatches = React.lazy(() =>
  import('./features/payouts/pages/PayoutBatches').then((m) => ({ default: m.PayoutBatches })),
);
const PayoutBatchDetail = React.lazy(() =>
  import('./features/payouts/pages/PayoutBatchDetail').then((m) => ({
    default: m.PayoutBatchDetail,
  })),
);
const AuditLogs = React.lazy(() =>
  import('./features/admin/AuditLogs').then((m) => ({ default: m.AuditLogs })),
);

import { useEffect, useState } from 'react';
import api from './services/api';

// ── Auth helpers ──────────────────────────────────────────────────────────────

export function isAdminAuthenticated(): Promise<boolean> {
  return api.get('/auth/admin-me')
    .then(() => true)
    .catch(() => false);
}

// ── Route guards ──────────────────────────────────────────────────────────────

/**
 * Requires an active AdminCookie session.
 * Checks via GET /api/auth/admin-me on mount.
 */
const RequireAdmin: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

  useEffect(() => {
    isAdminAuthenticated().then(setIsAuthenticated);
  }, []);

  if (isAuthenticated === null) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[var(--paper)]">
        <span className="text-[var(--ink-soft)] text-sm">Checking session…</span>
      </div>
    );
  }

  if (!isAuthenticated) return <Navigate to="/login" replace />;

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
          <Route path="credentials" element={<CredentialQueue />} />
          <Route path="payments" element={<PaymentQueue />} />
          <Route path="payouts" element={<PayoutQueue />} />
          <Route path="payouts/batches" element={<PayoutBatches />} />
          <Route path="payouts/batches/:id" element={<PayoutBatchDetail />} />
          <Route path="disputes" element={<Disputes />} />
          <Route path="disputes/:jobId" element={<DisputeDetail />} />
          <Route path="refunds" element={<RefundQueue />} />
          <Route path="audit-logs" element={<AuditLogs />} />
          <Route path="settings" element={<Settings />} />
        </Route>

        {/* Catch-all */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </React.Suspense>
  );
}

export default App;
