import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';
import { ExternalLink, ShieldCheck } from 'lucide-react';
import { PageHeader } from '../../../components/PageHeader';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef, type RowAction } from '../../../components/DataTable';
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

  const columns: ColumnDef<PendingCredential>[] = [
    {
      key: 'tradie',
      header: 'Tradie',
      priority: 'primary',
      cell: (credential) => (
        <div>
          <Link to={`/users/${credential.tradieUserId}`} className="cell-link">
            {credential.tradieName}
          </Link>
          <span className="block text-xs cell-muted">{credential.tradieEmail}</span>
        </div>
      ),
    },
    {
      key: 'trade',
      header: 'Trade',
      priority: 'secondary',
      cell: (credential) => (
        <div>
          <span>{credential.tradeType ?? '—'}</span>
          {credential.businessName && (
            <span className="block text-xs cell-muted">{credential.businessName}</span>
          )}
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Credential',
      priority: 'secondary',
      cell: (credential) => (
        <span className="pill pill-brand">{credential.type}</span>
      ),
    },
    {
      key: 'document',
      header: 'Document',
      priority: 'secondary',
      cell: (credential) => (
        <a
          href={credential.downloadUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="action-link inline-flex items-center gap-1.5"
        >
          <ExternalLink size={12} aria-hidden="true" />
          <span className="truncate max-w-[200px]">
            {credential.originalFileName || 'View document'}
          </span>
        </a>
      ),
    },
  ];

  const rowActions = (credential: PendingCredential): RowAction[] => [
    {
      label: 'Approve',
      onClick: () => openAction('approve', credential),
      variant: 'primary',
      disabled: busyId === credential.id,
      primary: true,
    },
    {
      label: 'Reject',
      onClick: () => openAction('reject', credential),
      variant: 'danger',
      disabled: busyId === credential.id,
    },
  ];

  return (
    <div className="space-y-5">
      {/* Header */}
      <PageHeader
        title="Credential Verification"
        description="Review tradie licences, insurance and certifications. Approving a credential verifies the tradie and makes them eligible for job matching."
        meta={
          data && (
            <>
              <div className="stat-pill">
                <ShieldCheck size={13} aria-hidden="true" />
                <strong>{data.totalCount.toLocaleString()}</strong> awaiting review
              </div>
              <div className="stat-pill">
                <strong>{data.items.length}</strong> on this page
              </div>
            </>
          )
        }
      />

      {successMessage && (
        <Banner variant="success">{successMessage}</Banner>
      )}

      {actionError && (
        <Banner variant="error">{actionError}</Banner>
      )}

      {isError && (
        <Banner
          variant="error"
          action={{ label: 'Retry', onClick: () => refetch() }}
        >
          Could not load the credential queue: {describeReviewError(queryError)}
        </Banner>
      )}

      {/* Queue table */}
      <DataTable
        columns={columns}
        rows={data?.items}
        getRowKey={(c) => c.id}
        isLoading={isLoading}
        rowActions={rowActions}
        empty="No credentials awaiting review."
        pagination={
          data ? (
            <Pagination
              page={data.page}
              totalPages={data.totalPages}
              pageSize={data.pageSize}
              totalCount={data.totalCount}
              itemLabel="credentials"
              onPageChange={setPage}
            />
          ) : undefined
        }
      />

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
