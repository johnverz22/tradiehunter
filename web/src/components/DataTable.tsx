/**
 * DataTable<T> — unified table / card-list component.
 *
 * Rendering strategy (driven by useBreakpoint):
 *   Desktop:          full <table> with all columns
 *   Tablet landscape: full <table> with all columns
 *   Tablet portrait:  <table> but 'detail' columns are hidden (lg:table-cell)
 *   Phone:            <ul> card list
 *
 * Column priorities:
 *   primary   — always visible; becomes the card title on phone
 *   secondary — table + card label/value pairs
 *   detail    — table only (hidden on phone; hidden on tablet portrait)
 *
 * Row actions:
 *   primary=true  → shown as a button directly in the card footer
 *   others        → collected into a "⋯ More" <details> menu
 *
 * Loading: skeleton rows/cards
 * Pagination: pass a <Pagination> node as `pagination` prop
 *
 * Markup is the design-system data table (COMPONENTS.md "Data table"): `.table-wrap > .table`,
 * `<th scope="col">`, sortable headers are real buttons with `aria-sort`, the actions column has a
 * visually hidden header, pagination sits inside the wrapper under the table.
 * The phone card list is kept (presentation restyled on tokens); see todo decision D9.
 */
import React from 'react';
import { Link } from 'react-router-dom';
import { ChevronDown, ChevronUp, MoreHorizontal } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';

// ── Types ─────────────────────────────────────────────────────────────────────

export type ColumnPriority = 'primary' | 'secondary' | 'detail';

export interface ColumnDef<T> {
  key: string;
  header: string;
  cell: (row: T) => React.ReactNode;
  priority: ColumnPriority;
  align?: 'left' | 'right' | 'center';
  sortable?: boolean;
  /** Tailwind width class applied to <th>/<td> in table mode, e.g. 'w-32' */
  width?: string;
}

export interface RowAction {
  label: string;
  onClick?: () => void;
  to?: string;
  variant?: 'primary' | 'danger' | 'ghost';
  disabled?: boolean;
  /** If true, this action is shown directly in the card footer rather than in the ⋯ menu. */
  primary?: boolean;
}

export interface SortState {
  key: string;
  desc: boolean;
}

export interface DataTableProps<T> {
  columns: ColumnDef<T>[];
  rows: T[] | undefined;
  getRowKey: (row: T) => string | number;
  getRowClassName?: (row: T) => string | undefined;
  onRowClick?: (row: T) => void;
  isLoading?: boolean;
  /** Content to show when rows is empty (after loading). */
  empty?: React.ReactNode;
  /** Content to show when there's a fetch error. */
  error?: React.ReactNode;
  sortState?: SortState;
  onSort?: (key: string) => void;
  /** Per-row actions array factory. */
  rowActions?: (row: T) => RowAction[];
  /** Rendered below the table/card list (use <Pagination>). */
  pagination?: React.ReactNode;
  /** Override the entire card for a row (phone only). */
  mobileCard?: (row: T) => React.ReactNode;
  /** Number of skeleton rows/cards to show while loading. Default 5. */
  skeletonCount?: number;
  /** Visible table caption, for tables that are not under a heading. */
  caption?: string;
}

// ── Action button helpers ─────────────────────────────────────────────────────

/** Row-action variants map to kit button kinds (danger is the outline kind in rows). */
const VARIANT_KIND: Record<string, string> = {
  primary: 'btn-primary',
  danger: 'btn-danger-outline',
  ghost: 'btn-ghost',
};

function actionClass(variant: RowAction['variant'], extra = '') {
  return `btn ${VARIANT_KIND[variant ?? 'ghost']} ${extra}`.trim();
}

function ActionButton({ action }: { action: RowAction }) {
  const cls = actionClass(action.variant, 'btn-sm');
  if (action.to) {
    return (
      <Link to={action.to} className={cls}>
        {action.label}
      </Link>
    );
  }
  return (
    <button type="button" className={cls} onClick={action.onClick} disabled={action.disabled}>
      {action.label}
    </button>
  );
}

// ── Sort icon ─────────────────────────────────────────────────────────────────

function SortIcon({ colKey, sortState }: { colKey: string; sortState?: SortState }) {
  if (!sortState || sortState.key !== colKey) return null;
  return sortState.desc
    ? <ChevronDown size={14} aria-hidden="true" />
    : <ChevronUp size={14} aria-hidden="true" />;
}

