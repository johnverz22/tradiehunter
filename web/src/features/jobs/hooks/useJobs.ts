import { useQuery } from '@tanstack/react-query';
import { fetchJobs, fetchJobDetail, type JobListParams } from '../../../services/adminApi';

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
  });
