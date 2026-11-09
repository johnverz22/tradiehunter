import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, MessageSquare, CheckCircle, AlertTriangle, XCircle, Clock, FileText, Image as ImageIcon } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { ConfirmModal } from '../../../components/ConfirmModal';
import { useDisputeDetail, useResolveDispute } from '../hooks/useDisputes';

type DisputeAction = 'FullRefund' | 'PartialRefund' | 'NoRefund' | 'None';

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
      request: { outcome: pendingAction, note: note || undefined },
    });
    navigate('/disputes');
  };

  const actionConfig: Record<DisputeAction, { label: string; description: string; destructive: boolean }> = {
    FullRefund: {
      label: 'Full Refund',
      description: 'Resolve dispute and issue a full refund to the homeowner. This will also cancel the job.',
      destructive: true,
    },
    PartialRefund: {
      label: 'Partial Refund',
      description: 'Resolve dispute and issue a partial refund to the homeowner.',
      destructive: false,
    },
    NoRefund: {
      label: 'No Refund',
      description: 'Resolve dispute with no refund.',
      destructive: false,
    },
    None: {
      label: 'No Action',
      description: 'Close dispute without taking any action.',
      destructive: false,
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

      {/* Evidence */}
      <div className="card">
        <h3 className="card-title">
          <FileText size={14} className="inline -mt-0.5 mr-1.5" aria-hidden="true" />
          Dispute Evidence ({dispute.evidence?.length ?? 0})
        </h3>
        {!dispute.evidence?.length ? (
          <p className="text-sm text-[var(--ink-soft)] py-4 text-center">No evidence submitted.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-4">
            {dispute.evidence.map((ev) => (
              <div key={ev.id} className="border border-[var(--border)] rounded p-3">
                <div className="flex justify-between items-center mb-2">
                  <span className="text-xs font-semibold text-[var(--ink)]">{ev.type}</span>
                  <span className="text-xs text-[var(--ink-soft)]">
                    {new Date(ev.createdAtUtc).toLocaleString()}
                  </span>
                </div>
                {ev.type === 'Text' && <p className="text-sm text-[var(--ink-soft)] whitespace-pre-wrap">{ev.textContent}</p>}
                {(ev.type === 'Photo' || ev.type === 'Document') && (
                  <a href={ev.downloadUrl} target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 text-sm text-[var(--brand-500)] hover:underline">
                    <ImageIcon size={14} /> View attached file
                  </a>
                )}
                <p className="text-xs text-[var(--ink-soft)] mt-2">Submitted by: {ev.submittedBy}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Time Logs */}
      <div className="card">
        <h3 className="card-title">
          <Clock size={14} className="inline -mt-0.5 mr-1.5" aria-hidden="true" />
          Time Logs ({dispute.timeLogs?.length ?? 0})
        </h3>
        {!dispute.timeLogs?.length ? (
          <p className="text-sm text-[var(--ink-soft)] py-4 text-center">No time logs recorded.</p>
        ) : (
          <div className="mt-4 space-y-2">
            {dispute.timeLogs.map((log) => (
              <div key={log.id} className="flex justify-between items-center border-b border-[var(--border)] last:border-0 pb-2">
                <div>
                  <p className="text-sm text-[var(--ink)]">Check In: {new Date(log.checkInAtUtc).toLocaleString()}</p>
                  {log.checkOutAtUtc && (
                    <p className="text-sm text-[var(--ink)]">Check Out: {new Date(log.checkOutAtUtc).toLocaleString()}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Chat transcript */}
      <div className="card">
        <h3 className="card-title">
          <MessageSquare size={14} className="inline -mt-0.5 mr-1.5" aria-hidden="true" />
          Chat Context ({dispute.chatTranscript.length})
        </h3>
        {dispute.chatTranscript.length === 0 ? (
          <p className="text-sm text-[var(--ink-soft)] py-4 text-center">No messages.</p>
        ) : (
          <div className="max-h-80 overflow-y-auto">
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
        <div className="card">
          <h2 className="card-title">Resolution Actions</h2>
          <p className="text-xs text-[var(--ink-soft)] mb-4">
            All actions are final. Add an optional note before resolving.
          </p>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Admin note (optional)…"
            rows={3}
            className="field field-multiline w-full mb-4 resize-none"
          />
          <div className="flex flex-wrap gap-3">
            <ActionButton
              label="Full Refund"
              icon={<XCircle size={14} />}
              variant="danger"
              onClick={() => setPendingAction('FullRefund')}
            />
            <ActionButton
              label="Partial Refund"
              icon={<AlertTriangle size={14} />}
              variant="warning"
              onClick={() => setPendingAction('PartialRefund')}
            />
            <ActionButton
              label="No Refund"
              icon={<CheckCircle size={14} />}
              variant="success"
              onClick={() => setPendingAction('NoRefund')}
            />
            <ActionButton
              label="No Action"
              icon={<CheckCircle size={14} />}
              variant="success"
              onClick={() => setPendingAction('None')}
            />
          </div>
        </div>
      ) : (
        <div className="card text-center">
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
  <div className="card !p-4">
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
    success: 'pill-green',
    warning: 'pill-amber',
    danger: 'pill-red',
  };
  return (
    <button onClick={onClick} className={`pill ${styles[variant]} !px-4 !py-2 !text-sm`}>
      {icon}
      {label}
    </button>
  );
};
