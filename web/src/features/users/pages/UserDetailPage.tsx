import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useUserDetail, useVerifyUser, useDeactivateUser, useWarnUser, useSuspendUser, useResolveUserFlags } from '../hooks/useUsers';

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
  const { data: user, isLoading, isError, error, refetch } = useUserDetail(id ?? '');
  const verifyMutation = useVerifyUser();
  const deactivateMutation = useDeactivateUser();
  const warnMutation = useWarnUser();
  const suspendMutation = useSuspendUser();
  const resolveFlagsMutation = useResolveUserFlags();

  const [confirmModal, setConfirmModal] = useState<'verify' | 'deactivate' | 'warn' | 'suspend' | 'resolveFlags' | null>(null);
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
        <div
          role="alert"
          className="bg-red-50 border border-red-200 rounded p-4 text-sm text-[var(--red)]"
        >
          <p className="font-semibold mb-1">User not found.</p>
          <p>{describeUserError(error)}</p>
          <p className="mt-2 text-xs opacity-80" style={{ fontFamily: 'var(--font-mono)' }}>
            ID: {id}
          </p>
        </div>
        <button
          onClick={() => refetch()}
          className="btn btn-ghost"
        >
          Retry
        </button>
      </div>
    );
  }

  const handleAction = async () => {
    if (confirmModal === 'verify') await verifyMutation.mutateAsync(user.id);
    else if (confirmModal === 'deactivate') {
      await deactivateMutation.mutateAsync(user.id);
      navigate('/users');
    }
    else if (confirmModal === 'warn') {
      await warnMutation.mutateAsync({ id: user.id, reason: actionReason });
    }
    else if (confirmModal === 'suspend') {
      await suspendMutation.mutateAsync({ id: user.id, reason: actionReason });
    }
    else if (confirmModal === 'resolveFlags') {
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

  return (
    <div className="space-y-8">
      <div className="text-[13px] text-[var(--ink)] opacity-60">
        <Link to="/users" className="text-[var(--brand-500)] hover:underline">
          Users
        </Link>{' '}
        / {user.fullName}
      </div>

      <div className="flex items-start justify-between gap-4">
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
            <div className="text-sm text-[var(--ink)] opacity-70">
              {user.tradeType || user.role} •{' '}
              <StatusBadge status={user.isVerified ? 'Verified' : 'Unverified'} />
            </div>
          </div>
        </div>
        
        <div className="flex items-center gap-3 shrink-0">
          {!user.isVerified && user.role === 'Tradie' && (
            <button
              onClick={() => setConfirmModal('verify')}
              className="btn" style={{ background: 'var(--green)', color: '#fff' }}
            >
              Verify NZBN
            </button>
          )}
          {user.isActive && (
            <button
              onClick={() => setConfirmModal('deactivate')}
              className="btn btn-danger"
            >
              Deactivate
            </button>
          )}
          {user.flags?.some(f => !f.resolved) && (
            <button
              onClick={() => setConfirmModal('resolveFlags')}
              className="btn"
            >
              Resolve Flags
            </button>
          )}
          {user.isActive && (
            <>
              <button onClick={() => setConfirmModal('warn')} className="btn btn-ghost" style={{ color: 'var(--amber)' }}>Warn</button>
              <button onClick={() => setConfirmModal('suspend')} className="btn btn-ghost" style={{ color: 'var(--red)' }}>Suspend</button>
            </>
          )}
        </div>

      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="card-title">Account Details</h3>
          <div className="space-y-0">
            <div className="detail-row">
              <span className="detail-label">User ID</span>
              <span className="detail-value mono">{user.id}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Email</span>
              <span className="detail-value">{user.email}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Joined</span>
              <span className="detail-value">
                {new Date(user.createdAtUtc).toLocaleDateString('en-NZ', {
                  month: 'short',
                  year: 'numeric',
                })}
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Status</span>
              <span
                className="detail-value"
                style={{ color: user.isActive ? 'var(--green-ink)' : 'var(--red-ink)' }}
              >
                {user.isActive ? 'Active' : 'Inactive'}
              </span>
            </div>
            {user.businessName && (
              <div className="detail-row">
                <span className="detail-label">Business</span>
                <span className="detail-value">{user.businessName}</span>
              </div>
            )}
          </div>
        </div>

        <div className="card">
          <h3 className="card-title">Performance</h3>
          <div className="space-y-0">
            <div className="detail-row">
              <span className="detail-label">Rating</span>
              <span className="detail-value">
                ★ {user.averageRating.toFixed(1)} ({user.reviewCount} reviews)
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Jobs Completed</span>
              <span className="detail-value">{user.jobCount}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Role</span>
              <span className="detail-value">{user.role}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Disputes</span>
              <span className="detail-value">0</span>
            </div>
          </div>
        </div>
      </div>

      
      {user.flags && user.flags.length > 0 && (
        <div>
          <h2 className="text-[18px] font-semibold text-[var(--ink)] mb-4" style={{ fontFamily: 'var(--font-display)' }}>
            Account Flags
          </h2>
          <div className="table-container">
            <table className="table">
              <thead>
                <tr>
                  <th className="th">Type</th>
                  <th className="th">Counter</th>
                  <th className="th">Status</th>
                  <th className="th">Date</th>
                </tr>
              </thead>
              <tbody>
                {user.flags.map((flag) => (
                  <tr key={flag.id}>
                    <td className="td font-medium">{flag.type}</td>
                    <td className="td">{flag.counter}</td>
                    <td className="td">
                      <StatusBadge status={flag.resolved ? 'Resolved' : flag.thresholdHit ? 'ThresholdHit' : 'Open'} />
                    </td>
                    <td className="td">{new Date(flag.createdAtUtc).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {user.recentJobs.length > 0 && (
        <div>
          <h2
            className="text-[18px] font-semibold text-[var(--ink)] mb-4"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Recent Jobs
          </h2>
          <div className="table-container">
            <table className="table">
              <thead>
                <tr>
                  <th className="th">
                    Job ID
                  </th>
                  <th className="th">
                    Description
                  </th>
                  <th className="th">
                    Homeowner
                  </th>
                  <th className="th">
                    Status
                  </th>
                  <th className="th">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody>
                {user.recentJobs.map((job) => (
                  <tr key={job.id} >
                    <td
                      className="td"
                      style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}
                    >
                      JOB-{String(job.id).padStart(5, '0')}
                    </td>
                    <td className="td">{job.title}</td>
                    <td className="td">{job.homeownerName}</td>
                    <td className="td">
                      <StatusBadge status={job.status} />
                    </td>
                    <td className="td">
                      {new Date(job.createdAtUtc).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      
      
      <ConfirmModal
        open={confirmModal !== null}
        title={
          confirmModal === 'verify' ? `Verify ${user.fullName}?` :
          confirmModal === 'deactivate' ? `Deactivate ${user.fullName}?` :
          confirmModal === 'warn' ? `Warn ${user.fullName}?` :
          confirmModal === 'suspend' ? `Suspend ${user.fullName}?` :
          confirmModal === 'resolveFlags' ? `Resolve flags for ${user.fullName}?` : ''
        }
        message={
          confirmModal === 'verify' ? 'This will mark the tradie as verified and make them eligible for job matches.' :
          confirmModal === 'deactivate' ? 'This will disable login for this user. You will be redirected to the user list.' :
          confirmModal === 'resolveFlags' ? 'This will mark all open flags as resolved for this user.' :
          (confirmModal === 'warn' || confirmModal === 'suspend') ? 'Please provide a reason for this action. It will be recorded.' : ''
        }
        confirmLabel={
          confirmModal === 'verify' ? 'Verify' : 
          confirmModal === 'deactivate' ? 'Deactivate' :
          confirmModal === 'warn' ? 'Send Warning' :
          confirmModal === 'suspend' ? 'Suspend Account' :
          confirmModal === 'resolveFlags' ? 'Resolve Flags' : ''
        }
        destructive={['deactivate', 'warn', 'suspend'].includes(confirmModal || '')}
        confirmDisabled={(confirmModal === 'warn' || confirmModal === 'suspend') && actionReason.trim().length === 0}
        onConfirm={handleAction}
        onCancel={() => { setConfirmModal(null); setActionReason(''); }}
      >
        {(confirmModal === 'warn' || confirmModal === 'suspend') && (
          <div className="mt-4">
            <label className="block text-sm font-medium text-[var(--ink)] mb-1">Reason (required)</label>
            <textarea 
              className="field field-multiline w-full resize-none" 
              rows={3} 
              value={actionReason} 
              onChange={e => setActionReason(e.target.value)}
              placeholder="Enter reason..."
            />
          </div>
        )}
      </ConfirmModal>
    </div>
  );
};
