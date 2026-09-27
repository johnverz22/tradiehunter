import React, { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, MessageSquare, Clock, Image as ImageIcon } from 'lucide-react';
import { StatusBadge } from '../../../components/StatusBadge';
import { InfoRow } from '../../../components/InfoRow';
import { useJobDetail } from '../hooks/useJobs';

export const JobDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { data: job, isLoading } = useJobDetail(Number(id));
  const [tab, setTab] = useState<'info' | 'chat' | 'timeline' | 'photos'>('info');

  if (isLoading)
    return <div className="text-[var(--ink-soft)] text-sm p-4">Loading job…</div>;
  if (!job)
    return <div className="text-[var(--red)] text-sm p-4">Job not found.</div>;

  return (
    <div className="space-y-5 max-w-4xl">
      {/* Back */}
      <Link
        to="/jobs"
        className="inline-flex items-center gap-1.5 text-sm text-[var(--ink-soft)] hover:text-[var(--ink)]"
      >
        <ArrowLeft size={14} /> Back to Jobs
      </Link>

      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-[var(--ink)]">{job.title}</h1>
          <p className="text-sm text-[var(--ink-soft)]">
            {job.category} · {job.address ?? 'No address'}
          </p>
        </div>
        <StatusBadge status={job.status} />
      </div>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-[var(--paper-line)]">
        {(
          [
            ['info', 'Info'],
            ['chat', `Chat (${job.chatTranscript.length})`],
            ['timeline', 'Timeline'],
            ['photos', `Photos (${job.photos.length})`],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={[
              'px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors',
              tab === key
                ? 'border-[var(--brand-500)] text-[var(--brand-700)]'
                : 'border-transparent text-[var(--ink-soft)] hover:text-[var(--ink)]',
            ].join(' ')}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {tab === 'info' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="border border-[var(--paper-line)] rounded-lg p-5 space-y-3">
            <h2 className="text-sm font-semibold text-[var(--ink)]">Job Info</h2>
            <InfoRow label="ID" value={String(job.id)} mono />
            <InfoRow label="Status" value={job.status} />
            <InfoRow label="Category" value={job.category} />
            <InfoRow label="Urgency" value={job.urgency} />
            <InfoRow label="Schedule" value={job.scheduleStatus} />
            {job.scheduledDateUtc && (
              <InfoRow
                label="Scheduled"
                value={new Date(job.scheduledDateUtc).toLocaleString()}
              />
            )}
            <InfoRow label="Created" value={new Date(job.createdAtUtc).toLocaleString()} />
            <InfoRow label="Updated" value={new Date(job.updatedAtUtc).toLocaleString()} />
          </div>
          <div className="border border-[var(--paper-line)] rounded-lg p-5 space-y-3">
            <h2 className="text-sm font-semibold text-[var(--ink)]">Participants</h2>
            <div>
              <p className="text-xs text-[var(--ink-soft)] mb-0.5">Homeowner</p>
              <Link
                to={`/users/${job.homeownerId}`}
                className="text-sm text-[var(--brand-500)] hover:underline"
              >
                {job.homeownerName}
              </Link>
            </div>
            {job.matchedTradieId && (
              <div>
                <p className="text-xs text-[var(--ink-soft)] mb-0.5">Tradie</p>
                <Link
                  to={`/users/${job.matchedTradieId}`}
                  className="text-sm text-[var(--brand-500)] hover:underline"
                >
                  {job.tradeName ?? job.matchedTradieId}
                </Link>
              </div>
            )}
          </div>
          {job.description && (
            <div className="border border-[var(--paper-line)] rounded-lg p-5 col-span-full">
              <h2 className="text-sm font-semibold text-[var(--ink)] mb-2">Description</h2>
              <p className="text-sm text-[var(--ink-soft)] whitespace-pre-wrap">{job.description}</p>
            </div>
          )}
        </div>
      )}

      {tab === 'chat' && (
        <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
          <div className="px-5 py-3 border-b border-[var(--paper-line)] flex items-center gap-2">
            <MessageSquare size={14} className="text-[var(--ink-soft)]" />
            <span className="text-sm font-medium text-[var(--ink)]">Chat Transcript (read-only)</span>
          </div>
          {job.chatTranscript.length === 0 ? (
            <div className="px-5 py-8 text-center text-sm text-[var(--ink-soft)]">
              No messages yet.
            </div>
          ) : (
            <div className="divide-y divide-[var(--paper-line)] max-h-[500px] overflow-y-auto">
              {job.chatTranscript.map((msg) => (
                <div key={msg.id} className="px-5 py-3">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-semibold text-[var(--ink)]">
                      {msg.senderName}
                    </span>
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
      )}

      {tab === 'timeline' && (
        <div className="border border-[var(--paper-line)] rounded-lg overflow-hidden">
          <div className="px-5 py-3 border-b border-[var(--paper-line)] flex items-center gap-2">
            <Clock size={14} className="text-[var(--ink-soft)]" />
            <span className="text-sm font-medium text-[var(--ink)]">Status History</span>
          </div>
          {job.statusHistory.length === 0 ? (
            <div className="px-5 py-8 text-center text-sm text-[var(--ink-soft)]">
              No history yet.
            </div>
          ) : (
            <div className="px-5 py-4">
              <ol className="relative border-l border-[var(--paper-line)] ml-3 space-y-5">
                {job.statusHistory.map((h) => (
                  <li key={h.id} className="ml-5">
                    <span className="absolute -left-1.5 mt-1 w-3 h-3 rounded-full bg-[var(--brand-500)] border-2 border-[var(--paper)]" />
                    <div className="flex items-center gap-2 mb-0.5">
                      <StatusBadge status={h.fromStatus} />
                      <span className="text-xs text-[var(--ink-soft)]">→</span>
                      <StatusBadge status={h.toStatus} />
                    </div>
                    <p className="text-xs text-[var(--ink-soft)]">
                      {h.changedByName ?? h.changedByUserId} ·{' '}
                      {new Date(h.changedAtUtc).toLocaleString()}
                    </p>
                    {h.reason && (
                      <p className="text-xs text-[var(--ink-soft)] mt-0.5 italic">{h.reason}</p>
                    )}
                  </li>
                ))}
              </ol>
            </div>
          )}
        </div>
      )}

      {tab === 'photos' && (
        <div className="border border-[var(--paper-line)] rounded-lg p-5">
          <div className="flex items-center gap-2 mb-4">
            <ImageIcon size={14} className="text-[var(--ink-soft)]" />
            <span className="text-sm font-medium text-[var(--ink)]">Job Photos</span>
          </div>
          {job.photos.length === 0 ? (
            <p className="text-sm text-[var(--ink-soft)] text-center py-8">No photos attached.</p>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
              {job.photos.map((photo) => (
                <a
                  key={photo.id}
                  href={photo.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block aspect-square rounded-lg overflow-hidden border border-[var(--paper-line)] hover:border-[var(--brand-300)] transition-colors"
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
      )}
    </div>
  );
};


