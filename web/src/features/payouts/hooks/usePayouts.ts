import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  completePayoutBatch,
  fetchPayoutBatch,
  fetchPayoutBatches,
  fetchPendingPayouts,
  processPayout,
  type PagedResult,
  type PayoutBatchDetail,
  type PayoutBatchSummary,
  type PayoutQueueItem,
  type PayoutQueueParams,
} from '../../../services/adminApi';

/** Prefix shared by every cached page of the queue — used for partial-key updates. */
const QUEUE_KEY = ['admin', 'payouts', 'pending'] as const;
const BATCHES_KEY = ['admin', 'payouts', 'batches'] as const;

export const usePayoutQueue = (params: PayoutQueueParams) =>
  useQuery({
    queryKey: [...QUEUE_KEY, params],
    queryFn: () => fetchPendingPayouts(params),
    staleTime: 30_000,
  });

export const usePayoutBatches = (params: PayoutQueueParams) =>
  useQuery({
    queryKey: [...BATCHES_KEY, params],
    queryFn: () => fetchPayoutBatches(params),
    staleTime: 30_000,
  });

export const usePayoutBatch = (id: string) =>
  useQuery({
    queryKey: [...BATCHES_KEY, id],
    queryFn: () => fetchPayoutBatch(id),
    enabled: Boolean(id),
    staleTime: 30_000,
  });

/**
 * Marking a payout Processed takes it out of the queue, so the row is dropped
 * from every cached page first (instant feedback) and then the server is
 * re-consulted so paging and counts stay authoritative. The payout's batch gains
 * a processed row, so the batch views are stale too.
 */
export const useProcessPayout = () => {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: ({ id, transferReference }: { id: string; transferReference: string }) =>
      processPayout(id, transferReference),
    onSuccess: (_r, { id }) => {
      qc.setQueriesData<PagedResult<PayoutQueueItem>>({ queryKey: QUEUE_KEY }, (page) =>
        page
          ? {
              ...page,
              items: page.items.filter((p) => p.id !== id),
              totalCount: Math.max(0, page.totalCount - 1),
            }
          : page,
      );
      qc.invalidateQueries({ queryKey: QUEUE_KEY });
      qc.invalidateQueries({ queryKey: BATCHES_KEY });
    },
  });
};

export const useCompletePayoutBatch = () => {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => completePayoutBatch(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: BATCHES_KEY });
    },
  });
};

/**
 * Oldest-first, matching the payment queue. Backend pages by creation date, but
 * a page boundary can leave a newer row above an older one when a payout is
 * processed mid-scroll, so the page is re-sorted here.
 */
export const sortOldestFirst = <T extends { createdAtUtc: string }>(items: T[]): T[] =>
  [...items].sort((a, b) => Date.parse(a.createdAtUtc) - Date.parse(b.createdAtUtc));

export type { PayoutBatchDetail, PayoutBatchSummary };
