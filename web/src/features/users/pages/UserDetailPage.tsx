import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { MoreHorizontal } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
import { DataTable, type ColumnDef } from '../../../components/DataTable';
import { Banner } from '../../../components/Banner';
import { useBreakpoint } from '../../../hooks/useBreakpoint';
import {
  useUserDetail,
  useVerifyUser,
  useDeactivateUser,
  useWarnUser,
  useSuspendUser,
  useResolveUserFlags,
} from '../hooks/useUsers';
import type { AccountFlag, AdminJobSummary } from '../../../services/adminApi';

function describeUserError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;
    if (!error.response) {
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. Check the backend is running and VITE_API_URL is correct.`;
    }
    if (status === 404) return 'No user exists with this ID (API returned 404).';
    if (status === 401 || status === 403)
      return 'Your session is not authorized for this user (401/403). Try logging in again.';
    const serverMsg =
      typeof error.response.data === 'object' &&
      error.response.data !== null &&
      'message' in error.response.data
        ? String((error.response.data as { message: unknown }).message)
        : null;
    return serverMsg ?? `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

export const UserDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { isPhone } = useBreakpoint();
  const { data: user, isLoading, isError, error, refetch } = useUserDetail(id ?? '');
  const verifyMutation = useVerifyUser();
  const deactivateMutation = useDeactivateUser();
  const warnMutation = useWarnUser();
  const suspendMutation = useSuspendUser();
  const resolveFlagsMutation = useResolveUserFlags();

  const [confirmModal, setConfirmModal] = useState<
    'verify' | 'deactivate' | 'warn' | 'suspend' | 'resolveFlags' | null
  >(null);
  const [actionReason, setActionReason] = useState('');

  if (!id) {
    return (
      <div className="space-y-4 p-4">
        <p className="text-[var(--red)] text-sm">No user ID in the URL.</p>
        <Link to="/users" className="text-sm text-[var(--brand-500)] hover:underline">
          ← Back to Users
        </Link>
      </div>
    );
  }

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading user…</div>;

  if (isError || !user) {
    return (
      <div className="space-y-4 max-w-lg">
        <Link
          to="/users"
          className="inline-flex items-center gap-1.5 text-sm text-[var(--ink-soft)] hover:text-[var(--ink)]"
        >
          ← Back to Users
        </Link>
        <Banner variant="error" action={{ label: 'Retry', onClick: () => refetch() }}>
          <div>
            <p className="font-semibold mb-1">User not found.</p>
            <p>{describeUserError(error)}</p>
            <p className="mt-2 text-xs opacity-80 mono">ID: {id}</p>
          </div>
        </Banner>
      </div>
    );
  }

  const handleAction = async () => {
    if (confirmModal === 'verify') await verifyMutation.mutateAsync(user.id);
    else if (confirmModal === 'deactivate') {
      await deactivateMutation.mutateAsync(user.id);
      navigate('/users');
    } else if (confirmModal === 'warn') {
      await warnMutation.mutateAsync({ id: user.id, reason: actionReason });
    } else if (confirmModal === 'suspend') {
      await suspendMutation.mutateAsync({ id: user.id, reason: actionReason });
    } else if (confirmModal === 'resolveFlags') {
      await resolveFlagsMutation.mutateAsync(user.id);
    }
    setConfirmModal(null);
    setActionReason('');
  };

  const initials = (user.fullName || 'U')
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const flagColumns: ColumnDef<AccountFlag>[] = [
    {
      key: 'type',
      header: 'Type',
      priority: 'primary',
      cell: (f) => <span className="font-medium">{f.type}</span>,
    },
    {
      key: 'counter',
      header: 'Counter',
      priority: 'secondary',
      cell: (f) => f.counter,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (f) => (
        <StatusBadge
          status={f.resolved ? 'Resolved' : f.thresholdHit ? 'ThresholdHit' : 'Open'}
        />
      ),
    },
    {
      key: 'date',
      header: 'Date',
      priority: 'detail',
      cell: (f) => new Date(f.createdAtUtc).toLocaleDateString(),
    },
  ];

  const recentJobColumns: ColumnDef<AdminJobSummary>[] = [
    {
      key: 'id',
      header: 'Job ID',
      priority: 'secondary',
      cell: (j) => <span className="mono">JOB-{String(j.id).padStart(5, '0')}</span>,
    },
    {
      key: 'title',
      header: 'Description',
      priority: 'primary',
      cell: (j) => j.title,
    },
    {
      key: 'homeowner',
      header: 'Homeowner',
      priority: 'detail',
      cell: (j) => j.homeownerName,
    },
    {
      key: 'status',
      header: 'Status',
      priority: 'secondary',
      cell: (j) => <StatusBadge status={j.status} />,
    },
    {
      key: 'date',
      header: 'Date',
      priority: 'detail',
      cell: (j) => new Date(j.createdAtUtc).toLocaleDateString(),
    },
  ];

  const actionButtons = (
    <>
      {!user.isVerified && user.role === 'Tradie' && (
        <button
          onClick={() => setConfirmModal('verify')}
          className="btn"
          style={{ background: 'var(--green)', color: '#fff' }}
        >
          Verify NZBN
        </button>
      )}
      {user.flags?.some((f) => !f.resolved) && (
        <button
          onClick={() => setConfirmModal('resolveFlags')}
          className="btn btn-ghost"
        >
          Resolve Flags
        </button>
      )}
      {user.isActive && (
        <>
          <button
            onClick={() => setConfirmModal('warn')}
            className="btn btn-ghost"
            style={{ color: 'var(--amber)' }}
          >
            Warn
          </button>
          <button
            onClick={() => setConfirmModal('suspend')}
            className="btn btn-ghost"
            style={{ color: 'var(--red)' }}
          >
            Suspend
          </button>
          <button
            onClick={() => setConfirmModal('deactivate')}
            className="btn btn-danger"
          >
            Deactivate
          </button>
        </>
      )}
    </>
  );

  return (
    <div className={`space-y-8 ${isPhone ? 'pb-24' : ''}`}>
      <div className="text-[13px] text-[var(--ink)] opacity-60">
        <Link to="/users" className="text-[var(--brand-500)] hover:underline">
          Users
        </Link>{' '}
        / {user.fullName}
      </div>

      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div className="flex items-center gap-5">
          <div
            className="w-16 h-16 rounded-full bg-[var(--brand-500)] flex items-center justify-center text-white font-semibold text-2xl shrink-0"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            {initials}
          </div>
          <div>
            <h1
              className="text-[24px] font-bold text-[var(--ink)] mb-1"
              style={{ fontFamily: 'var(--font-display)' }}
            >
              {user.fullName || 'Unknown User'}
            </h1>
            <div className="text-sm text-[var(--ink)] opacity-70 flex items-center gap-2 flex-wrap">
              <span>{user.tradeType || user.role}</span>
              <span>•</span>
              <StatusBadge status={user.isVerified ? 'Verified' : 'Unverified'} />
            </div>
          </div>
        </div>

        {/* Desktop / tablet actions in header */}
        {!isPhone && (
          <div className="flex items-center gap-3 shrink-0 flex-wrap">
            {actionButtons}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="card-title">Account Details</h3>
          <DescriptionList>
            <InfoRow label="User ID" valueClassName="mono">{user.id}</InfoRow>
            <InfoRow label="Email">{user.email}</InfoRow>
            <InfoRow label="Joined">
              {new Date(user.createdAtUtc).toLocaleDateString('en-NZ', {
                month: 'short',
                year: 'numeric',
              })}
            </InfoRow>
            <InfoRow
              label="Status"
              valueClassName={user.isActive ? 'text-[var(--green-ink)]' : 'text-[var(--red-ink)]'}
            >
              {user.isActive ? 'Active' : 'Inactive'}
            </InfoRow>
            {user.businessName && (
              <InfoRow label="Business">{user.businessName}</InfoRow>
            )}
          </DescriptionList>
        </div>

        <div className="card">
          <h3 className="card-title">Performance</h3>
          <DescriptionList>
            <InfoRow label="Rating">
              {user.reviewCount > 0
                ? `★ ${user.averageRating.toFixed(1)} (${user.reviewCount} ${user.reviewCount === 1 ? 'review' : 'reviews'})`
                : 'No reviews yet'}
            </InfoRow>
            <InfoRow label="Jobs Completed">{user.jobCount}</InfoRow>
            <InfoRow label="Role">{user.role}</InfoRow>
            <InfoRow label="Disputes">0</InfoRow>
          </DescriptionList>
        </div>
      </div>

      {user.flags && user.flags.length > 0 && (
        <div className="space-y-4">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Account Flags
          </h2>
          <DataTable
            columns={flagColumns}
            rows={user.flags}
            getRowKey={(f) => f.id}
          />
        </div>
      )}

      {user.recentJobs && user.recentJobs.length > 0 && (
        <div className="space-y-4">
          <h2
            className="text-[18px] font-semibold text-[var(--ink)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Recent Jobs
          </h2>
          <DataTable
            columns={recentJobColumns}
            rows={user.recentJobs}
            getRowKey={(j) => j.id}
          />
        </div>
      )}

      {/* Phone sticky bottom action bar */}
      {isPhone && (
        <div
          className="fixed bottom-0 inset-x-0 bg-[var(--surface)] border-t border-[var(--paper-line)] p-4 flex items-center gap-2 z-20 shadow-lg"
          style={{ paddingBottom: 'max(var(--safe-bottom), 16px)' }}
        >
          {/* Primary / main action */}
          {!user.isVerified && user.role === 'Tradie' ? (
            <button
              onClick={() => setConfirmModal('verify')}
              className="btn flex-1 justify-center min-h-[44px]"
              style={{ background: 'var(--green)', color: '#fff' }}
            >
              Verify NZBN
            </button>
          ) : user.flags?.some((f) => !f.resolved) ? (
            <button
              onClick={() => setConfirmModal('resolveFlags')}
              className="btn btn-primary flex-1 justify-center min-h-[44px]"
            >
              Resolve Flags
            </button>
          ) : user.isActive ? (
            <button
              onClick={() => setConfirmModal('warn')}
              className="btn btn-primary flex-1 justify-center min-h-[44px]"
            >
              Warn User
            </button>
          ) : null}

          {/* More menu for destructive / secondary operations */}
          <details className="relative">
            <summary
              className="btn btn-ghost !p-2 min-h-[44px] min-w-[44px] flex items-center justify-center list-none cursor-pointer"
              aria-label="More actions"
            >
              <MoreHorizontal size={20} aria-hidden="true" />
            </summary>
            <div className="absolute bottom-full right-0 mb-2 w-48 surface shadow-[var(--shadow-pop)] rounded p-2 z-30">
              {user.flags?.some((f) => !f.resolved) && (
                <button
                  onClick={() => {
                    setConfirmModal('resolveFlags');
                    (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
                  }}
                  className="w-full text-left px-3 py-2 text-sm text-[var(--ink)] hover:bg-[var(--paper)] rounded min-h-[44px]"
                >
                  Resolve Flags
                </button>
              )}
              {user.isActive && (
                <>
                  <button
                    onClick={() => {
                      setConfirmModal('warn');
                      (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
                    }}
                    className="w-full text-left px-3 py-2 text-sm text-[var(--amber-ink)] hover:bg-[var(--paper)] rounded min-h-[44px]"
                  >
                    Warn
                  </button>
                  <button
                    onClick={() => {
                      setConfirmModal('suspend');
                      (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
                    }}
                    className="w-full text-left px-3 py-2 text-sm text-[var(--red)] hover:bg-[var(--paper)] rounded min-h-[44px]"
                  >
                    Suspend
                  </button>
                  <button
                    onClick={() => {
                      setConfirmModal('deactivate');
                      (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
                    }}
                    className="w-full text-left px-3 py-2 text-sm text-[var(--red)] hover:bg-red-50 dark:hover:bg-red-900/20 rounded min-h-[44px]"
                  >
                    Deactivate
                  </button>
                </>
              )}
            </div>
          </details>
        </div>
      )}

      {/* Confirm modal */}
      <ConfirmModal
        open={confirmModal !== null}
        title={
          confirmModal === 'verify'
            ? `Verify ${user.fullName}?`
            : confirmModal === 'deactivate'
              ? `Deactivate ${user.fullName}?`
              : confirmModal === 'warn'
                ? `Warn ${user.fullName}?`
                : confirmModal === 'suspend'
                  ? `Suspend ${user.fullName}?`
                  : confirmModal === 'resolveFlags'
                    ? `Resolve flags for ${user.fullName}?`
                    : ''
        }
        message={
          confirmModal === 'verify'
            ? 'This will mark the tradie as verified and make them eligible for job matches.'
            : confirmModal === 'deactivate'
              ? 'This will disable login for this user. You will be redirected to the user list.'
              : confirmModal === 'resolveFlags'
                ? 'This will mark all open flags as resolved for this user.'
                : confirmModal === 'warn' || confirmModal === 'suspend'
                  ? 'Please provide a reason for this action. It will be recorded.'
                  : ''
        }
        confirmLabel={
          confirmModal === 'verify'
            ? 'Verify'
            : confirmModal === 'deactivate'
              ? 'Deactivate'
              : confirmModal === 'warn'
                ? 'Send Warning'
                : confirmModal === 'suspend'
                  ? 'Suspend Account'
                  : confirmModal === 'resolveFlags'
                    ? 'Resolve Flags'
                    : ''
        }
        destructive={['deactivate', 'warn', 'suspend'].includes(confirmModal || '')}
        confirmDisabled={
          (confirmModal === 'warn' || confirmModal === 'suspend') &&
          actionReason.trim().length === 0
        }
        onConfirm={handleAction}
        onCancel={() => {
          setConfirmModal(null);
          setActionReason('');
        }}
      >
        {(confirmModal === 'warn' || confirmModal === 'suspend') && (
          <div className="mt-4">
            <label className="block text-sm font-medium text-[var(--ink)] mb-1">
              Reason (required)
            </label>
            <textarea
              className="field field-multiline w-full resize-none"
              rows={3}
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              placeholder="Enter reason..."
              autoFocus
            />
          </div>
        )}
      </ConfirmModal>
    </div>
  );
};
