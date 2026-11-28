/**
 * Read-only sections of the admin user page: everything the user supplied from the app,
 * credential status, the review summary and suggestion eligibility.
 * Presentation only — data comes from `useUserDetail`.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import { Banner } from '../../../components/Banner';
import { DataTable, type ColumnDef } from '../../../components/DataTable';
import { DescriptionList, InfoRow } from '../../../components/DescriptionList';
import { StatusBadge } from '../../../components/StatusBadge';
import type {
  AdminCredential,
  AdminReviewSummary,
  AdminScheduleSlot,
  AdminTradieDetails,
  AdminTradieRate,
  AdminUserDetail,
} from '../../../services/adminApi';

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const money = (amount: number) =>
  new Intl.NumberFormat('en-NZ', { style: 'currency', currency: 'NZD' }).format(amount);

const yesNo = (value: boolean) => (value ? 'Yes' : 'No');

const MISSING = <span className="muted">Not provided</span>;

const Stars: React.FC<{ rating: number }> = ({ rating }) => (
  <span aria-label={`${rating} out of 5 stars`}>
    <span aria-hidden="true">{'★'.repeat(rating)}{'☆'.repeat(5 - rating)}</span>
  </span>
);

// ── Profile the user filled in on mobile ──────────────────────────────────────

export const ProfileDetailsCard: React.FC<{ user: AdminUserDetail }> = ({ user }) => {
  const t = user.tradieDetails;
  return (
    <section className="card">
      <div className="card-head">
        <h2>Profile details</h2>
      </div>
      <div className="card-body">
        <DescriptionList>
          <InfoRow label="Phone">{user.phoneNumber || MISSING}</InfoRow>
          <InfoRow label="Email verified">{yesNo(user.emailVerified)}</InfoRow>
          {t && (
            <>
              <InfoRow label="Trade">{user.tradeType || MISSING}</InfoRow>
              <InfoRow label="Registration no.">{t.registrationNumber || MISSING}</InfoRow>
              <InfoRow label="About">{t.bio || MISSING}</InfoRow>
              <InfoRow label="Base address">{t.address || MISSING}</InfoRow>
              <InfoRow label="Service radius">{`${t.serviceRadiusKm} km`}</InfoRow>
              <InfoRow label="Available for work">{yesNo(t.isAvailable)}</InfoRow>
              <InfoRow label="Insurance">{yesNo(t.hasInsurance)}</InfoRow>
              <InfoRow label="GST registered">{yesNo(t.isGstRegistered)}</InfoRow>
              <InfoRow label="Cancellations">{t.cancellationCount}</InfoRow>
              <InfoRow label="Payout account">
                {t.bankAccountMasked ? (
                  <>
                    {t.bankAccountName ? `${t.bankAccountName} · ` : ''}
                    <span className="mono">{t.bankAccountMasked}</span>{' '}
                    <StatusBadge status={t.bankAccountVerified ? 'Verified' : 'Unverified'} />
                  </>
                ) : (
                  MISSING
                )}
              </InfoRow>
            </>
          )}
        </DescriptionList>
      </div>
    </section>
  );
};

// ── Credentials ───────────────────────────────────────────────────────────────

const credentialColumns: ColumnDef<AdminCredential>[] = [
  { key: 'type', header: 'Type', priority: 'primary', cell: (c) => c.type },
  { key: 'status', header: 'Status', priority: 'secondary', cell: (c) => <StatusBadge status={c.status} /> },
  { key: 'file', header: 'File', priority: 'detail', cell: (c) => <span className="mono">{c.originalFileName}</span> },
  {
    key: 'reviewed',
    header: 'Reviewed',
    priority: 'detail',
    cell: (c) => (c.reviewedAtUtc ? new Date(c.reviewedAtUtc).toLocaleDateString() : '—'),
  },
  { key: 'reason', header: 'Reject reason', priority: 'detail', cell: (c) => c.rejectReason ?? '—' },
];

export const CredentialsCard: React.FC<{ credentials: AdminCredential[] }> = ({ credentials }) => (
  <section className="card flush">
    <div className="card-head">
      <h2>Credentials</h2>
      <Link to="/credentials" className="btn btn-ghost btn-sm">
        Review queue
      </Link>
    </div>
    <div className="card-body">
      <DataTable
        columns={credentialColumns}
        rows={credentials}
        getRowKey={(c) => c.id}
        empty="No credentials uploaded."
      />
    </div>
  </section>
);

// ── Services and rates ────────────────────────────────────────────────────────

const rateColumns: ColumnDef<AdminTradieRate>[] = [
  { key: 'service', header: 'Service', priority: 'primary', cell: (r) => r.serviceName },
  {
    key: 'licence',
    header: 'Licence needed',
    priority: 'detail',
    cell: (r) => yesNo(r.requiresLicence),
  },
  {
    key: 'rate',
    header: 'Hourly rate',
    priority: 'secondary',
    align: 'right',
    cell: (r) => money(r.hourlyRate),
  },
];

export const RatesCard: React.FC<{ rates: AdminTradieRate[] }> = ({ rates }) => (
  <section className="card flush">
    <div className="card-head">
      <h2>Services and rates</h2>
    </div>
    <div className="card-body">
      <DataTable columns={rateColumns} rows={rates} getRowKey={(r) => r.serviceId} empty="No services listed." />
    </div>
  </section>
);

// ── Weekly availability ───────────────────────────────────────────────────────

export const ScheduleCard: React.FC<{ schedule: AdminScheduleSlot[] }> = ({ schedule }) => (
  <section className="card">
    <div className="card-head">
      <h2>Weekly availability</h2>
    </div>
    <div className="card-body">
      {schedule.length === 0 ? (
        <p className="muted">No working hours set.</p>
      ) : (
        <DescriptionList>
          {schedule.map((slot, i) => (
            <InfoRow key={`${slot.weekday}-${slot.startTime}-${i}`} label={WEEKDAYS[slot.weekday] ?? `Day ${slot.weekday}`}>
              <span className="mono">
                {slot.startTime}–{slot.endTime}
              </span>
            </InfoRow>
          ))}
        </DescriptionList>
      )}
    </div>
  </section>
);

// ── Suggestion eligibility ────────────────────────────────────────────────────

export const EligibilityCard: React.FC<{ details: AdminTradieDetails }> = ({ details }) => (
  <section className="card">
    <div className="card-head">
      <h2>Job suggestions</h2>
      <StatusBadge status={details.isOfferable ? 'Active' : 'Inactive'} />
    </div>
    <div className="card-body">
      {details.isOfferable ? (
        <p>Eligible to be suggested to homeowners within their service area.</p>
      ) : (
        <>
          <p>Not suggested to homeowners right now:</p>
          <ul className="stack">
            {details.eligibilityIssues.map((issue) => (
              <li key={issue}>{issue}</li>
            ))}
          </ul>
        </>
      )}
    </div>
  </section>
);

// ── Ratings and reviews ───────────────────────────────────────────────────────

export const RatingsCard: React.FC<{ user: AdminUserDetail }> = ({ user }) => (
  <section className="card">
    <div className="card-head">
      <h2>Ratings</h2>
    </div>
    <div className="card-body">
      {user.reviewCount === 0 ? (
        <p className="muted">No reviews yet.</p>
      ) : (
        <>
          <p>
            <strong className="money">★ {user.averageRating.toFixed(1)}</strong>{' '}
            <span className="muted">
              from {user.reviewCount} {user.reviewCount === 1 ? 'review' : 'reviews'}
            </span>
          </p>
          <ul className="stack list-none p-0 m-0">
            {[5, 4, 3, 2, 1].map((star) => {
              const count = user.ratingBreakdown?.[String(star)] ?? 0;
              return (
                <li key={star} className="flex items-center gap-3 text-sm">
                  <span className="shrink-0 mono">{star} ★</span>
                  <progress
                    className="flex-1 min-w-0"
                    max={user.reviewCount}
                    value={count}
                    aria-label={`${count} ${star}-star reviews`}
                  />
                  <span className="shrink-0 mono">{count}</span>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </div>
  </section>
);

export const TopReviewsCard: React.FC<{ reviews: AdminReviewSummary[] }> = ({ reviews }) => (
  <section className="card">
    <div className="card-head">
      <h2>Top reviews</h2>
    </div>
    <div className="card-body">
      {reviews.length === 0 ? (
        <p className="muted">No reviews yet.</p>
      ) : (
        <ul className="stack list-none p-0 m-0">
          {reviews.map((r) => (
            <li key={r.id} className="stack">
              <div className="flex items-baseline justify-between gap-3">
                <Stars rating={r.rating} />
                <span className="muted text-sm">{new Date(r.createdAtUtc).toLocaleDateString()}</span>
              </div>
              {r.comment ? <p>{r.comment}</p> : <p className="muted">No comment.</p>}
              <p className="muted text-sm">
                {r.reviewerName} ·{' '}
                <Link to={`/jobs/${r.jobId}`} className="cell-link">
                  JOB-{String(r.jobId).padStart(5, '0')}
                </Link>
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  </section>
);

// ── Account state notices ─────────────────────────────────────────────────────

export const AccountNotices: React.FC<{ user: AdminUserDetail; onReactivate: () => void }> = ({
  user,
  onReactivate,
}) => (
  <>
    {!user.isActive && (
      <Banner variant="error" title="Account deactivated" action={{ label: 'Reactivate', onClick: onReactivate }}>
        {user.deactivation ? (
          <>
            {user.deactivation.note || 'No note recorded.'}
            <span className="muted">
              {' '}
              — {user.deactivation.byName ?? 'Staff'}, {new Date(user.deactivation.atUtc).toLocaleString()}
            </span>
          </>
        ) : (
          'No deactivation note was recorded for this account.'
        )}
      </Banner>
    )}
    {user.isActive && user.reactivation && (
      <Banner variant="info" title="Previously deactivated, then reactivated">
        {user.reactivation.note || 'No note recorded.'}
        <span className="muted">
          {' '}
          — {user.reactivation.byName ?? 'Staff'}, {new Date(user.reactivation.atUtc).toLocaleString()}
        </span>
      </Banner>
    )}
    {user.emailBouncedAtUtc && (
      <Banner variant="warn" title="Emails to this user are bouncing">
        Notifications such as deactivation and credential decisions will not reach {user.email}. Contact them another
        way.
      </Banner>
    )}
  </>
);
