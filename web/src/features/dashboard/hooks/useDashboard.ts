import { useQuery } from '@tanstack/react-query';
import { fetchStats, fetchMetrics } from '../../../services/adminApi';

export const useDashboardStats = () =>
  useQuery({
    queryKey: ['admin', 'stats'],
    queryFn: fetchStats,
    refetchInterval: 60_000, // auto-refresh every 60s
    staleTime: 30_000,
  });

export const useDashboardMetrics = () =>
  useQuery({
    queryKey: ['admin', 'metrics'],
    queryFn: fetchMetrics,
    staleTime: 60_000,
  });
