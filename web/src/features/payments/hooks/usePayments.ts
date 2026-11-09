import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchPendingPayments,
  rejectPayment,
  verifyPayment,
  type PagedResult,
  type PaymentQueueParams,
  type PendingPayment,
  type RejectPaymentBody,
} from '../../../services/adminApi';

/** Prefix shared by every cached page of the queue — used for partial-key updates. */
const QUEUE_KEY = ['admin', 'payments', 'pending'] as const;

export const usePaymentQueue = (params: PaymentQueueParams) =>
  useQuery({
    queryKey: [...QUEUE_KEY, params],
    queryFn: () => fetchPendingPayments(params),
    staleTime: 30_000,
  });

/**
 * Both review actions end the same way — the receipt leaves the queue — so they
 * share the cache handling. A verified payment books the job, and a rejected one
 * sends it back to AwaitingPayment, so the job list is stale either way.
 */
export const usePaymentReview = () => {
  const qc = useQueryClient();

  const settle = (id: number) => {
    // Drop the row from every cached page first (instant feedback), then resync
    // with the server so paging and counts stay authoritative.
    qc.setQueriesData<PagedResult<PendingPayment>>({ queryKey: QUEUE_KEY }, (page) =>
      page
        ? {
            ...page,
            items: page.items.filter((p) => p.id !== id),
            totalCount: Math.max(0, page.totalCount - 1),
          }
        : page,
    );
    qc.invalidateQueries({ queryKey: QUEUE_KEY });
    qc.invalidateQueries({ queryKey: ['admin', 'jobs'] });
  };

  return {
    verify: useMutation({ mutationFn: (id: number) => verifyPayment(id), onSuccess: (_r, id) => settle(id) }),
    reject: useMutation({
      mutationFn: ({ id, reason }: { id: number; reason: RejectPaymentBody }) => rejectPayment(id, reason),
      onSuccess: (_r, { id }) => settle(id),
    }),
  };
};
