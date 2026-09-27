import React from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { useDashboardStats } from '../hooks/useDashboard';
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
          className="px-4 py-2 text-sm rounded border border-[var(--paper-line)] text-[var(--ink-soft)] hover:bg-[var(--paper-line)] transition-colors"
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
        <span className="text-xs font-semibold px-3 py-1.5 rounded-full bg-[var(--brand-100)] text-[var(--brand-900)]">
          Admin
        </span>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-5 shadow-sm">
          <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">Total Users</div>
          <div
            className="text-[28px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-mono)' }}
          >
            {stats.totalUsers}
          </div>
        </div>
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-5 shadow-sm">
          <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">Active Jobs</div>
          <div
            className="text-[28px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-mono)' }}
          >
            {stats.activeJobs}
          </div>
        </div>
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-5 shadow-sm">
          <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">Flagged Disputes</div>
          <div
            className="text-[28px] font-semibold text-[var(--red)]"
            style={{ fontFamily: 'var(--font-mono)' }}
          >
            {stats.pendingDisputes}
          </div>
        </div>
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-5 shadow-sm">
          <div className="text-[13px] text-[var(--ink)] opacity-60 mb-2">Pending Verifications</div>
          <div
            className="text-[28px] font-semibold text-[var(--amber)]"
            style={{ fontFamily: 'var(--font-mono)' }}
          >
            {stats.todaySignups}
          </div>
        </div>
      </div>

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
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr>
                {['Job ID', 'Issue', 'Reported By', 'Date', 'Status', 'Action'].map((h) => (
                  <th
                    key={h}
                    className="text-left px-4 py-3.5 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {disputesLoading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    Loading disputes…
                  </td>
                </tr>
              ) : !disputesData || disputesData.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    No flagged disputes
                  </td>
                </tr>
              ) : (
                disputesData.items.map((d) => (
                  <tr
                    key={d.jobId}
                    className="bg-red-50/40 hover:bg-[var(--paper)]"
                  >
                    <td
                      className="px-4 py-3.5 text-sm text-[var(--ink)]"
                      style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}
                    >
                      {formatJobId(d.jobId)}
                    </td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">
                      {d.flagReason ?? d.jobTitle}
                    </td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{d.homeownerName}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">
                      {new Date(d.flaggedAtUtc).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3.5 text-sm">
                      <StatusBadge status={d.disputeStatus} />
                    </td>
                    <td className="px-4 py-3.5 text-sm">
                      <Link
                        to={`/disputes/${d.jobId}`}
                        className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
                      >
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
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr>
                {['Job ID', 'Description', 'Homeowner', 'Tradie', 'Status', 'Posted'].map((h) => (
                  <th
                    key={h}
                    className="text-left px-4 py-3.5 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {jobsLoading ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    Loading recent jobs…
                  </td>
                </tr>
              ) : !jobsData || jobsData.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    No jobs yet
                  </td>
                </tr>
              ) : (
                jobsData.items.map((j) => (
                  <tr key={j.id} className="hover:bg-[var(--paper)]">
                    <td
                      className="px-4 py-3.5 text-sm text-[var(--ink)]"
                      style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}
                    >
                      <Link
                        to={`/jobs/${j.id}`}
                        className="text-[var(--brand-500)] hover:underline"
                      >
                        {formatJobId(j.id)}
                      </Link>
                    </td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{j.title}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{j.homeownerName}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">
                      {j.tradeName ?? '—'}
                    </td>
                    <td className="px-4 py-3.5 text-sm">
                      <StatusBadge status={j.status} />
                    </td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">
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
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr>
                {['Name', 'Trade', 'Email', 'Applied', 'Action'].map((h) => (
                  <th
                    key={h}
                    className="text-left px-4 py-3.5 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {usersLoading ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    Loading verifications…
                  </td>
                </tr>
              ) : pendingVerifications.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-8 text-center text-sm text-[var(--ink-soft)]">
                    No pending verifications
                  </td>
                </tr>
              ) : (
                pendingVerifications.map((u) => (
                  <tr key={u.id} className="hover:bg-[var(--paper)]">
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{u.fullName}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{u.role}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">{u.email}</td>
                    <td className="px-4 py-3.5 text-sm text-[var(--ink)]">
                      {new Date(u.createdAtUtc).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3.5 text-sm">
                      <Link
                        to={`/users/${u.id}`}
                        className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
                      >
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
