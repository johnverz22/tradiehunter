import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { StatGrid } from '../../../components/StatGrid';
import { StatCard } from '../../../components/StatCard';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
import { StatusBadge } from '../../../components/StatusBadge';
import { formatDate, formatHours } from '../../../utils/format';
import { useDashboardStats, useDashboardMetrics } from '../hooks/useDashboard';
import { useJobList } from '../../jobs/hooks/useJobs';
import { useDisputeList } from '../../disputes/hooks/useDisputes';
import { useUserList } from '../../users/hooks/useUsers';
import { useCredentialQueue } from '../../credentials/hooks/useCredentials';
import type { AdminJobSummary, AdminUserListItem, AdminDisputeListItem } from '../../../services/adminApi';

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
  const navigate = useNavigate();
  const {
    data: stats,
    isLoading: statsLoading,
    isError: statsError,
    error: statsErrObj,
    refetch: refetchStats,
  } = useDashboardStats();

  // P8-08: marketplace-health metrics
  const { data: metrics } = useDashboardMetrics();
  const window30 = metrics?.last30Days;

  // Same query the Credentials page uses
  const { data: credentialQueue } = useCredentialQueue({ page: 1, pageSize: 1 });

  // Supporting tables
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
        <PageHeader title="Dashboard" />
        <Banner variant="error" action={{ label: 'Retry', onClick: () => refetchStats() }}>
          <div>
            <p className="font-semibold mb-1">Failed to load dashboard stats.</p>
            <p>{describeStatsError(statsErrObj)}</p>
          </div>
        </Banner>
      </div>
    );
  }

  const pendingVerifications =
    usersData?.items.filter((u) => !u.isVerified).slice(0, 5) ?? [];

  // Dispute columns
  const disputeColumns: ColumnDef<AdminDisputeListItem>[] = [
    {
      key: 'jobId',
      header: 'Job ID',
      priority: 'detail',
      cell: (d) => <span className="mono">{formatJobId(d.jobId)}</span>,
    },
    {
      key: 'issue',
      header: 'Issue',
      priority: 'primary',
      cell: (d) => (
        <span className="font-medium text-[var(--ink)]">
          {d.flagReason ?? d.jobTitle}
        </span>
      ),
    },
    {
      key: 'reportedBy',
      header: 'Reported By',
      priority: 'detail',
      cell: (d) => d.homeownerName,
    },
    {
      key: 'date',
      header: 'Date',
      priority: 'detail',
      cell: (d) => <span className="cell-muted">{formatDate(d.flaggedAtUtc)}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (d) => <StatusBadge status={d.disputeStatus} />,
    },
  ];

  const disputeActions = (d: AdminDisputeListItem): RowAction[] => [
    {
      label: 'Review',
      onClick: () => navigate(`/disputes/${d.jobId}`),
      variant: 'ghost',
      primary: true,
    },
  ];

  // Recent job columns
  const jobColumns: ColumnDef<AdminJobSummary>[] = [
    {
      key: 'id',
      header: 'Job ID',
      priority: 'detail',
      cell: (j) => (
        <Link to={`/jobs/${j.id}`} className="cell-link mono">
          {formatJobId(j.id)}
        </Link>
      ),
    },
    {
      key: 'title',
      header: 'Description',
      priority: 'primary',
      cell: (j) => (
        <Link to={`/jobs/${j.id}`} className="cell-link font-medium">
          {j.title}
        </Link>
      ),
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (j) => j.homeownerName,
    },
    {
      key: 'trade',
      header: 'Tradie',
      priority: 'detail',
      cell: (j) => <span className="cell-muted">{j.tradeName ?? '—'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (j) => <StatusBadge status={j.status} />,
    },
    {
      key: 'date',
      header: 'Posted',
      priority: 'detail',
      cell: (j) => <span className="cell-muted">{formatDate(j.createdAtUtc)}</span>,
    },
  ];

  // Verification columns
  const verificationColumns: ColumnDef<AdminUserListItem>[] = [
    {
      key: 'name',
      header: 'Name',
      priority: 'primary',
      cell: (u) => (
        <Link to={`/users/${u.id}`} className="cell-link font-medium">
          {u.fullName}
        </Link>
      ),
    },
    {
      key: 'trade',
      header: 'Trade',
      priority: 'secondary',
      cell: (u) => <StatusBadge status={u.role} />,
    },
    {
      key: 'email',
      header: 'Email',
      priority: 'detail',
      cell: (u) => <span className="mono cell-muted text-xs">{u.email}</span>,
    },
    {
      key: 'applied',
      header: 'Applied',
      priority: 'detail',
      cell: (u) => <span className="cell-muted">{formatDate(u.createdAtUtc)}</span>,
    },
  ];

  const verificationActions = (u: AdminUserListItem): RowAction[] => [
    {
      label: 'Verify',
      onClick: () => navigate(`/users/${u.id}`),
      variant: 'ghost',
      primary: true,
    },
  ];

  return (
    <div className="space-y-8">
      <PageHeader
        title="Dashboard"
        badge={<span className="pill pill-brand">Admin</span>}
      />

      {/* Needs-action cards */}
      <StatGrid>
        <StatCard
          label="Pending Verifications"
          value={credentialQueue?.totalCount}
          color="var(--amber-ink)"
          to="/credentials"
          hint="Needs action"
        />
        <StatCard
          label="Flagged Disputes"
          value={stats.pendingDisputes}
          color="var(--red-ink)"
          to="/disputes"
          hint="Needs action"
        />
        <StatCard
          label="Active Jobs"
          value={stats.activeJobs}
          color="var(--ink)"
          to="/jobs"
        />
        <StatCard
          label="Total Users"
          value={stats.totalUsers}
          color="var(--ink)"
          to="/users"
        />
      </StatGrid>

      {/* ── P8-08: marketplace health ─────────────────────────────── */}
      {window30 && (
        <div className="space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
            <h2
              className="text-[18px] font-semibold text-[var(--ink)] m-0"
              style={{ fontFamily: 'var(--font-display)' }}
            >
              Marketplace Health · last 30 days
            </h2>
            <span className="text-[13px] text-[var(--ink)] opacity-60">
              {window30.totalJobs} jobs · {window30.totalSignups} signups
            </span>
          </div>
          <StatGrid>
            <StatCard
              label="Activation rate"
              value={`${window30.activationRatePct.toFixed(1)}%`}
            />
            <StatCard
              label="Match → payment"
              value={formatHours(window30.avgMatchToAwaitingPaymentHours)}
            />
            <StatCard
              label="Payment verification"
              value={formatHours(window30.avgPaymentVerificationHours)}
            />
            <StatCard
              label="Tradie response"
              value={`${window30.tradieResponseRatePct.toFixed(1)}%`}
            />
          </StatGrid>
        </div>
      )}

      {/* ── Flagged disputes ─────────────────────────────────────────── */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)] m-0"
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
        <DataTable
          columns={disputeColumns}
          rows={disputesData?.items}
          getRowKey={(d) => d.jobId}
          onRowClick={(d) => navigate(`/disputes/${d.jobId}`)}
          isLoading={disputesLoading}
          rowActions={disputeActions}
          empty="No flagged disputes"
        />
      </div>

      {/* ── Recent jobs ──────────────────────────────────────────────── */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)] m-0"
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
        <DataTable
          columns={jobColumns}
          rows={jobsData?.items}
          getRowKey={(j) => j.id}
          onRowClick={(j) => navigate(`/jobs/${j.id}`)}
          isLoading={jobsLoading}
          empty="No jobs yet"
        />
      </div>

      {/* ── Pending verifications ────────────────────────────────────── */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)] m-0"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Unverified tradies
          </h2>
          <Link
            to="/credentials"
            className="text-[13px] text-[var(--brand-500)] font-medium hover:underline"
          >
            Review credentials
          </Link>
        </div>
        <DataTable
          columns={verificationColumns}
          rows={pendingVerifications}
          getRowKey={(u) => u.id}
          onRowClick={(u) => navigate(`/users/${u.id}`)}
          isLoading={usersLoading}
          rowActions={verificationActions}
          empty="No unverified tradies"
        />
      </div>
    </div>
  );
};
