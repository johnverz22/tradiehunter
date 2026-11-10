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
}

// ── Action button helpers ─────────────────────────────────────────────────────

const VARIANT_CLASS: Record<string, string> = {
  primary: 'btn btn-primary',
  danger:  'btn btn-danger',
  ghost:   'btn btn-ghost',
};

function ActionButton({ action }: { action: RowAction }) {
  const cls = `${VARIANT_CLASS[action.variant ?? 'ghost']} !py-1 !px-2.5 !text-xs min-h-[44px] sm:min-h-0 inline-flex items-center justify-center`;
  if (action.to) {
    return (
      <Link to={action.to} className={cls}>
        {action.label}
      </Link>
    );
  }
  return (
    <button
      className={cls}
      onClick={action.onClick}
      disabled={action.disabled}
    >
      {action.label}
    </button>
  );
}

// ── Sort icon ─────────────────────────────────────────────────────────────────

function SortIcon({ colKey, sortState }: { colKey: string; sortState?: SortState }) {
  if (!sortState || sortState.key !== colKey) return null;
  return sortState.desc
    ? <ChevronDown size={13} className="inline ml-1" aria-hidden="true" />
    : <ChevronUp   size={13} className="inline ml-1" aria-hidden="true" />;
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function SkeletonRow({ colCount }: { colCount: number }) {
  return (
    <tr aria-hidden="true">
      {Array.from({ length: colCount }).map((_, i) => (
        <td key={i} className="td">
          <div className="h-4 bg-[var(--paper-line)] rounded animate-pulse" />
        </td>
      ))}
    </tr>
  );
}

function SkeletonCard() {
  return (
    <li aria-hidden="true" className="surface p-4 space-y-3">
      <div className="flex justify-between">
        <div className="h-4 w-40 bg-[var(--paper-line)] rounded animate-pulse" />
        <div className="h-5 w-16 bg-[var(--paper-line)] rounded-full animate-pulse" />
      </div>
      <div className="space-y-2">
        <div className="h-3 w-full bg-[var(--paper-line)] rounded animate-pulse" />
        <div className="h-3 w-3/4 bg-[var(--paper-line)] rounded animate-pulse" />
      </div>
      <div className="h-10 bg-[var(--paper-line)] rounded animate-pulse" />
    </li>
  );
}

// ── Card list (phone) ─────────────────────────────────────────────────────────

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
      <ul className="space-y-3 list-none p-0 m-0" role="list">
        {Array.from({ length: skeletonCount }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </ul>
    );
  }

  if (error) {
    return <div className="surface p-6 text-center text-sm text-[var(--ink-soft)]">{error}</div>;
  }

  if (!rows || rows.length === 0) {
    return <div className="surface p-6 text-center text-sm text-[var(--ink-soft)]">{empty ?? 'No results.'}</div>;
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
          <li
            key={key}
            className={`surface overflow-hidden ${rowClass}`}
            role="row"
          >
            {/* Card body */}
            <div
              className={`p-4 space-y-2 ${onRowClick ? 'cursor-pointer hover:bg-[var(--paper)] transition-colors' : ''}`}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {/* Title row: primary value */}
              <div className="flex items-start justify-between gap-3">
                <div className="font-medium text-[var(--ink)] min-w-0 flex-1">
                  {primaryCol ? primaryCol.cell(row) : null}
                </div>
              </div>

              {/* Secondary fields */}
              {secondaryCols.map((col) => (
                <div key={col.key} className="flex items-baseline justify-between gap-3 text-sm">
                  <span className="text-[var(--ink-soft)] shrink-0">{col.header}</span>
                  <span className="text-[var(--ink)] text-right min-w-0 flex-1">{col.cell(row)}</span>
                </div>
              ))}
            </div>

            {/* Footer */}
            {actions.length > 0 && (
              <div className="flex items-center gap-2 px-4 py-3 border-t border-[var(--paper-line)] bg-[var(--paper)]">
                {actions.length <= 2 ? (
                  actions.map((a, i) => {
                    const cls = `${VARIANT_CLASS[a.variant ?? 'ghost']} flex-1 justify-center min-h-[44px] inline-flex items-center`;
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
                        className="btn btn-ghost !py-1 !px-2 min-h-[44px] list-none cursor-pointer flex items-center justify-center"
                        aria-label="More actions"
                      >
                        <MoreHorizontal size={16} aria-hidden="true" />
                      </summary>
                      <div className="absolute bottom-full left-0 mb-1 z-10 surface shadow-[var(--shadow-pop)] rounded min-w-[160px]">
                        {secondaryActions.map((a, i) => {
                          const cls = [
                            'w-full text-left px-4 py-3 text-sm font-medium min-h-[44px] block',
                            a.variant === 'danger'
                              ? 'text-[var(--red)] hover:bg-red-50 dark:hover:bg-red-900/20'
                              : 'text-[var(--ink)] hover:bg-[var(--paper)]',
                          ].join(' ');
                          if (a.to) {
                            return (
                              <Link
                                key={i}
                                to={a.to}
                                className={cls}
                                onClick={() => {
                                  (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
                                }}
                              >
                                {a.label}
                              </Link>
                            );
                          }
                          return (
                            <button
                              key={i}
                              className={cls}
                              onClick={() => {
                                a.onClick?.();
                                (document.activeElement as HTMLElement)?.closest('details')?.removeAttribute('open');
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
                            className={`${VARIANT_CLASS[primaryAction.variant ?? 'primary']} w-full justify-center min-h-[44px] inline-flex items-center`}
                          >
                            {primaryAction.label}
                          </Link>
                        ) : (
                          <button
                            className={`${VARIANT_CLASS[primaryAction.variant ?? 'primary']} w-full justify-center min-h-[44px]`}
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

  const alignClass = (align?: string) =>
    align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : '';

  return (
    <div className="table-container">
      <div className="overflow-x-auto">
        <table className="table">
          <thead>
            <tr>
              {visibleCols.map((col) => (
                <th
                  key={col.key}
                  className={[
                    'th',
                    col.sortable && onSort ? 'th-sortable' : '',
                    alignClass(col.align),
                    col.width ?? '',
                  ].join(' ')}
                  onClick={col.sortable && onSort ? () => onSort(col.key) : undefined}
                >
                  {col.header}
                  {col.sortable && (
                    <SortIcon colKey={col.key} sortState={sortState} />
                  )}
                </th>
              ))}
              {rowActions && <th className="th" />}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              Array.from({ length: skeletonCount }).map((_, i) => (
                <SkeletonRow key={i} colCount={colCount} />
              ))
            ) : error ? (
              <tr>
                <td colSpan={colCount} className="td text-center cell-muted">
                  {error}
                </td>
              </tr>
            ) : !rows || rows.length === 0 ? (
              <tr>
                <td colSpan={colCount} className="td text-center cell-muted">
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
                    className={`${rowClass} ${onRowClick ? 'cursor-pointer' : ''}`}
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
                        className={`td ${alignClass(col.align)} ${col.width ?? ''}`}
                      >
                        {col.cell(row)}
                      </td>
                    ))}
                    {rowActions && (
                      <td className="td">
                        <div className="flex items-center justify-end gap-2">
                          {actions.map((a, i) => (
                            <ActionButton key={i} action={a} />
                          ))}
                        </div>
                      </td>
                    )}
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
      {pagination}
    </div>
  );
}
