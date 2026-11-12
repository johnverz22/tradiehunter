import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchPendingRefunds,
  processRefund,
  type PagedResult,
  type ProcessRefundBody,
  type RefundQueueParams,
  type RefundSummary,
} from '../../../services/adminApi';

const QUEUE_KEY = ['admin', 'refunds', 'pending'] as const;

export const useRefundQueue = (params: RefundQueueParams) =>
  useQuery({
    queryKey: [...QUEUE_KEY, params],
    queryFn: () => fetchPendingRefunds(params),
    staleTime: 30_000,
  });

export const useProcessRefund = () => {
  const qc = useQueryClient();

  return useMutation({
    mutationFn: ({ id, body }: { id: string; body: ProcessRefundBody }) =>
      processRefund(id, body),
    onSuccess: (_result, { id }) => {
      // Remove the processed refund from every cached queue page immediately,
      // then re-sync from the server.
      qc.setQueriesData<PagedResult<RefundSummary>>({ queryKey: QUEUE_KEY }, (page) =>
        page
          ? {
              ...page,
              items: page.items.filter((r) => r.id !== id),
              totalCount: Math.max(0, page.totalCount - 1),
            }
          : page,
      );
      qc.invalidateQueries({ queryKey: QUEUE_KEY });
      // Refresh any open job detail pages so their stepper reflects the payment status.
      qc.invalidateQueries({ queryKey: ['admin', 'jobs'] });
    },
  });
};
