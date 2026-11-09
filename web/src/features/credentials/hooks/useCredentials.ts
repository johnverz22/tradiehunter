import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchPendingCredentials,
  reviewCredential,
  type CredentialQueueParams,
  type PagedResult,
  type PendingCredential,
  type ReviewCredentialRequest,
} from '../../../services/adminApi';

/** Prefix shared by every cached page of the queue — used for partial-key updates. */
const QUEUE_KEY = ['admin', 'credentials', 'pending'] as const;

export const useCredentialQueue = (params: CredentialQueueParams) =>
  useQuery({
    queryKey: [...QUEUE_KEY, params],
    queryFn: () => fetchPendingCredentials(params),
    staleTime: 30_000,
  });

export const useReviewCredential = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, request }: { id: number; request: ReviewCredentialRequest }) =>
      reviewCredential(id, request),
    onSuccess: (_reviewed, { id }) => {
      // A reviewed credential is no longer Pending, so it leaves the queue.
      // Drop the row from every cached page first (instant feedback), then
      // resync with the server so paging and counts stay authoritative.
      qc.setQueriesData<PagedResult<PendingCredential>>({ queryKey: QUEUE_KEY }, (page) =>
        page
          ? {
              ...page,
              items: page.items.filter((c) => c.id !== id),
              totalCount: Math.max(0, page.totalCount - 1),
            }
          : page,
      );
      qc.invalidateQueries({ queryKey: QUEUE_KEY });
      // Approving/rejecting can flip `isVerified` on the tradie's user record.
      qc.invalidateQueries({ queryKey: ['admin', 'users'] });
    },
  });
};
