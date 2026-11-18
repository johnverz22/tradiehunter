import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

/**
 * Pagination — design system `nav.pagination` (COMPONENTS.md "Pagination"): summary text, then
 * previous / numbered / next `.page-btn`s. Current page has `aria-current="page"`; previous is
 * disabled on the first page; previous and next carry labels.
 */
interface PaginationProps {
  page: number;
  totalPages: number;
  pageSize: number;
  totalCount: number;
  /** Plural noun for the summary line, e.g. "jobs". */
  itemLabel: string;
  onPageChange: (page: number) => void;
}

/** First/last page, the current page with a neighbour either side, `…` for the gaps. */
function pageWindow(page: number, totalPages: number): (number | 'gap')[] {
  if (totalPages <= 7) return Array.from({ length: totalPages }, (_, i) => i + 1);

  const wanted = new Set([1, totalPages, page, page - 1, page + 1]);
  const pages = [...wanted]
    .filter((p) => p >= 1 && p <= totalPages)
    .sort((a, b) => a - b);

  const window: (number | 'gap')[] = [];
  pages.forEach((p, i) => {
    if (i > 0 && p - pages[i - 1] > 1) window.push('gap');
    window.push(p);
  });
  return window;
}

export const Pagination: React.FC<PaginationProps> = ({
  page,
  totalPages,
  pageSize,
  totalCount,
  itemLabel,
  onPageChange,
}) => {
  // Nothing to summarise — "Showing 0–0 of 0 jobs" is just noise above the
  // table's own empty state.
  if (totalCount === 0) return null;

  const from = (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, totalCount);

  return (
    <nav className="pagination" aria-label="Pagination">
      <span>
        Showing {from.toLocaleString()}–{to.toLocaleString()} of{' '}
        {totalCount.toLocaleString()} {itemLabel}
      </span>

      {totalPages > 1 && (
        <div className="page-buttons">
          <button
            type="button"
            className="page-btn"
            onClick={() => onPageChange(page - 1)}
            disabled={page <= 1}
            aria-label="Previous page"
          >
            <ChevronLeft size={18} aria-hidden="true" />
          </button>

          {pageWindow(page, totalPages).map((entry, i) =>
            entry === 'gap' ? (
              <span key={`gap-${i}`} className="px-1" aria-hidden="true">
                …
              </span>
            ) : (
              <button
                key={entry}
                type="button"
                className="page-btn"
                aria-current={entry === page ? 'page' : undefined}
                onClick={() => onPageChange(entry)}
                aria-label={`Page ${entry}`}
              >
                {entry}
              </button>
            ),
          )}

          <button
            type="button"
            className="page-btn"
            onClick={() => onPageChange(page + 1)}
            disabled={page >= totalPages}
            aria-label="Next page"
          >
            <ChevronRight size={18} aria-hidden="true" />
          </button>
        </div>
      )}
    </nav>
  );
};
