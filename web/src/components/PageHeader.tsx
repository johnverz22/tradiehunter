/**
 * PageHeader — page title + meta + actions slot for every admin page (design system:
 * COMPONENTS.md "Page header", frames `.breadcrumb` + `.page-header`).
 *
 * Optional breadcrumb above (parent link, then the current title with aria-current="page"),
 * `h1` with an optional badge, optional `.sub` line, `.page-actions` on the right (full width
 * below the title on phones), optional meta row underneath.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import { ChevronRight } from 'lucide-react';

export interface PageHeaderProps {
  /** Page title — rendered as <h1>. */
  title: string;
  /** Optional sub-line below the title. */
  description?: string;
  /** Row of small stat/badge elements (rendered below the header). */
  meta?: React.ReactNode;
  /** Button(s) slot — desktop: right of title; phone: full-width below. */
  actions?: React.ReactNode;
  /** Parent page for the breadcrumb above the title (the current crumb is `title`). */
  backLink?: { to: string; label: string };
  /** Small badge next to the title (e.g. "Admin"). */
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
  <div className="stack">
    {backLink && (
      <nav className="breadcrumb" aria-label="Breadcrumb">
        <Link to={backLink.to}>{backLink.label}</Link>
        <ChevronRight size={14} aria-hidden="true" />
        <span aria-current="page">{title}</span>
      </nav>
    )}

    <div className="page-header">
      <div className="min-w-0">
        <div className="row">
          <h1>{title}</h1>
          {badge}
        </div>
        {description && <div className="sub">{description}</div>}
      </div>

      {/* Actions: right on sm+, full-width stacked below on phone */}
      {actions && <div className="page-actions w-full sm:w-auto">{actions}</div>}
    </div>

    {meta && <div className="flex flex-wrap gap-3">{meta}</div>}
  </div>
);
