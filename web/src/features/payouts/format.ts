/** Payout amounts are NZD by contract (PayoutOptions.Currency), so the code is fixed. */
export const money = (amount: number) =>
  new Intl.NumberFormat('en-NZ', { style: 'currency', currency: 'NZD' }).format(amount);

/** Mirrors the payment queue's wording so both queues read the same way. */
export function createdAgo(iso?: string | null): string {
  if (!iso) return '—';
  const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

const dateOnly = (iso: string) =>
  new Date(iso).toLocaleDateString('en-NZ', { day: 'numeric', month: 'short' });

export const periodLabel = (start: string, end: string) =>
  `${dateOnly(start)} – ${dateOnly(end)}`;