function ariaSort(colKey: string, sortState?: SortState): 'ascending' | 'descending' | undefined {
  if (!sortState || sortState.key !== colKey) return undefined;
  return sortState.desc ? 'descending' : 'ascending';
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function SkeletonRow({ colCount }: { colCount: number }) {
  return (
    <tr aria-hidden="true">
      {Array.from({ length: colCount }).map((_, i) => (
        <td key={i}>
          <span className="skeleton" />
        </td>
      ))}
    </tr>
  );
}

function SkeletonCard() {
  return (
    <li aria-hidden="true" className="card p-4 space-y-3">
      <div className="flex justify-between">
        <span className="skeleton w-40" />
        <span className="skeleton w-16" />
      </div>
      <div className="space-y-2">
        <span className="skeleton w-full" />
        <span className="skeleton w-3/4" />
      </div>
      <span className="skeleton" style={{ height: 'var(--sz-control)' }} />
    </li>
  );
}

// ── Card list (phone) ─────────────────────────────────────────────────────────

function closeMenu() {
  (document.activeElement as HTMLElement | null)?.closest('details')?.removeAttribute('open');
}

function CardList<T>({
  columns,
  rows,
  getRowKey,
  getRowClassName,
  onRowClick,
  rowActions,
  mobileCard,
  isLoading,
  empty,
  error,
  skeletonCount = 5,
}: Pick<
  DataTableProps<T>,
  'columns' | 'rows' | 'getRowKey' | 'getRowClassName' | 'onRowClick' | 'rowActions' | 'mobileCard' |
  'isLoading' | 'empty' | 'error' | 'skeletonCount'
>) {
  const primaryCol   = columns.find((c) => c.priority === 'primary');
  const secondaryCols = columns.filter((c) => c.priority === 'secondary');

  if (isLoading) {
    return (
      <ul className="space-y-3 list-none p-0 m-0" role="list" aria-busy="true">
        {Array.from({ length: skeletonCount }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </ul>
    );
  }

  if (error) {
    return <div className="card p-6 text-center text-sm c-soft">{error}</div>;
  }

  if (!rows || rows.length === 0) {
    return <div className="card p-6 text-center text-sm c-soft">{empty ?? 'No results.'}</div>;
  }

  return (
    <ul className="space-y-3 list-none p-0 m-0" role="list">
      {rows.map((row) => {
        const key = getRowKey(row);
        const rowClass = getRowClassName?.(row) ?? '';

        // Allow full override per row
        if (mobileCard) {
          return <li key={key} className={rowClass}>{mobileCard(row)}</li>;
        }

        const actions = rowActions?.(row) ?? [];
        const primaryAction    = actions.find((a) => a.primary) ?? actions[0];
        const secondaryActions = actions.filter((a) => a !== primaryAction);

        return (
          <li key={key} className={`card overflow-hidden ${rowClass}`}>
            {/* Card body */}
            <div
              className={`p-4 space-y-2 ${onRowClick ? 'cursor-pointer' : ''}`}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {/* Title row: primary value */}
              <div className="flex items-start justify-between gap-3">
                <div className="font-semibold min-w-0 flex-1">
                  {primaryCol ? primaryCol.cell(row) : null}
                </div>
              </div>

              {/* Secondary fields */}
              {secondaryCols.map((col) => (
                <div key={col.key} className="flex items-baseline justify-between gap-3 text-sm">
                  <span className="c-soft shrink-0">{col.header}</span>
                  <span className="text-right min-w-0 flex-1">{col.cell(row)}</span>
                </div>
              ))}
            </div>

            {/* Footer */}
            {actions.length > 0 && (
              <div className="flex items-center gap-2 px-4 py-3 border-t border-[var(--line)] bg-[var(--surface-alt)]">
                {actions.length <= 2 ? (
                  actions.map((a, i) => {
                    const cls = actionClass(a.variant, 'flex-1');
                    if (a.to) {
                      return (
                        <Link key={i} to={a.to} className={cls}>
                          {a.label}
                        </Link>
                      );
                    }
                    return (
                      <button
                        key={i}
                        type="button"
                        className={cls}
                        onClick={a.onClick}
                        disabled={a.disabled}
                      >
                        {a.label}
                      </button>
                    );
                  })
                ) : (
                  <>
                    <details className="relative">
                      <summary
                        className="btn btn-ghost btn-icon list-none cursor-pointer"
                        aria-label="More actions"
                      >
                        <MoreHorizontal size={18} aria-hidden="true" />
                      </summary>
                      <div className="absolute bottom-full left-0 mb-1 z-10 min-w-[160px] bg-[var(--surface)] border border-[var(--line)] rounded-[var(--r-control)] shadow-[var(--sh-pop)]">
                        {secondaryActions.map((a, i) => {
                          const cls = [
                            'w-full text-left px-4 py-3 text-sm font-semibold block min-h-[var(--sz-touch)]',
                            a.variant === 'danger'
                              ? 'text-[var(--danger)] hover:bg-[var(--danger-tint)]'
                              : 'text-[var(--ink)] hover:bg-[var(--surface-alt)]',
                          ].join(' ');
                          if (a.to) {
                            return (
                              <Link key={i} to={a.to} className={cls} onClick={closeMenu}>
                                {a.label}
                              </Link>
                            );
                          }
                          return (
                            <button
                              key={i}
                              type="button"
                              className={cls}
                              onClick={() => {
                                a.onClick?.();
                                closeMenu();
                              }}
                              disabled={a.disabled}
                            >
                              {a.label}
                            </button>
                          );
                        })}
                      </div>
                    </details>
                    <div className="flex-1">
                      {primaryAction && (
                        primaryAction.to ? (
                          <Link
                            to={primaryAction.to}
                            className={actionClass(primaryAction.variant ?? 'primary', 'btn-block')}
                          >
                            {primaryAction.label}
                          </Link>
                        ) : (
                          <button
                            type="button"
                            className={actionClass(primaryAction.variant ?? 'primary', 'btn-block')}
                            onClick={primaryAction.onClick}
                            disabled={primaryAction.disabled}
                          >
                            {primaryAction.label}
                          </button>
                        )
                      )}
                    </div>
                  </>
                )}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

// ── Main DataTable ────────────────────────────────────────────────────────────

export function DataTable<T>({
  columns,
  rows,
  getRowKey,
  getRowClassName,
  onRowClick,
  isLoading = false,
  empty,
  error,
  sortState,
  onSort,
  rowActions,
  pagination,
  mobileCard,
  skeletonCount = 5,
  caption,
}: DataTableProps<T>) {
  const { isPhone, isTabletPortrait } = useBreakpoint();

  // Phone → card list
  if (isPhone) {
    return (
      <div className="space-y-3">
        <CardList
          columns={columns}
          rows={rows}
          getRowKey={getRowKey}
          getRowClassName={getRowClassName}
          onRowClick={onRowClick}
          rowActions={rowActions}
          mobileCard={mobileCard}
          isLoading={isLoading}
          empty={empty}
          error={error}
          skeletonCount={skeletonCount}
        />
        {pagination}
      </div>
    );
  }

  // Tablet portrait → table with detail columns hidden
  // Desktop / tablet landscape → full table
  const hideDetail = isTabletPortrait;

  // Filter visible columns (never filter primary/secondary; detail hidden on tablet portrait)
  const visibleCols = columns.filter(
    (c) => c.priority !== 'detail' || !hideDetail,
  );
  const colCount = visibleCols.length + (rowActions ? 1 : 0);

  // Right-aligned columns use the kit's `.num` (right + tabular figures).
  const alignClass = (align?: string) =>
    align === 'right' ? 'num' : align === 'center' ? 'text-center' : '';

  return (
    <div className="table-wrap">
      <table className="table" aria-busy={isLoading || undefined}>
        {caption ? <caption>{caption}</caption> : null}
        <thead>
          <tr>
            {visibleCols.map((col) => {
              const sortable = !!(col.sortable && onSort);
              return (
                <th
                  key={col.key}
                  scope="col"
                  aria-sort={sortable ? ariaSort(col.key, sortState) : undefined}
                  className={[alignClass(col.align), col.width ?? ''].filter(Boolean).join(' ') || undefined}
                >
                  {sortable ? (
                    <button type="button" onClick={() => onSort!(col.key)}>
                      {col.header}
                      <SortIcon colKey={col.key} sortState={sortState} />
                    </button>
                  ) : (
                    col.header
                  )}
                </th>
              );
            })}
            {rowActions && (
              <th scope="col">
                <span className="sr-only">Actions</span>
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {isLoading ? (
            Array.from({ length: skeletonCount }).map((_, i) => (
              <SkeletonRow key={i} colCount={colCount} />
            ))
          ) : error ? (
            <tr>
              <td colSpan={colCount} className="text-center muted">
                {error}
              </td>
            </tr>
          ) : !rows || rows.length === 0 ? (
            <tr>
              <td colSpan={colCount} className="text-center muted">
                {empty ?? 'No results.'}
              </td>
            </tr>
          ) : (
            rows.map((row) => {
              const actions = rowActions?.(row) ?? [];
              const rowClass = getRowClassName?.(row) ?? '';
              return (
                <tr
                  key={getRowKey(row)}
                  className={`${rowClass} ${onRowClick ? 'cursor-pointer' : ''}`.trim() || undefined}
                  onClick={
                    onRowClick
                      ? (e) => {
                          if ((e.target as HTMLElement).closest('button, a, input, select, textarea')) return;
                          onRowClick(row);
                        }
                      : undefined
                  }
                >
                  {visibleCols.map((col) => (
                    <td
                      key={col.key}
                      className={[alignClass(col.align), col.width ?? ''].filter(Boolean).join(' ') || undefined}
                    >
                      {col.cell(row)}
                    </td>
                  ))}
                  {rowActions && (
                    <td className="actions">
                      {actions.map((a, i) => (
                        <ActionButton key={i} action={a} />
                      ))}
                    </td>
                  )}
                </tr>
              );
            })
          )}
        </tbody>
      </table>
      {pagination}
    </div>
  );
}
