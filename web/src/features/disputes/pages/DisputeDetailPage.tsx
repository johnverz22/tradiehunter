import React, { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import {
  MessageSquare,
  CheckCircle,
  AlertTriangle,
  XCircle,
  Clock,
  FileText,
  Image as ImageIcon,
} from 'lucide-react';
import { Badge } from '../../../components/Badge';
import { Banner } from '../../../components/Banner';
import { Button } from '../../../components/Button';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
import { Field } from '../../../components/Field';
import { PageHeader } from '../../../components/PageHeader';
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
    return (
      <p className="muted" role="status" aria-busy="true">
        Loading dispute…
      </p>
    );
  if (!dispute)
    return (
      <div className="stack">
        <Link to="/disputes" className="cell-link">
          ← Back to Disputes
        </Link>
        <Banner variant="error" title="Dispute not found.">
          This dispute does not exist or is no longer available.
        </Banner>
      </div>
    );

  const handleResolve = async () => {
    if (!pendingAction) return;
    await resolveMutation.mutateAsync({
      jobId: Number(jobId),
      request: { outcome: pendingAction, note: note || undefined },
    });
    navigate('/disputes');
  };

  const actionConfig: Record<
    DisputeAction,
    { label: string; description: string; destructive: boolean }
  > = {
    FullRefund: {
      label: 'Full Refund',
      description:
        'Resolve dispute and issue a full refund to the homeowner. This will also cancel the job.',
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
    <div className="stack">
      <PageHeader
        title={dispute.jobTitle}
        description={`Flagged ${new Date(dispute.flaggedAtUtc).toLocaleString()}`}
        backLink={{ to: '/disputes', label: 'Disputes' }}
        badge={
          <>
            <StatusBadge status={dispute.status} size="lg" />
            <StatusBadge status={dispute.disputeStatus} size="lg" />
          </>
        }
      />

      {dispute.flagReason && (
        <Banner variant="warn" title="Flag reason">
          {dispute.flagReason}
        </Banner>
      )}

      <div className="grid side">
        <div className="stack">
          {/* Evidence */}
          <section className="card">
            <div className="card-head">
              <h2>Dispute evidence ({dispute.evidence?.length ?? 0})</h2>
              <FileText size={16} className="c-soft" aria-hidden="true" />
            </div>
            <div className="card-body">
              {!dispute.evidence?.length ? (
                <p className="muted">No evidence submitted.</p>
              ) : (
                <div className="stack">
                  {dispute.evidence.map((ev) => (
                    <div key={ev.id} className="evidence-item">
                      <div className="row between">
                        <Badge>{ev.type}</Badge>
                        <span className="t-meta muted">{new Date(ev.createdAtUtc).toLocaleString()}</span>
                      </div>
                      {ev.type === 'Text' && <p className="desc-text">{ev.textContent}</p>}
                      {(ev.type === 'Photo' || ev.type === 'Document') && (
                        <a
                          href={ev.downloadUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="cell-link row nowrap"
                        >
                          <ImageIcon size={16} aria-hidden="true" /> View attached file
                        </a>
                      )}
                      <p className="t-meta muted">Submitted by: {ev.submittedBy}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>

          {/* Time logs */}
          <section className="card">
            <div className="card-head">
              <h2>Time logs ({dispute.timeLogs?.length ?? 0})</h2>
              <Clock size={16} className="c-soft" aria-hidden="true" />
            </div>
            <div className="card-body">
              {!dispute.timeLogs?.length ? (
                <p className="muted">No time logs recorded.</p>
              ) : (
                dispute.timeLogs.map((log) => (
                  <DescriptionList key={log.id}>
                    <InfoRow label="Check in">{new Date(log.checkInAtUtc).toLocaleString()}</InfoRow>
                    {log.checkOutAtUtc && (
                      <InfoRow label="Check out">{new Date(log.checkOutAtUtc).toLocaleString()}</InfoRow>
                    )}
                  </DescriptionList>
                ))
              )}
            </div>
          </section>

          {/* Chat transcript */}
          <section className="card">
            <div className="card-head">
              <h2>Chat context ({dispute.chatTranscript.length})</h2>
              <MessageSquare size={16} className="c-soft" aria-hidden="true" />
            </div>
            <div className="card-body">
              {dispute.chatTranscript.length === 0 ? (
                <p className="muted">No messages.</p>
              ) : (
                <ol className="timeline chat-scroll" tabIndex={0} aria-label="Chat context">
                  {dispute.chatTranscript.map((msg) => (
                    <li key={msg.id}>
                      <span className="t-meta">{msg.senderName}</span>
                      <div>
                        <div className="ev">{msg.content}</div>
                        <div className="meta">
                          <time dateTime={msg.sentAtUtc}>{new Date(msg.sentAtUtc).toLocaleString()}</time>
                        </div>
                      </div>
                    </li>
                  ))}
                </ol>
              )}
            </div>
          </section>
        </div>

        <div className="stack">
          {/* Parties */}
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

          {/* Resolution actions */}
          <section className="card">
            <div className="card-head">
              <h2>Resolution</h2>
            </div>
            <div className="card-body">
              {!isAlreadyResolved ? (
                <>
                  <Field
                    label="Admin note"
                    optional
                    help="All actions are final. The note is saved with the resolution."
                  >
                    {(a11y) => (
                      <textarea
                        {...a11y}
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        placeholder="Admin note (optional)…"
                        rows={3}
                        className="textarea"
                      />
                    )}
                  </Field>
                  <div className="row">
                    <ActionButton
                      label="Full Refund"
                      icon={<XCircle size={16} />}
                      kind="danger-outline"
                      onClick={() => setPendingAction('FullRefund')}
                    />
                    <ActionButton
                      label="Partial Refund"
                      icon={<AlertTriangle size={16} />}
                      kind="secondary"
                      onClick={() => setPendingAction('PartialRefund')}
                    />
                    <ActionButton
                      label="No Refund"
                      icon={<CheckCircle size={16} />}
                      kind="secondary"
                      onClick={() => setPendingAction('NoRefund')}
                    />
                    <ActionButton
                      label="No Action"
                      icon={<CheckCircle size={16} />}
                      kind="secondary"
                      onClick={() => setPendingAction('None')}
                    />
                  </div>
                </>
              ) : (
                <p className="muted">
                  This dispute has been <strong>{dispute.disputeStatus.toLowerCase()}</strong>. No further
                  actions available.
                </p>
              )}
            </div>
          </section>
        </div>
      </div>

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
  <section className="card">
    <div className="card-head">
      <h2>{title}</h2>
    </div>
    <div className="card-body">
      <DescriptionList>
        <InfoRow label="Name">{name}</InfoRow>
        <InfoRow label="Role">
          <StatusBadge status={role} />
        </InfoRow>
        {isVerified && (
          <InfoRow label="Verification">
            <StatusBadge status="Verified" />
          </InfoRow>
        )}
        <InfoRow label="Jobs" valueClassName="money">
          {jobCount}
        </InfoRow>
        {userId && (
          <InfoRow label="Profile">
            <Link to={`/users/${userId}`} className="cell-link">
              View profile →
            </Link>
          </InfoRow>
        )}
      </DescriptionList>
    </div>
  </section>
);

const ActionButton: React.FC<{
  label: string;
  icon: React.ReactNode;
  kind: 'secondary' | 'danger-outline';
  onClick: () => void;
}> = ({ label, icon, kind, onClick }) => (
  <Button kind={kind} icon={icon} onClick={onClick}>
    {label}
  </Button>
);
