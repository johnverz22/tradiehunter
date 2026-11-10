/**
 * PageHeader — unified page title + meta + actions slot for every admin page.
 *
 * Desktop/tablet: title left, actions right.
 * Phone: title stacks, actions render full-width below.
 *
 * Replaces the hand-rolled <h1> + stat-pills + action buttons scattered
 * across every page. Desktop layout is visually identical to what was there.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';

export interface PageHeaderProps {
  /** Page title — rendered as <h1> with display font. */
  title: string;
  /** Optional sub-line below the title. */
  description?: string;
  /** Stat pills row (rendered below title). */
  meta?: React.ReactNode;
  /** Button(s) slot — desktop: right of title; phone: full-width below. */
  actions?: React.ReactNode;
  /** Breadcrumb back link above the title. */
  backLink?: { to: string; label: string };
  /** Small badge next to the title (e.g. "Admin" pill). */
  badge?: React.ReactNode;
}

export const PageHeader: React.FC<PageHeaderProps> = ({
  title,
  description,
  meta,
  actions,
  backLink,
  badge,
}) => (
  <div className="space-y-3">
    {backLink && (
      <Link
        to={backLink.to}
        className="inline-flex items-center gap-1 text-[13px] text-[var(--ink-soft)] hover:text-[var(--ink)] transition-colors"
      >
        <ChevronLeft size={14} aria-hidden="true" />
        {backLink.label}
      </Link>
    )}

    {/* Title row */}
    <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
      <div className="min-w-0">
        <div className="flex items-center gap-3 flex-wrap">
          <h1
            className="text-[22px] sm:text-[28px] font-bold text-[var(--ink)] leading-tight m-0"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            {title}
          </h1>
          {badge}
        </div>

        {description && (
          <p className="text-sm text-[var(--ink-soft)] mt-1">{description}</p>
        )}
      </div>

      {/* Actions: right on sm+, full-width stacked below on phone */}
      {actions && (
        <div className="flex flex-wrap gap-2 shrink-0 sm:items-start w-full sm:w-auto">
          {actions}
        </div>
      )}
    </div>

    {/* Stat pills */}
    {meta && (
      <div className="flex flex-wrap gap-3">{meta}</div>
    )}
  </div>
);
