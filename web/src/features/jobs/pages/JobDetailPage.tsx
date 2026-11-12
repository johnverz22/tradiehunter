import React, { useCallback, useState, useEffect } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, MessageSquare, Image as ImageIcon, RefreshCw } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
import { JobProgressStepper } from '../../../components/JobProgressStepper';
import { useJobDetail } from '../hooks/useJobs';

// ── Formatters ────────────────────────────────────────────────────────────────

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

/** Returns a human-readable "X ago" label from a timestamp in ms. */
function timeAgo(ms: number): string {
  const seconds = Math.floor((Date.now() - ms) / 1000);
  if (seconds < 10)  return 'just now';
  if (seconds < 60)  return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60)  return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ago`;
}

// ── Component ─────────────────────────────────────────────────────────────────

export const JobDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const {
    data: job,
    isLoading,
    dataUpdatedAt,
    refetch,
    isFetching,
  } = useJobDetail(Number(id));

  // Tick the "Updated X ago" label every 15 s.
  const [, setTick] = useState(0);
  useEffect(() => {
    const timer = setInterval(() => setTick((n) => n + 1), 15_000);
    return () => clearInterval(timer);
  }, []);

  const handleRefresh = useCallback(() => { void refetch(); }, [refetch]);

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading job…</div>;
  if (!job)
    return <div className="text-[var(--red)] text-sm p-4">Job not found.</div>;

  const history = [...job.statusHistory].sort(
    (a, b) => new Date(a.changedAtUtc).getTime() - new Date(b.changedAtUtc).getTime(),
  );

  const updatedCaption = (
    <span className="inline-flex items-center gap-1.5">
      {timeAgo(dataUpdatedAt)}
      <button
        type="button"
        onClick={handleRefresh}
        disabled={isFetching}
        aria-label="Refresh job status"
        className="inline-flex items-center justify-center rounded p-0.5 hover:opacity-80 disabled:opacity-40 transition-opacity"
      >
        <RefreshCw
          size={12}
          aria-hidden="true"
          className={isFetching ? 'animate-spin' : ''}
        />
      </button>
    </span>
  );

  return (
    <div className="space-y-6">
      {/* Breadcrumb */}
      <div className="text-[13px] text-[var(--ink)] opacity-60">
        <Link to="/jobs" className="inline-flex items-center gap-1.5 hover:underline">
          <ArrowLeft size={13} /> Jobs
        </Link>{' '}
        / <span className="mono">{formatJobId(job.id)}</span>
      </div>

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div>
          <h1 className="text-[22px] sm:text-[24px] font-bold text-[var(--ink)] mb-1">
            {job.title}
          </h1>
          <p className="mono text-[13px] text-[var(--ink)] opacity-60">
            {formatJobId(job.id)} • {job.category} • {job.address ?? 'No address'}
          </p>
        </div>
        <StatusBadge status={job.status} size="lg" />
      </div>

      {/* Status stepper — correct status mapping, live updates, sublabels */}
      <JobProgressStepper
        status={job.status}
        statusHistory={job.statusHistory}
        updatedCaption={updatedCaption}
      />

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

            <DescriptionList>
              <InfoRow
                label="Urgency"
                valueClassName={job.urgency === 'Urgent' ? 'text-[var(--red-ink)]' : undefined}
              >
                {job.urgency}
              </InfoRow>
              <InfoRow label="Category">{job.category}</InfoRow>
              <InfoRow label="Schedule">{job.scheduleStatus}</InfoRow>
              {job.scheduledDateUtc && (
                <InfoRow label="Scheduled">
                  {dateTimeFormat.format(new Date(job.scheduledDateUtc))}
                </InfoRow>
              )}
              <InfoRow label="Posted">
                {dateTimeFormat.format(new Date(job.createdAtUtc))}
              </InfoRow>
              <InfoRow label="Last updated">
                {dateTimeFormat.format(new Date(job.updatedAtUtc))}
              </InfoRow>
            </DescriptionList>
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
            <DescriptionList>
              <InfoRow label="Name">
                <Link to={`/users/${job.homeownerId}`} className="cell-link">
                  {job.homeownerName}
                </Link>
              </InfoRow>
              <InfoRow label="User ID" valueClassName="mono">{job.homeownerId}</InfoRow>
            </DescriptionList>
          </div>

          {job.matchedTradieId && (
            <div className="card">
              <h3 className="card-title">Tradie</h3>
              <DescriptionList>
                <InfoRow label="Name">
                  <Link to={`/users/${job.matchedTradieId}`} className="cell-link">
                    {job.tradeName ?? job.matchedTradieId}
                  </Link>
                </InfoRow>
                <InfoRow label="Status">{job.status}</InfoRow>
              </DescriptionList>
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
