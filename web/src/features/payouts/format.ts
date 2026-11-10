import { formatAge, formatMoney } from '../../utils/format';

/** Payout amounts are NZD by contract (PayoutOptions.Currency), so the code is fixed. */
export const money = (amount: number) => formatMoney(amount);

/** Mirrors the payment queue's wording so both queues read the same way. */
export const createdAgo = (iso?: string | null): string => formatAge(iso);

const dateOnly = (iso: string) =>
  new Date(iso).toLocaleDateString('en-NZ', {
    day: 'numeric',
    month: 'short',
    timeZone: 'Pacific/Auckland',
  });

export const periodLabel = (start: string, end: string) =>
  `${dateOnly(start)} – ${dateOnly(end)}`;
