import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { MoreHorizontal } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
import { DataTable, type ColumnDef } from '../../../components/DataTable';
import { Banner } from '../../../components/Banner';
import { Button } from '../../../components/Button';
import { Field } from '../../../components/Field';
import { PageHeader } from '../../../components/PageHeader';
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
      <div className="stack">
        <Banner variant="error">No user ID in the URL.</Banner>
        <Link to="/users" className="cell-link">
          ← Back to Users
        </Link>
      </div>
    );
  }

  if (isLoading)
    return (
      <p className="muted" role="status" aria-busy="true">
        Loading user…
      </p>
    );

  if (isError || !user) {
    return (
      <div className="stack">
        <Link to="/users" className="cell-link">
          ← Back to Users
        </Link>
        <Banner
          variant="error"
          title="User not found."
          action={{ label: 'Retry', onClick: () => refetch() }}
        >
          {describeUserError(error)} <span className="mono">ID: {id}</span>
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

  const flagColumns: ColumnDef<AccountFlag>[] = [
    {
      key: 'type',
      header: 'Type',
      priority: 'primary',
      cell: (f) => f.type,
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

  const hasOpenFlags = user.flags?.some((f) => !f.resolved) ?? false;
  const canVerify = !user.isVerified && user.role === 'Tradie';

  const actionButtons = (
    <>
      {canVerify && (
        <Button kind="accent" onClick={() => setConfirmModal('verify')}>
          Verify NZBN
        </Button>
      )}
      {hasOpenFlags && (
        <Button kind="secondary" onClick={() => setConfirmModal('resolveFlags')}>
          Resolve Flags
        </Button>
      )}
      {user.isActive && (
        <>
          <Button kind="secondary" onClick={() => setConfirmModal('warn')}>
            Warn
          </Button>
          <Button kind="danger-outline" onClick={() => setConfirmModal('suspend')}>
            Suspend
          </Button>
          <Button kind="danger-outline" onClick={() => setConfirmModal('deactivate')}>
            Deactivate
          </Button>
        </>
      )}
    </>
  );

  /** Opens a confirm dialog from the phone "More" menu and closes the menu. */
  const openFromMenu = (kind: 'warn' | 'suspend' | 'deactivate' | 'resolveFlags') => {
    setConfirmModal(kind);
    (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
  };

  return (
    <div className={`stack ${isPhone ? 'pb-24' : ''}`.trim()}>
      <PageHeader
        title={user.fullName || 'Unknown User'}
        description={user.tradeType || user.role}
        backLink={{ to: '/users', label: 'Users' }}
        badge={<StatusBadge status={user.isVerified ? 'Verified' : 'Unverified'} size="lg" />}
        actions={!isPhone ? actionButtons : undefined}
      />

      <div className="grid side">
        <div className="stack">
          <section className="card">
            <div className="card-head">
              <h2>Account details</h2>
            </div>
            <div className="card-body">
              <DescriptionList>
                <InfoRow label="User ID" valueClassName="mono">
                  {user.id}
                </InfoRow>
                <InfoRow label="Email">{user.email}</InfoRow>
                <InfoRow label="Joined">
                  {new Date(user.createdAtUtc).toLocaleDateString('en-NZ', {
                    month: 'short',
                    year: 'numeric',
                  })}
                </InfoRow>
                <InfoRow label="Status">
                  <StatusBadge status={user.isActive ? 'Active' : 'Inactive'} />
                </InfoRow>
                {user.businessName && <InfoRow label="Business">{user.businessName}</InfoRow>}
              </DescriptionList>
            </div>
          </section>

          {user.flags && user.flags.length > 0 && (
            <section className="card flush">
              <div className="card-head">
                <h2>Account flags</h2>
              </div>
              <div className="card-body">
                <DataTable columns={flagColumns} rows={user.flags} getRowKey={(f) => f.id} />
              </div>
            </section>
          )}

          {user.recentJobs && user.recentJobs.length > 0 && (
            <section className="card flush">
              <div className="card-head">
                <h2>Recent jobs</h2>
              </div>
              <div className="card-body">
                <DataTable columns={recentJobColumns} rows={user.recentJobs} getRowKey={(j) => j.id} />
              </div>
            </section>
          )}
        </div>

        <div className="stack">
          <section className="card">
            <div className="card-head">
              <h2>Performance</h2>
            </div>
            <div className="card-body">
              <DescriptionList>
                <InfoRow label="Rating">
                  {user.reviewCount > 0
                    ? `★ ${user.averageRating.toFixed(1)} (${user.reviewCount} ${user.reviewCount === 1 ? 'review' : 'reviews'})`
                    : 'No reviews yet'}
                </InfoRow>
                <InfoRow label="Jobs Completed" valueClassName="money">
                  {user.jobCount}
                </InfoRow>
                <InfoRow label="Role">{user.role}</InfoRow>
                <InfoRow label="Disputes" valueClassName="money">
                  0
                </InfoRow>
              </DescriptionList>
            </div>
          </section>
        </div>
      </div>

      {/* Phone sticky bottom action bar */}
      {isPhone && (
        <div className="action-bar">
          {/* Primary / main action */}
          {canVerify ? (
            <Button kind="accent" block onClick={() => setConfirmModal('verify')}>
              Verify NZBN
            </Button>
          ) : hasOpenFlags ? (
            <Button kind="primary" block onClick={() => setConfirmModal('resolveFlags')}>
              Resolve Flags
            </Button>
          ) : user.isActive ? (
            <Button kind="primary" block onClick={() => setConfirmModal('warn')}>
              Warn User
            </Button>
          ) : null}

          {/* More menu for destructive / secondary operations */}
          <details className="more-menu">
            <summary className="btn btn-secondary btn-icon" aria-label="More actions">
              <MoreHorizontal size={20} aria-hidden="true" />
            </summary>
            <div className="more-menu-list">
              {hasOpenFlags && (
                <button type="button" onClick={() => openFromMenu('resolveFlags')}>
                  Resolve Flags
                </button>
              )}
              {user.isActive && (
                <>
                  <button type="button" onClick={() => openFromMenu('warn')}>
                    Warn
                  </button>
                  <button type="button" className="danger" onClick={() => openFromMenu('suspend')}>
                    Suspend
                  </button>
                  <button type="button" className="danger" onClick={() => openFromMenu('deactivate')}>
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
          <Field label="Reason" help="Required. It is recorded with the action.">
            {(a11y) => (
              <textarea
                {...a11y}
                className="textarea"
                rows={3}
                value={actionReason}
                onChange={(e) => setActionReason(e.target.value)}
                placeholder="Enter reason..."
                autoFocus
                data-autofocus
              />
            )}
          </Field>
        )}
      </ConfirmModal>
    </div>
  );
};
