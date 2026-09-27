import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, MessageSquare, CheckCircle, AlertTriangle, XCircle } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useDisputeDetail, useResolveDispute } from '../hooks/useDisputes';

type DisputeAction = 'Resolved' | 'Escalated' | 'CancelJob';

export const DisputeDetailPage: React.FC = () => {
  const { jobId } = useParams<{ jobId: string }>();
  const navigate = useNavigate();
  const { data: dispute, isLoading } = useDisputeDetail(Number(jobId));
  const resolveMutation = useResolveDispute();

  const [pendingAction, setPendingAction] = useState<DisputeAction | null>(null);
  const [note, setNote] = useState('');

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading dispute…</div>;
  if (!dispute)
    return <div className="text-[var(--red)] text-sm p-4">Dispute not found.</div>;

  const handleResolve = async () => {
    if (!pendingAction) return;
    await resolveMutation.mutateAsync({
      jobId: Number(jobId),
      request: { action: pendingAction, note: note || undefined },
    });
    navigate('/disputes');
  };

  const actionConfig: Record<DisputeAction, { label: string; description: string; destructive: boolean }> = {
    Resolved: {
      label: 'Mark Resolved',
      description: 'This will close the dispute. No further action will be taken.',
      destructive: false,
    },
    Escalated: {
      label: 'Escalate',
      description: 'This will flag the dispute for escalation to a senior reviewer.',
      destructive: false,
    },
    CancelJob: {
      label: 'Cancel Job',
      description: 'This will cancel the job and close the dispute. This cannot be undone.',
      destructive: true,
    },
  };

  const isAlreadyResolved = ['Resolved', 'Escalated'].includes(dispute.disputeStatus);

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Back */}
      <Link
        to="/disputes"
        className="inline-flex items-center gap-1.5 text-sm text-[var(--ink-soft)] hover:text-[var(--ink)]"
      >
        <ArrowLeft size={14} /> Back to Disputes
      </Link>

      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-[var(--ink)]">{dispute.jobTitle}</h1>
          <p className="text-sm text-[var(--ink-soft)]">
            Flagged {new Date(dispute.flaggedAtUtc).toLocaleString()}
          </p>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <StatusBadge status={dispute.status} />
          <StatusBadge status={dispute.disputeStatus} />
        </div>
      </div>

      {/* Flag reason */}
      {dispute.flagReason && (
        <div className="flex items-start gap-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4">
          <AlertTriangle size={16} className="text-[var(--amber)] shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-medium text-[var(--ink)]">Flag reason</p>
            <p className="text-sm text-[var(--ink-soft)] mt-1">{dispute.flagReason}</p>
          </div>
        </div>
      )}

      {/* Parties */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <PartyCard
          title="Homeowner"
          name={dispute.homeownerName}
          userId={dispute.homeownerDetail?.id}
          role="Homeowner"
          jobCount={dispute.homeownerDetail?.jobCount ?? 0}
        />
        {dispute.tradieName && (
          <PartyCard
            title="Tradie"
            name={dispute.tradieName}
            userId={dispute.tradieDetail?.id}
            role="Tradie"
            jobCount={dispute.tradieDetail?.jobCount ?? 0}
            isVerified={dispute.tradieDetail?.isVerified}
          />
        )}
      </div>

      {/* Chat transcript */}
      <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
        <div className="px-5 py-3 border-b border-[var(--paper-line)] flex items-center gap-2">
          <MessageSquare size={14} className="text-[var(--ink-soft)]" />
          <span className="text-sm font-medium text-[var(--ink)]">Chat Context (read-only)</span>
        </div>
        {dispute.chatTranscript.length === 0 ? (
          <div className="px-5 py-6 text-center text-sm text-[var(--ink-soft)]">No messages.</div>
        ) : (
          <div className="divide-y divide-[var(--paper-line)] max-h-80 overflow-y-auto">
            {dispute.chatTranscript.map((msg) => (
              <div key={msg.id} className="px-5 py-3">
                <div className="flex justify-between mb-0.5">
                  <span className="text-xs font-semibold text-[var(--ink)]">{msg.senderName}</span>
                  <span className="text-xs text-[var(--ink-soft)]">
                    {new Date(msg.sentAtUtc).toLocaleString()}
                  </span>
                </div>
                <p className="text-sm text-[var(--ink-soft)]">{msg.content}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Resolution actions */}
      {!isAlreadyResolved ? (
        <div className="border border-[var(--paper-line)] rounded-lg p-5">
          <h2 className="text-sm font-semibold text-[var(--ink)] mb-1">Resolution Actions</h2>
          <p className="text-xs text-[var(--ink-soft)] mb-4">
            All actions are final. Add an optional note before resolving.
          </p>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Admin note (optional)…"
            rows={3}
            className="w-full mb-4 px-3 py-2 text-sm border border-[var(--paper-line)] rounded bg-[var(--paper)] text-[var(--ink)] focus:outline-none focus:ring-2 focus:ring-[var(--brand-500)] resize-none"
          />
          <div className="flex flex-wrap gap-3">
            <ActionButton
              label="Mark Resolved"
              icon={<CheckCircle size={14} />}
              variant="success"
              onClick={() => setPendingAction('Resolved')}
            />
            <ActionButton
              label="Escalate"
              icon={<AlertTriangle size={14} />}
              variant="warning"
              onClick={() => setPendingAction('Escalated')}
            />
            <ActionButton
              label="Cancel Job"
              icon={<XCircle size={14} />}
              variant="danger"
              onClick={() => setPendingAction('CancelJob')}
            />
          </div>
        </div>
      ) : (
        <div className="border border-[var(--paper-line)] rounded-lg p-5 text-center">
          <p className="text-sm text-[var(--ink-soft)]">
            This dispute has been <strong>{dispute.disputeStatus.toLowerCase()}</strong>. No further
            actions available.
          </p>
        </div>
      )}

      {/* Confirmation modal */}
      {pendingAction && (
        <ConfirmModal
          open
          title={actionConfig[pendingAction].label}
          message={actionConfig[pendingAction].description}
          confirmLabel={actionConfig[pendingAction].label}
          destructive={actionConfig[pendingAction].destructive}
          onConfirm={handleResolve}
          onCancel={() => setPendingAction(null)}
        />
      )}
    </div>
  );
};

// ── Sub-components ─────────────────────────────────────────────────────────────

const PartyCard: React.FC<{
  title: string;
  name: string;
  userId?: string;
  role: string;
  jobCount: number;
  isVerified?: boolean;
}> = ({ title, name, userId, role, jobCount, isVerified }) => (
  <div className="border border-[var(--paper-line)] rounded-lg p-4">
    <p className="text-xs text-[var(--ink-soft)] mb-1">{title}</p>
    <p className="text-sm font-semibold text-[var(--ink)]">{name}</p>
    <div className="flex items-center gap-2 mt-2">
      <StatusBadge status={role} />
      {isVerified && <StatusBadge status="Verified" />}
    </div>
    <p className="text-xs text-[var(--ink-soft)] mt-2">{jobCount} jobs</p>
    {userId && (
      <Link
        to={`/users/${userId}`}
        className="mt-2 inline-block text-xs text-[var(--brand-500)] hover:underline"
      >
        View profile →
      </Link>
    )}
  </div>
);

const ActionButton: React.FC<{
  label: string;
  icon: React.ReactNode;
  variant: 'success' | 'warning' | 'danger';
  onClick: () => void;
}> = ({ label, icon, variant, onClick }) => {
  const styles: Record<string, string> = {
    success: 'border-green-200 text-green-700 hover:bg-green-50 dark:hover:bg-green-900/20',
    warning: 'border-amber-200 text-amber-700 hover:bg-amber-50 dark:hover:bg-amber-900/20',
    danger: 'border-red-200 text-[var(--red)] hover:bg-red-50 dark:hover:bg-red-900/20',
  };
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-2 px-4 py-2 text-sm rounded border transition-colors ${styles[variant]}`}
    >
      {icon}
      {label}
    </button>
  );
};
