import { useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchJobs, fetchJobDetail, type JobListParams } from '../../../services/adminApi';

/** Statuses that should not trigger continuous polling. */
const TERMINAL_STATUSES = new Set([
  'Completed',
  'Cancelled',
  'Expired',
  'Disputed',
]);

export const useJobList = (params: JobListParams) =>
  useQuery({
    queryKey: ['admin', 'jobs', params],
    queryFn: () => fetchJobs(params),
    staleTime: 30_000,
  });

export const useJobDetail = (id: number) =>
  useQuery({
    queryKey: ['admin', 'jobs', id],
    queryFn: () => fetchJobDetail(id),
    enabled: !!id,
    staleTime: 10_000,
    refetchOnWindowFocus: true,
    // Poll every 15 s while the job is in a non-terminal state; pause once
    // it's done/cancelled/expired/disputed so we don't hammer the server.
    refetchInterval: (query) => {
      const data = query.state.data;
      if (!data) return 15_000;
      return TERMINAL_STATUSES.has(data.status) ? false : 15_000;
    },
    // Don't poll while the browser tab is hidden.
    refetchIntervalInBackground: false,
  });

/** Re-export the query client accessor for convenience. */
export { useQueryClient };
