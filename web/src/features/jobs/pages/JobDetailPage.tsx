import React from 'react';
import { Link, useParams } from 'react-router-dom';
import { MessageSquare, Image as ImageIcon } from 'lucide-react';
import { Banner } from '../../../components/Banner';
import { PageHeader } from '../../../components/PageHeader';
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

// ── Component ─────────────────────────────────────────────────────────────────

export const JobDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  // useJobDetail polls while the job is active, so the page stays current on its own.
  const { data: job, isLoading } = useJobDetail(Number(id));

  if (isLoading)
    return (
      <p className="muted" role="status" aria-busy="true">
        Loading job…
      </p>
    );
  if (!job)
    return (
      <Banner variant="error" title="Job not found">
        This job does not exist or is no longer available.
      </Banner>
    );

  const history = [...job.statusHistory].sort(
    (a, b) => new Date(a.changedAtUtc).getTime() - new Date(b.changedAtUtc).getTime(),
  );

  return (
    <div className="stack">
      <PageHeader
        title={job.title}
        description={`${formatJobId(job.id)} · ${job.category} · ${job.address ?? 'No address'}`}
        backLink={{ to: '/jobs', label: 'Jobs' }}
        badge={<StatusBadge status={job.status} size="lg" />}
      />

      {/* Status stepper — correct status mapping, live updates, sublabels */}
      <section className="card">
        <div className="card-body">
          <JobProgressStepper
            status={job.status}
            statusHistory={job.statusHistory}
          />
        </div>
      </section>

      <div className="grid side">
        <div className="stack">
          <section className="card">
            <div className="card-head">
              <h2>Job details</h2>
            </div>
            <div className="card-body">
              {job.description && <p className="desc-text">{job.description}</p>}
              <DescriptionList>
                <InfoRow label="Urgency" valueClassName={job.urgency === 'Urgent' ? 'c-danger' : undefined}>
                  {job.urgency}
                </InfoRow>
                <InfoRow label="Category">{job.category}</InfoRow>
                <InfoRow label="Schedule">{job.scheduleStatus}</InfoRow>
                {job.scheduledDateUtc && (
                  <InfoRow label="Scheduled">{dateTimeFormat.format(new Date(job.scheduledDateUtc))}</InfoRow>
                )}
                <InfoRow label="Posted">{dateTimeFormat.format(new Date(job.createdAtUtc))}</InfoRow>
                <InfoRow label="Last updated">{dateTimeFormat.format(new Date(job.updatedAtUtc))}</InfoRow>
              </DescriptionList>
            </div>
          </section>

          <section className="card">
            <div className="card-head">
              <h2>Photos ({job.photos.length})</h2>
              <ImageIcon size={16} className="c-soft" aria-hidden="true" />
            </div>
            <div className="card-body">
              {job.photos.length === 0 ? (
                <p className="muted">No photos attached.</p>
              ) : (
                <div className="photo-grid">
                  {job.photos.map((photo) => (
                    <a
                      key={photo.id}
                      href={photo.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="photo-tile"
                    >
                      <img src={photo.url} alt={photo.originalFileName ?? `Photo ${photo.id}`} loading="lazy" />
                    </a>
                  ))}
                </div>
              )}
            </div>
          </section>

          <section className="card">
            <div className="card-head">
              <h2>Chat transcript ({job.chatTranscript.length})</h2>
              <MessageSquare size={16} className="c-soft" aria-hidden="true" />
            </div>
            <div className="card-body">
              {job.chatTranscript.length === 0 ? (
                <p className="muted">No messages yet.</p>
              ) : (
                <ol className="timeline chat-scroll" tabIndex={0} aria-label="Chat transcript">
                  {job.chatTranscript.map((msg) => (
                    <li key={msg.id}>
                      <span className="t-meta">{msg.senderName}</span>
                      <div>
                        <div className="ev">{msg.content}</div>
                        <div className="meta">
                          <time dateTime={msg.sentAtUtc}>{dateTimeFormat.format(new Date(msg.sentAtUtc))}</time>
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
          <section className="card">
            <div className="card-head">
              <h2>Homeowner</h2>
            </div>
            <div className="card-body">
              <DescriptionList>
                <InfoRow label="Name">
                  <Link to={`/users/${job.homeownerId}`} className="cell-link">
                    {job.homeownerName}
                  </Link>
                </InfoRow>
                <InfoRow label="User ID" valueClassName="mono">
                  {job.homeownerId}
                </InfoRow>
              </DescriptionList>
            </div>
          </section>

          {job.matchedTradieId && (
            <section className="card">
              <div className="card-head">
                <h2>Tradie</h2>
              </div>
              <div className="card-body">
                <DescriptionList>
                  <InfoRow label="Name">
                    <Link to={`/users/${job.matchedTradieId}`} className="cell-link">
                      {job.tradeName ?? job.matchedTradieId}
                    </Link>
                  </InfoRow>
                  <InfoRow label="Status">{job.status}</InfoRow>
                </DescriptionList>
              </div>
            </section>
          )}

          <section className="card">
            <div className="card-head">
              <h2>Activity timeline</h2>
            </div>
            <div className="card-body">
              <ol className="timeline">
                <li className="done">
                  <time dateTime={job.createdAtUtc}>{timeFormat.format(new Date(job.createdAtUtc))}</time>
                  <div>
                    <div className="ev">Job posted by {job.homeownerName}</div>
                    <div className="meta">{dateTimeFormat.format(new Date(job.createdAtUtc))}</div>
                  </div>
                </li>
                {history.map((h) => (
                  <li key={h.id} className="done">
                    <time dateTime={h.changedAtUtc}>{timeFormat.format(new Date(h.changedAtUtc))}</time>
                    <div>
                      <div className="ev">
                        Status changed to <strong>{h.toStatus}</strong>
                      </div>
                      <div className="meta">
                        {h.changedByName ?? h.changedByUserId} · {dateTimeFormat.format(new Date(h.changedAtUtc))}
                        {h.reason ? ` · ${h.reason}` : ''}
                      </div>
                    </div>
                  </li>
                ))}
              </ol>
              {history.length === 0 && <p className="muted">No status changes recorded yet.</p>}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};
