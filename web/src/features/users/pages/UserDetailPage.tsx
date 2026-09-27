import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useUserDetail, useVerifyUser, useDeactivateUser } from '../hooks/useUsers';

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

  const [confirmModal, setConfirmModal] = useState<'verify' | 'deactivate' | null>(null);

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
          className="px-4 py-2 text-sm rounded border border-[var(--paper-line)] text-[var(--ink-soft)] hover:bg-[var(--paper-line)] transition-colors"
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
    setConfirmModal(null);
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
              <span
                className={`inline-block px-2.5 py-0.5 rounded-full text-[11px] font-semibold ${
                  user.isVerified
                    ? 'bg-green-100 text-[var(--green)]'
                    : 'bg-[var(--brand-100)] text-[var(--brand-900)]'
                }`}
              >
                {user.isVerified ? 'Verified' : 'Unverified'}
              </span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3 shrink-0">
          {!user.isVerified && user.role === 'Tradie' && (
            <button
              onClick={() => setConfirmModal('verify')}
              className="px-5 py-2.5 rounded text-sm font-semibold bg-[var(--green)] text-white hover:opacity-90 transition-opacity"
            >
              Verify NZBN
            </button>
          )}
          {user.isActive && (
            <button
              onClick={() => setConfirmModal('deactivate')}
              className="px-5 py-2.5 rounded text-sm font-semibold border border-[var(--red)] text-[var(--red)] hover:bg-[var(--red)] hover:text-white transition-colors"
            >
              Deactivate
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-6 shadow-sm">
          <h3
            className="text-[16px] font-semibold text-[var(--ink)] mb-4 pb-3 border-b border-[var(--brand-100)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Account Details
          </h3>
          <div className="space-y-0">
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">User ID</span>
              <span
                className="text-sm font-medium text-[var(--ink)]"
                style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}
              >
                {user.id}
              </span>
            </div>
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Email</span>
              <span className="text-sm font-medium text-[var(--ink)]">{user.email}</span>
            </div>
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Joined</span>
              <span className="text-sm font-medium text-[var(--ink)]">
                {new Date(user.createdAtUtc).toLocaleDateString('en-NZ', {
                  month: 'short',
                  year: 'numeric',
                })}
              </span>
            </div>
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Status</span>
              <span
                className="text-sm font-medium"
                style={{ color: user.isActive ? 'var(--green)' : 'var(--red)' }}
              >
                {user.isActive ? 'Active' : 'Inactive'}
              </span>
            </div>
            {user.businessName && (
              <div className="flex justify-between py-2.5">
                <span className="text-[13px] text-[var(--ink)] opacity-60">Business</span>
                <span className="text-sm font-medium text-[var(--ink)]">{user.businessName}</span>
              </div>
            )}
          </div>
        </div>

        <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded p-6 shadow-sm">
          <h3
            className="text-[16px] font-semibold text-[var(--ink)] mb-4 pb-3 border-b border-[var(--brand-100)]"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Performance
          </h3>
          <div className="space-y-0">
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Rating</span>
              <span className="text-sm font-medium text-[var(--ink)]">
                ★ {user.averageRating.toFixed(1)} ({user.reviewCount} reviews)
              </span>
            </div>
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Jobs Completed</span>
              <span className="text-sm font-medium text-[var(--ink)]">{user.jobCount}</span>
            </div>
            <div className="flex justify-between py-2.5 border-b border-[var(--brand-100)]">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Role</span>
              <span className="text-sm font-medium text-[var(--ink)]">{user.role}</span>
            </div>
            <div className="flex justify-between py-2.5">
              <span className="text-[13px] text-[var(--ink)] opacity-60">Disputes</span>
              <span className="text-sm font-medium text-[var(--ink)]">0</span>
            </div>
          </div>
        </div>
      </div>

      {user.recentJobs.length > 0 && (
        <div>
          <h2
            className="text-[18px] font-semibold text-[var(--ink)] mb-4"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Recent Jobs
          </h2>
          <div className="bg-[var(--paper)] border border-[var(--paper-line)] rounded shadow-sm overflow-hidden">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]">
                    Job ID
                  </th>
                  <th className="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]">
                    Description
                  </th>
                  <th className="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]">
                    Homeowner
                  </th>
                  <th className="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]">
                    Status
                  </th>
                  <th className="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide text-[var(--ink)] opacity-60 border-b border-[var(--brand-100)] bg-[var(--paper)]">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody>
                {user.recentJobs.map((job) => (
                  <tr key={job.id} className="hover:bg-[var(--paper)]">
                    <td
                      className="px-4 py-3 text-sm text-[var(--ink)]"
                      style={{ fontFamily: 'var(--font-mono)', fontSize: '13px' }}
                    >
                      JOB-{String(job.id).padStart(5, '0')}
                    </td>
                    <td className="px-4 py-3 text-sm text-[var(--ink)]">{job.title}</td>
                    <td className="px-4 py-3 text-sm text-[var(--ink)]">{job.homeownerName}</td>
                    <td className="px-4 py-3 text-sm">
                      <StatusBadge status={job.status} />
                    </td>
                    <td className="px-4 py-3 text-sm text-[var(--ink)]">
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
          confirmModal === 'verify'
            ? `Verify ${user.fullName}?`
            : `Deactivate ${user.fullName}?`
        }
        message={
          confirmModal === 'verify'
            ? 'This will mark the tradie as verified and make them eligible for job matches.'
            : 'This will disable login for this user. You will be redirected to the user list.'
        }
        confirmLabel={confirmModal === 'verify' ? 'Verify' : 'Deactivate'}
        destructive={confirmModal === 'deactivate'}
        onConfirm={handleAction}
        onCancel={() => setConfirmModal(null)}
      />
    </div>
  );
};
