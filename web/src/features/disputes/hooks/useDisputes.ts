import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchDisputes,
  fetchDisputeDetail,
  resolveDispute,
  type ResolveDisputeRequest,
} from '../../../services/adminApi';

export const useDisputeList = (params: {
  disputeStatus?: string;
  page?: number;
  pageSize?: number;
}) =>
  useQuery({
    queryKey: ['admin', 'disputes', params],
    queryFn: () => fetchDisputes(params),
    staleTime: 30_000,
  });

export const useDisputeDetail = (jobId: number) =>
  useQuery({
    queryKey: ['admin', 'disputes', jobId],
    queryFn: () => fetchDisputeDetail(jobId),
    enabled: !!jobId,
  });

export const useResolveDispute = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ jobId, request }: { jobId: number; request: ResolveDisputeRequest }) =>
      resolveDispute(jobId, request),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'disputes'] });
      qc.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
};
