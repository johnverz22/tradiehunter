import { useQuery } from '@tanstack/react-query';
import { fetchAuditLogs, type AuditLogParams } from '../../../services/adminApi';

export const useAuditLogs = (params: AuditLogParams) =>
  useQuery({
    queryKey: ['admin', 'audit-logs', params],
    queryFn: () => fetchAuditLogs(params),
    staleTime: 30_000,
  });
