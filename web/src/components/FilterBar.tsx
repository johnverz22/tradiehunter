/**
 * FilterBar — responsive filter container.
 *
 * Desktop:  flex row (unchanged from current inline layout)
 * Tablet:   wrapping 2-column grid; search spans full width
 * Phone:    search always visible + "Filters" button that opens a
 *           bottom sheet (via Modal) with all other filters stacked;
 *           Apply closes the sheet, Clear resets the badge count.
 *
 * Usage:
 *   <FilterBar activeFiltersCount={activeCount} onClear={handleClear}>
 *     <SearchInput ... />
 *     <SelectField ... />
 *     <CheckboxField ... />
 *   </FilterBar>
 *
 * The first child is treated as the "search" on phone (always shown).
 * All other children go into the bottom sheet.
 */
import React, { useId, useState } from 'react';
import { Filter } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { Modal } from './Modal';

interface FilterBarProps {
  children: React.ReactNode;
  /** Number of non-search filters that are active — drives the badge. */
  activeFiltersCount?: number;
  /** Called when user taps "Clear" in the sheet footer. */
  onClear?: () => void;
}

export const FilterBar: React.FC<FilterBarProps> = ({
  children,
  activeFiltersCount = 0,
  onClear,
}) => {
  const { isPhone } = useBreakpoint();
  const [sheetOpen, setSheetOpen] = useState(false);
  const btnId = useId();

  if (!isPhone) {
    // Tablet: wrapping 2-column grid; Desktop: flex row
    return (
      <div className="flex flex-wrap items-center gap-3 sm:grid sm:grid-cols-2 lg:flex">
        {children}
      </div>
    );
  }

  // Phone: split children into search (first) and rest
  const childArray = React.Children.toArray(children);
  const searchChild = childArray[0];
  const otherChildren = childArray.slice(1);
  const hasOthers = otherChildren.length > 0;

  return (
    <>
      <div className="flex gap-2 items-center w-full">
        {/* Search input — always visible, takes remaining width */}
        <div className="flex-1 min-w-0">{searchChild}</div>

        {/* Filters button */}
        {hasOthers && (
          <button
            id={btnId}
            onClick={() => setSheetOpen(true)}
            aria-expanded={sheetOpen}
            aria-haspopup="dialog"
            className="btn btn-ghost shrink-0 relative min-h-[44px] !px-3"
          >
            <Filter size={16} aria-hidden="true" />
            <span className="sr-only">Filters</span>
            <span aria-hidden="true" className="text-sm">Filters</span>
            {activeFiltersCount > 0 && (
              <span
                className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-[var(--brand-700)] text-white text-[10px] font-bold flex items-center justify-center"
                aria-label={`${activeFiltersCount} active filters`}
              >
                {activeFiltersCount}
              </span>
            )}
          </button>
        )}
      </div>

      {/* Bottom sheet with other filters */}
      <Modal
        open={sheetOpen}
        onClose={() => setSheetOpen(false)}
        title="Filters"
        footer={
          <div className="flex gap-2">
            {onClear && (
              <button
                className="btn btn-ghost flex-1"
                onClick={() => { onClear(); setSheetOpen(false); }}
              >
                Clear all
              </button>
            )}
            <button
              className="btn btn-primary flex-1"
              onClick={() => setSheetOpen(false)}
            >
              Apply
            </button>
          </div>
        }
      >
        <div className="space-y-4">
          {otherChildren.map((child, i) => (
            <div key={i} className="w-full">{child}</div>
          ))}
        </div>
      </Modal>
    </>
  );
};
