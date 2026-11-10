/**
 * useBreakpoint — SSR-safe, subscription-based breakpoint hook.
 *
 * Uses useSyncExternalStore + matchMedia so components always read a
 * consistent snapshot and re-render on the next frame after a resize
 * crosses a breakpoint boundary — no polling, no flicker.
 *
 * Tailwind v4 defaults: sm = 640px, lg = 1024px.
 * Tablet portrait is detected separately for DataTable column hiding.
 */
import { useSyncExternalStore } from 'react';

// ── matchMedia queries ────────────────────────────────────────────────────────

const QUERIES = {
  phone:         '(max-width: 639px)',
  tablet:        '(min-width: 640px) and (max-width: 1023px)',
  tabletPortrait:'(min-width: 640px) and (max-width: 1023px) and (orientation: portrait)',
  desktop:       '(min-width: 1024px)',
} as const;

type QueryKey = keyof typeof QUERIES;

// ── Per-query store (singleton per query string) ──────────────────────────────

function makeStore(query: string) {
  let mql: MediaQueryList | null = null;

  const getSnapshot = () => {
    if (typeof window === 'undefined') return false;
    if (!mql) mql = window.matchMedia(query);
    return mql.matches;
  };

  const getServerSnapshot = () => false;

  const subscribe = (callback: () => void) => {
    if (typeof window === 'undefined') return () => {};
    if (!mql) mql = window.matchMedia(query);
    mql.addEventListener('change', callback);
    return () => mql!.removeEventListener('change', callback);
  };

  return { getSnapshot, getServerSnapshot, subscribe };
}

const stores: Partial<Record<QueryKey, ReturnType<typeof makeStore>>> = {};

function getStore(key: QueryKey) {
  if (!stores[key]) stores[key] = makeStore(QUERIES[key]);
  return stores[key]!;
}

// ── Hook ─────────────────────────────────────────────────────────────────────

export interface Breakpoint {
  isPhone: boolean;
  isTablet: boolean;
  isTabletPortrait: boolean;
  isDesktop: boolean;
}

export function useBreakpoint(): Breakpoint {
  const phone   = useSyncExternalStore(
    getStore('phone').subscribe,
    getStore('phone').getSnapshot,
    getStore('phone').getServerSnapshot,
  );
  const tablet  = useSyncExternalStore(
    getStore('tablet').subscribe,
    getStore('tablet').getSnapshot,
    getStore('tablet').getServerSnapshot,
  );
  const tabletPortrait = useSyncExternalStore(
    getStore('tabletPortrait').subscribe,
    getStore('tabletPortrait').getSnapshot,
    getStore('tabletPortrait').getServerSnapshot,
  );
  const desktop = useSyncExternalStore(
    getStore('desktop').subscribe,
    getStore('desktop').getSnapshot,
    getStore('desktop').getServerSnapshot,
  );

  return { isPhone: phone, isTablet: tablet, isTabletPortrait: tabletPortrait, isDesktop: desktop };
}
