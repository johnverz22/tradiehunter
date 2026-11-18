/**
 * FilterBar — responsive filter container.
 *
 * Tablet/desktop: kit `.filterbar` (wrapping row, `role="search"`)
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
import React, { useState } from 'react';
import { Filter } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { Badge } from './Badge';
import { Button } from './Button';
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

  if (!isPhone) {
    // Kit `.filterbar`: wrapping row, search grows (max 360), selects and chips follow.
    return (
      <div className="filterbar" role="search">
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
      <div className="flex gap-2 items-center w-full" role="search">
        {/* Search input — always visible, takes remaining width */}
        <div className="flex-1 min-w-0">{searchChild}</div>

        {/* Filters button */}
        {hasOthers && (
          <Button
            kind="secondary"
            icon={<Filter size={18} />}
            onClick={() => setSheetOpen(true)}
            aria-expanded={sheetOpen}
            aria-haspopup="dialog"
            className="shrink-0"
          >
            Filters
            {activeFiltersCount > 0 && (
              <Badge tone="info">
                {activeFiltersCount}
                <span className="sr-only"> active filters</span>
              </Badge>
            )}
          </Button>
        )}
      </div>

      {/* Bottom sheet with other filters */}
      <Modal
        open={sheetOpen}
        onClose={() => setSheetOpen(false)}
        title="Filters"
        footer={
          <>
            {onClear && (
              <Button
                kind="secondary"
                onClick={() => {
                  onClear();
                  setSheetOpen(false);
                }}
              >
                Clear all
              </Button>
            )}
            <Button kind="accent" onClick={() => setSheetOpen(false)}>
              Apply
            </Button>
          </>
        }
      >
        {otherChildren.map((child, i) => (
          <div key={i} className="w-full">
            {child}
          </div>
        ))}
      </Modal>
    </>
  );
};
