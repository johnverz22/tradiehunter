import React from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, MessageSquare, Image as ImageIcon } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { useJobDetail } from '../hooks/useJobs';

/** The mockup's four-step progress flow. */
const STEPS = ['Requested', 'Matched', 'Confirmed', 'Complete'] as const;

const STEP_INDEX: Record<string, number> = {
  Draft: 0,
  Requested: 0,
  Matching: 0,
  Matched: 1,
  Confirmed: 2,
  InProgress: 2,
  Complete: 3,
};

const formatJobId = (id: number) => `JOB-${String(id).padStart(5, '0')}`;

const timeFormat = new Intl.DateTimeFormat('en-NZ', {
  hour: 'numeric',
  minute: '2-digit',
});

const dateTimeFormat = new Intl.DateTimeFormat('en-NZ', {
  day: 'numeric',
  month: 'short',
  hour: 'numeric',
  minute: '2-digit',
});

export const JobDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { data: job, isLoading } = useJobDetail(Number(id));

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading job…</div>;
  if (!job)
    return <div className="text-[var(--red)] text-sm p-4">Job not found.</div>;

  const isCancelled = job.status === 'Cancelled';
  const isComplete = job.status === 'Complete';
  const currentStep = STEP_INDEX[job.status] ?? 0;

  const history = [...job.statusHistory].sort(
    (a, b) => new Date(a.changedAtUtc).getTime() - new Date(b.changedAtUtc).getTime(),
  );

  return (
    <div className="space-y-6">
      {/* Breadcrumb */}
      <div className="text-[13px] text-[var(--ink)] opacity-60">
        <Link to="/jobs" className="inline-flex items-center gap-1.5">
          <ArrowLeft size={13} /> Jobs
        </Link>{' '}
        / <span className="mono">{formatJobId(job.id)}</span>
      </div>

      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-[24px] font-bold text-[var(--ink)] mb-1">{job.title}</h1>
          <p className="mono text-[13px] text-[var(--ink)] opacity-60">
            {formatJobId(job.id)} • {job.category} • {job.address ?? 'No address'}
          </p>
        </div>
        <StatusBadge status={job.status} size="lg" />
      </div>

      {/* Status stepper */}
      <div className="stepper">
        {STEPS.map((label, i) => {
          const done = i < currentStep || isComplete;
          const active = i === currentStep && !isComplete;
          const state = isCancelled && active ? 'cancelled' : done ? 'done' : active ? 'active' : '';
          return (
            <div key={label} className={`step ${state}`}>
              <div className="step-line" />
              <div className="step-dot" />
              <div className="step-label">{isCancelled && active ? 'Cancelled' : label}</div>
            </div>
          );
        })}
      </div>

      {/* Details */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="card">
            <h3 className="card-title">Job Details</h3>

            {job.description && (
              <p className="text-[15px] leading-relaxed text-[var(--ink)] mb-4 whitespace-pre-wrap">
                {job.description}
              </p>
            )}

            <div className="detail-row">
              <span className="detail-label">Urgency</span>
              <span
                className="detail-value"
                style={{ color: job.urgency === 'Urgent' ? 'var(--red-ink)' : undefined }}
              >
                {job.urgency}
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Category</span>
              <span className="detail-value">{job.category}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Schedule</span>
              <span className="detail-value">{job.scheduleStatus}</span>
            </div>
            {job.scheduledDateUtc && (
              <div className="detail-row">
                <span className="detail-label">Scheduled</span>
                <span className="detail-value">
                  {dateTimeFormat.format(new Date(job.scheduledDateUtc))}
                </span>
              </div>
            )}
            <div className="detail-row">
              <span className="detail-label">Posted</span>
              <span className="detail-value">
                {dateTimeFormat.format(new Date(job.createdAtUtc))}
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">Last updated</span>
              <span className="detail-value">
                {dateTimeFormat.format(new Date(job.updatedAtUtc))}
              </span>
            </div>
          </div>

          {/* Photos */}
          <div className="card">
            <h3 className="card-title">
              <ImageIcon size={14} className="inline -mt-0.5 mr-1.5" aria-hidden="true" />
              Photos ({job.photos.length})
            </h3>
            {job.photos.length === 0 ? (
              <p className="text-sm text-[var(--ink-soft)] py-4 text-center">No photos attached.</p>
            ) : (
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                {job.photos.map((photo) => (
                  <a
                    key={photo.id}
                    href={photo.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="block aspect-4/3 rounded overflow-hidden border border-[var(--brand-100)] hover:border-[var(--brand-300)] transition-colors"
                  >
                    <img
                      src={photo.url}
                      alt={photo.originalFileName ?? `Photo ${photo.id}`}
                      className="w-full h-full object-cover"
                      loading="lazy"
                    />
                  </a>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Participants */}
        <div className="space-y-6">
          <div className="card">
            <h3 className="card-title">Homeowner</h3>
            <div className="detail-row">
              <span className="detail-label">Name</span>
              <Link to={`/users/${job.homeownerId}`} className="detail-value cell-link">
                {job.homeownerName}
              </Link>
            </div>
            <div className="detail-row">
              <span className="detail-label">User ID</span>
              <span className="detail-value mono">{job.homeownerId}</span>
            </div>
          </div>

          {job.matchedTradieId && (
            <div className="card">
              <h3 className="card-title">Tradie</h3>
              <div className="detail-row">
                <span className="detail-label">Name</span>
                <Link to={`/users/${job.matchedTradieId}`} className="detail-value cell-link">
                  {job.tradeName ?? job.matchedTradieId}
                </Link>
              </div>
              <div className="detail-row">
                <span className="detail-label">Status</span>
                <span className="detail-value">{job.status}</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Activity timeline */}
      <div className="card">
        <h3 className="card-title">Activity Timeline</h3>

        <div className="timeline">
          <div className="timeline-item">
            <div className="timeline-time">
              {timeFormat.format(new Date(job.createdAtUtc))}
            </div>
            <div>
              <div className="timeline-event">Job posted by {job.homeownerName}</div>
              <div className="timeline-meta">{dateTimeFormat.format(new Date(job.createdAtUtc))}</div>
            </div>
          </div>

          {history.map((h) => (
            <div key={h.id} className="timeline-item">
              <div className="timeline-time">
                {timeFormat.format(new Date(h.changedAtUtc))}
              </div>
              <div>
                <div className="timeline-event">
                  Status changed to <strong>{h.toStatus}</strong>
                </div>
                <div className="timeline-meta">
                  {h.changedByName ?? h.changedByUserId} •{' '}
                  {dateTimeFormat.format(new Date(h.changedAtUtc))}
                  {h.reason ? ` • ${h.reason}` : ''}
                </div>
              </div>
            </div>
          ))}

          {history.length === 0 && (
            <p className="text-sm text-[var(--ink-soft)] py-4 text-center">
              No status changes recorded yet.
            </p>
          )}
        </div>
      </div>

      {/* Chat transcript */}
      <div className="card">
        <h3 className="card-title">
          <MessageSquare size={14} className="inline -mt-0.5 mr-1.5" aria-hidden="true" />
          Chat Transcript ({job.chatTranscript.length})
        </h3>
        {job.chatTranscript.length === 0 ? (
          <p className="text-sm text-[var(--ink-soft)] py-4 text-center">No messages yet.</p>
        ) : (
          <div className="max-h-[400px] overflow-y-auto">
            {job.chatTranscript.map((msg) => (
              <div key={msg.id} className="timeline-item">
                <div className="timeline-time">{msg.senderName}</div>
                <div>
                  <div className="timeline-event">{msg.content}</div>
                  <div className="timeline-meta">
                    {dateTimeFormat.format(new Date(msg.sentAtUtc))}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
