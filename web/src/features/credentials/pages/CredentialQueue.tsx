import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle, ExternalLink, ShieldCheck, XCircle } from 'lucide-react';
import { Pagination } from '../../../components/Pagination';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useCredentialQueue, useReviewCredential } from '../hooks/useCredentials';
import type { PendingCredential, ReviewedCredential } from '../../../services/adminApi';

const PAGE_SIZE = 20;
/** Mirrors `ReviewCredentialRequestValidator.RejectReason` (MaximumLength(500)). */
const REJECT_REASON_MAX = 500;

type ReviewKind = 'approve' | 'reject';

interface PendingAction {
  kind: ReviewKind;
  credential: PendingCredential;
}

/**
 * The backend answers 400/404 with `{ message }` and validation failures with a
 * FluentValidation error array — surface whichever one it sent.
 */
function describeReviewError(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;

    if (!error.response) {
      return `Cannot reach the API at ${error.config?.baseURL ?? 'the configured URL'}. Check the backend is running and VITE_API_URL is correct.`;
    }

    const data: unknown = error.response.data;
    if (Array.isArray(data)) {
      const firstError = data.find(
        (entry) => typeof entry === 'object' && entry !== null && 'errorMessage' in entry,
      ) as { errorMessage?: unknown } | undefined;
      if (firstError?.errorMessage) return String(firstError.errorMessage);
    }
    if (typeof data === 'object' && data !== null && 'message' in data) {
      return String((data as { message: unknown }).message);
    }

    if (status === 401 || status === 403)
      return 'Your session is not authorized to review credentials (401/403). Try logging in again.';
    if (status === 404) return 'That credential no longer exists (404). Reload the queue.';
    return `Request failed with status ${status}.`;
  }
  return error instanceof Error ? error.message : 'Unknown error.';
}

/** Confirmation line shown after a successful review — verification state comes from the backend. */
function reviewSummary(reviewed: ReviewedCredential): string {
  const what = `${reviewed.tradieName}'s ${reviewed.type.toLowerCase()}`;
  if (reviewed.status === 'Approved') {
    return `Approved ${what}. ${reviewed.tradieName} is verified and eligible for job matching.`;
  }
  return reviewed.tradieIsVerified
    ? `Rejected ${what}. ${reviewed.tradieName} still holds another approved credential.`
    : `Rejected ${what}. ${reviewed.tradieName} has no approved credentials left and is no longer verified.`;
}

