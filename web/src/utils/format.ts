/**
 * Shared admin formatting. NZ product: en-NZ, Pacific/Auckland, NZD.
 * Dates render as `09 Nov 2026` so 11/9 can never be read as 11 September.
 * Locale values mirror the backend `Locale` config defaults.
 */
const LOCALE = 'en-NZ';
const TIME_ZONE = 'Pacific/Auckland';
const CURRENCY = 'NZD';

const dateFmt = new Intl.DateTimeFormat(LOCALE, {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  timeZone: TIME_ZONE,
});

const dateTimeFmt = new Intl.DateTimeFormat(LOCALE, {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
  timeZone: TIME_ZONE,
});

const moneyFmt = new Intl.NumberFormat(LOCALE, { style: 'currency', currency: CURRENCY });

const parse = (iso?: string | null): Date | null => {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
};

export const formatDate = (iso?: string | null): string => {
  const d = parse(iso);
  return d ? dateFmt.format(d) : '—';
};

export const formatDateTime = (iso?: string | null): string => {
  const d = parse(iso);
  return d ? dateTimeFmt.format(d) : '—';
};

export const formatMoney = (amount?: number | null): string =>
  amount == null || Number.isNaN(amount) ? '—' : moneyFmt.format(amount);

/**
 * Compact age: `just now`, `5m ago`, `3h ago`, `2d ago`; beyond two weeks the
 * absolute date is clearer than a large day count. Future/invalid → `—`.
 */
export function formatAge(iso?: string | null, now: number = Date.now()): string {
  const d = parse(iso);
  if (!d) return '—';
  const mins = Math.floor((now - d.getTime()) / 60_000);
  if (mins < 0) return '—';
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return days <= 14 ? `${days}d ago` : formatDate(iso);
}

/** Average-hours metric; `—` when the API had no data rather than a fake `0.0h`. */
export const formatHours = (hours?: number | null): string =>
  hours == null || Number.isNaN(hours) || hours <= 0 ? '—' : `${hours.toFixed(1)}h`;
