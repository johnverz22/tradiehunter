import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchOverduePayments,
  fetchPendingPayments,
  rejectPayment,
  verifyPayment,
  type OverduePaymentsParams,
  type PagedResult,
  type PaymentQueueParams,
  type PendingPayment,
  type RejectPaymentBody,
} from '../../../services/adminApi';

/** Prefix shared by every cached page of the queue — used for partial-key updates. */
const QUEUE_KEY = ['admin', 'payments', 'pending'] as const;

/** Cached pages of the overdue view (v1.7) — jobs awaiting payment past their due date. */
const OVERDUE_KEY = ['admin', 'payments', 'overdue'] as const;

export const usePaymentQueue = (params: PaymentQueueParams) =>
  useQuery({
    queryKey: [...QUEUE_KEY, params],
    queryFn: () => fetchPendingPayments(params),
    staleTime: 30_000,
  });

export const useOverduePayments = (params: OverduePaymentsParams) =>
  useQuery({
    queryKey: [...OVERDUE_KEY, params],
    queryFn: () => fetchOverduePayments(params),
    staleTime: 30_000,
  });

/**
 * Both review actions end the same way — the receipt leaves the queue — so they
 * share the cache handling. A verified payment completes the job and queues the
 * tradie's payout (v1.7), and a rejected one sends it back to AwaitingPayment,
 * so the job list and the overdue view are stale either way.
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
    // Verify completes the job (leaves the overdue list); reject can push a job
    // further past its due date — either way the overdue view is stale.
    qc.invalidateQueries({ queryKey: OVERDUE_KEY });
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