export const CredentialQueue: React.FC = () => {
  const [page, setPage] = useState(1);
  const [pendingAction, setPendingAction] = useState<PendingAction | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const {
    data,
    isLoading,
    isError,
    error: queryError,
    refetch,
  } = useCredentialQueue({ page, pageSize: PAGE_SIZE });
  const reviewMutation = useReviewCredential();

  const openAction = (kind: ReviewKind, credential: PendingCredential) => {
    setSuccessMessage(null);
    setActionError(null);
    setRejectReason('');
    setPendingAction({ kind, credential });
  };

  const closeAction = () => {
    setPendingAction(null);
    setRejectReason('');
  };

  const handleConfirm = async () => {
    if (!pendingAction) return;
    const { kind, credential } = pendingAction;
    setActionError(null);

    try {
      const reviewed = await reviewMutation.mutateAsync({
        id: credential.id,
        request:
          kind === 'approve'
            ? { status: 'Approved' }
            : { status: 'Rejected', rejectReason: rejectReason.trim() },
      });
      setSuccessMessage(reviewSummary(reviewed));
      // Reviewing the only row left on a page would leave it empty — step back.
      if (data && data.items.length === 1 && page > 1) setPage(page - 1);
    } catch (err) {
      setActionError(
        `Could not ${kind} ${credential.tradieName}'s ${credential.type.toLowerCase()}: ${describeReviewError(err)}`,
      );
    } finally {
      closeAction();
    }
  };

  const busyId = reviewMutation.isPending ? reviewMutation.variables?.id : undefined;

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-[var(--ink)]">Credential Verification</h1>
        <p className="text-sm text-[var(--ink-soft)]">
          Review tradie licences, insurance and certifications. Approving a credential verifies the
          tradie and makes them eligible for job matching.
        </p>
        {data && (
          <div className="flex flex-wrap gap-4 mt-3">
            <div className="stat-pill">
              <ShieldCheck size={13} aria-hidden="true" />
              <strong>{data.totalCount.toLocaleString()}</strong> awaiting review
            </div>
            <div className="stat-pill">
              <strong>{data.items.length}</strong> on this page
            </div>
          </div>
        )}
      </div>

      {successMessage && (
        <div className="flex items-center gap-2 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg px-4 py-3 text-sm text-green-700 dark:text-green-400">
          <CheckCircle size={14} aria-hidden="true" />
          {successMessage}
        </div>
      )}

      {actionError && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          {actionError}
        </div>
      )}

      {isError && (
        <div className="flex flex-wrap items-center justify-between gap-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg px-4 py-3 text-sm text-[var(--red)]">
          <span>Could not load the credential queue: {describeReviewError(queryError)}</span>
          <button className="btn btn-ghost !py-1 !px-2.5 !text-xs" onClick={() => refetch()}>
            Retry
          </button>
        </div>
      )}

      {/* Queue table */}
      <div className="table-container">
        <div className="overflow-x-auto">
          <table className="table">
            <thead>
              <tr>
                <th className="th">Tradie</th>
                <th className="th">Trade</th>
                <th className="th">Credential</th>
                <th className="th">Document</th>
                <th className="th" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="td text-center cell-muted">
                    Loading…
                  </td>
                </tr>
              ) : data && data.items.length === 0 ? (
                <tr>
                  <td colSpan={5} className="td text-center cell-muted">
                    {data.totalCount > 0 && page > 1 ? (
                      <>
                        No credentials left on this page.{' '}
                        <button
                          className="action-link"
                          onClick={() => setPage(Math.max(1, data.totalPages))}
                        >
                          Go to page {Math.max(1, data.totalPages)}
                        </button>
                      </>
                    ) : (
                      'No credentials awaiting review.'
                    )}
                  </td>
                </tr>
              ) : (
                data?.items.map((credential) => (
                  <tr key={credential.id}>
                    <td className="td">
                      <Link to={`/users/${credential.tradieUserId}`} className="cell-link">
                        {credential.tradieName}
                      </Link>
                      <span className="block text-xs cell-muted">{credential.tradieEmail}</span>
                    </td>
                    <td className="td">
                      {credential.tradeType ?? '—'}
                      {credential.businessName && (
                        <span className="block text-xs cell-muted">{credential.businessName}</span>
                      )}
                    </td>
                    <td className="td">
                      <span className="pill pill-brand">{credential.type}</span>
                    </td>
                    <td className="td">
                      <a
                        href={credential.downloadUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="action-link inline-flex items-center gap-1.5"
                      >
                        <ExternalLink size={12} aria-hidden="true" />
                        {credential.originalFileName}
                      </a>
                    </td>
                    <td className="td">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          className="btn btn-primary !py-1 !px-2.5 !text-xs"
                          disabled={busyId === credential.id}
                          onClick={() => openAction('approve', credential)}
                        >
                          <CheckCircle size={12} aria-hidden="true" />
                          Approve
                        </button>
                        <button
                          className="btn btn-danger !py-1 !px-2.5 !text-xs"
                          disabled={busyId === credential.id}
                          onClick={() => openAction('reject', credential)}
                        >
                          <XCircle size={12} aria-hidden="true" />
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {data && (
          <Pagination
            page={data.page}
            totalPages={data.totalPages}
            pageSize={data.pageSize}
            totalCount={data.totalCount}
            itemLabel="credentials"
            onPageChange={setPage}
          />
        )}
      </div>

      <p className="text-xs text-[var(--ink-soft)]">
        Document links are private-bucket URLs that expire 15 minutes after the queue was loaded.
      </p>


      {/* Approve / reject confirmation */}
      {pendingAction && (
        <ConfirmModal
          open
          destructive={pendingAction.kind === 'reject'}
          title={
            pendingAction.kind === 'approve'
              ? `Approve ${pendingAction.credential.type.toLowerCase()}?`
              : `Reject ${pendingAction.credential.type.toLowerCase()}?`
          }
          message={
            pendingAction.kind === 'approve'
              ? `Approve ${pendingAction.credential.tradieName}'s ${pendingAction.credential.type.toLowerCase()}? The tradie becomes verified and eligible for job matching.`
              : `Reject ${pendingAction.credential.tradieName}'s ${pendingAction.credential.type.toLowerCase()}? They can upload a replacement document.`
          }
          confirmLabel={pendingAction.kind === 'approve' ? 'Approve' : 'Reject'}
          confirmDisabled={pendingAction.kind === 'reject' && rejectReason.trim().length === 0}
          onConfirm={handleConfirm}
          onCancel={closeAction}
        >
          {pendingAction.kind === 'reject' && (
            <div className="mt-4">
              <label
                htmlFor="reject-reason"
                className="block text-sm font-medium text-[var(--ink)] mb-1"
              >
                Reason for rejection
              </label>
              <textarea
                id="reject-reason"
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                rows={3}
                maxLength={REJECT_REASON_MAX}
                autoFocus
                placeholder="e.g. Licence expired — please upload the current one."
                className="field field-multiline w-full resize-none"
              />
              <p className="text-xs text-[var(--ink-soft)] mt-1">
                Required. Stored on the credential so the tradie can see what to fix.{' '}
                {rejectReason.length}/{REJECT_REASON_MAX} characters.
              </p>
            </div>
          )}
        </ConfirmModal>
      )}
    </div>
  );
};


