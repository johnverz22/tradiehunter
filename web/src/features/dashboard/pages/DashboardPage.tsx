import React from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { useDashboardStats, useDashboardMetrics } from '../hooks/useDashboard';
import { useJobList } from '../../jobs/hooks/useJobs';
import { useDisputeList } from '../../disputes/hooks/useDisputes';
import { useUserList } from '../../users/hooks/useUsers';
import { StatusBadge } from '../../../components/StatusBadge';

function describeStatsError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    if (!error.response) {
      return (
        `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. ` +
        'Check the backend is running (docker compose up), VITE_API_URL is correct, and CORS allows this origin.'
      );
    }
    const status = error.response.status;
    if (status === 401 || status === 403)
      return 'Your session is not authorized (401/403). Try logging in again as an Admin.';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

function formatJobId(id: number): string {
  return `JOB-${String(id).padStart(5, '0')}`;
}

export const DashboardPage: React.FC = () => {
  const {
    data: stats,
    isLoading: statsLoading,
    isError: statsError,
    error: statsErrObj,
    refetch: refetchStats,
  } = useDashboardStats();

  // P8-08: marketplace-health metrics (activation, match/payment timing, response).
  const { data: metrics } = useDashboardMetrics();
  const window30 = metrics?.last30Days;

  // Supporting tables — independent queries so one failure doesn't blank the page.
  const { data: jobsData, isLoading: jobsLoading } = useJobList({ page: 1, pageSize: 5 });
  const { data: disputesData, isLoading: disputesLoading } = useDisputeList({
    page: 1,
    pageSize: 5,
  });
  const { data: usersData, isLoading: usersLoading } = useUserList({
    role: 'Tradie',
    page: 1,
    pageSize: 20,
  });

  if (statsLoading) {
    return (
      <div className="flex items-center justify-center h-64 text-[var(--ink-soft)]">
        Loading dashboard…
      </div>
    );
  }

  if (statsError || !stats) {
    return (
      <div className="space-y-4 max-w-lg">
        <h1
          className="text-[28px] font-bold text-[var(--ink)]"
          style={{ fontFamily: 'var(--font-display)' }}
        >
          Dashboard
        </h1>
        <div
          role="alert"
          className="bg-red-50 border border-red-200 rounded p-4 text-sm text-[var(--red)]"
        >
          <p className="font-semibold mb-1">Failed to load dashboard stats.</p>
          <p>{describeStatsError(statsErrObj)}</p>
        </div>
        <button
          onClick={() => refetchStats()}
          className="btn btn-ghost"
        >
          Retry
        </button>
      </div>
    );
  }

  const pendingVerifications =
    usersData?.items.filter((u) => !u.isVerified).slice(0, 5) ?? [];

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1
          className="text-[28px] font-bold text-[var(--ink)]"
          style={{ fontFamily: 'var(--font-display)' }}
        >
          Dashboard
        </h1>
        <span className="pill pill-brand">
          Admin
        </span>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {(
          [
            ['Total Users', stats.totalUsers, 'var(--ink)'],
            ['Active Jobs', stats.activeJobs, 'var(--ink)'],
            ['Flagged Disputes', stats.pendingDisputes, 'var(--red-ink)'],
            ['Pending Verifications', stats.todaySignups, 'var(--amber-ink)'],
          ] as [string, number, string][]
        ).map(([label, value, color]) => (
          <div key={label} className="card !p-5">
            <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">{label}</div>
            <div
              className="text-[28px] font-semibold leading-tight"
              style={{ fontFamily: 'var(--font-mono)', color }}
            >
              {value.toLocaleString()}
            </div>
          </div>
        ))}
      </div>

      {/* ── P8-08: marketplace health ─────────────────────────────── */}
      {window30 && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2
              className="text-[18px] font-semibold text-[var(--ink)]"
              style={{ fontFamily: 'var(--font-display)' }}
            >
              Marketplace Health · last 30 days
            </h2>
            <span className="text-[13px] text-[var(--ink)] opacity-60">
              {window30.totalJobs} jobs · {window30.totalSignups} signups
            </span>
          </div>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {(
              [
                ['Activation rate', `${window30.activationRatePct.toFixed(1)}%`],
                [
                  'Match → payment',
                  `${(window30.avgMatchToAwaitingPaymentHours ?? window30.avgMatchToConfirmationHours).toFixed(1)}h`,
                ],
                [
                  'Payment verification',
                  `${(window30.avgPaymentVerificationHours ?? 0).toFixed(1)}h`,
                ],
                ['Tradie response', `${window30.tradieResponseRatePct.toFixed(1)}%`],
              ] as [string, string][]
            ).map(([label, value]) => (
              <div key={label} className="card !p-5">
                <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">{label}</div>
                <div
                  className="text-[28px] font-semibold leading-tight"
                  style={{ fontFamily: 'var(--font-mono)' }}
                >
                  {value}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ── Flagged disputes ─────────────────────────────────────────── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Flagged Disputes
          </h2>
          <Link
            to="/disputes"
            className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
          >
            View all
          </Link>
        </div>
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                {['Job ID', 'Issue', 'Reported By', 'Date', 'Status', 'Action'].map((h) => (
                  <th key={h} className="th">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {disputesLoading ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    Loading disputes…
                  </td>
                </tr>
              ) : !disputesData || disputesData.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    No flagged disputes
                  </td>
                </tr>
              ) : (
                disputesData.items.map((d) => (
                  <tr key={d.jobId}>
                    <td className="td mono">{formatJobId(d.jobId)}</td>
                    <td className="td">
                      {d.flagReason ?? d.jobTitle}
                    </td>
                    <td className="td">{d.homeownerName}</td>
                    <td className="td cell-muted">
                      {new Date(d.flaggedAtUtc).toLocaleDateString()}
                    </td>
                    <td className="td">
                      <StatusBadge status={d.disputeStatus} />
                    </td>
                    <td className="td">
                      <Link to={`/disputes/${d.jobId}`} className="action-link">
                        Review
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Recent jobs ──────────────────────────────────────────────── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Recent Jobs
          </h2>
          <Link
            to="/jobs"
            className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
          >
            View all
          </Link>
        </div>
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                {['Job ID', 'Description', 'Homeowner', 'Tradie', 'Status', 'Posted'].map((h) => (
                  <th key={h} className="th">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {jobsLoading ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    Loading recent jobs…
                  </td>
                </tr>
              ) : !jobsData || jobsData.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="td text-center cell-muted">
                    No jobs yet
                  </td>
                </tr>
              ) : (
                jobsData.items.map((j) => (
                  <tr key={j.id}>
                    <td className="td mono">
                      <Link to={`/jobs/${j.id}`} className="cell-link">
                        {formatJobId(j.id)}
                      </Link>
                    </td>
                    <td className="td">{j.title}</td>
                    <td className="td">{j.homeownerName}</td>
                    <td className="td cell-muted">{j.tradeName ?? '—'}</td>
                    <td className="td">
                      <StatusBadge status={j.status} />
                    </td>
                    <td className="td cell-muted">
                      {new Date(j.createdAtUtc).toLocaleDateString()}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Pending verifications ────────────────────────────────────── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Pending Verifications
          </h2>
          <Link
            to="/users"
            className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
          >
            View all
          </Link>
        </div>
        <div className="table-container">
          <table className="table">
            <thead>
              <tr>
                {['Name', 'Trade', 'Email', 'Applied', 'Action'].map((h) => (
                  <th key={h} className="th">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {usersLoading ? (
                <tr>
                  <td colSpan={5} className="td text-center cell-muted">
                    Loading verifications…
                  </td>
                </tr>
              ) : pendingVerifications.length === 0 ? (
                <tr>
                  <td colSpan={5} className="td text-center cell-muted">
                    No pending verifications
                  </td>
                </tr>
              ) : (
                pendingVerifications.map((u) => (
                  <tr key={u.id}>
                    <td className="td">{u.fullName}</td>
                    <td className="td"><StatusBadge status={u.role} /></td>
                    <td className="td mono cell-muted">{u.email}</td>
                    <td className="td cell-muted">
                      {new Date(u.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="td">
                      <Link to={`/users/${u.id}`} className="action-link">
                        Verify
                      </Link>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
