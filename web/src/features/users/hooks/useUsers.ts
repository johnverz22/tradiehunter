import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchUsers,
  fetchUserDetail,
  verifyUser,
  deactivateUser,
  warnUser,
  suspendUser,
  resolveUserFlags,
  type UserListParams,
} from '../../../services/adminApi';

export const useUserList = (params: UserListParams) =>
  useQuery({
    queryKey: ['admin', 'users', params],
    queryFn: () => fetchUsers(params),
    staleTime: 30_000,
  });

export const useUserDetail = (id: string) =>
  useQuery({
    queryKey: ['admin', 'users', id],
    queryFn: () => fetchUserDetail(id),
    enabled: !!id,
    // Don't hammer the API on 404 — the id is simply invalid.
    retry: (failureCount, error: unknown) => {
      if (
        typeof error === 'object' &&
        error !== null &&
        'response' in error &&
        typeof (error as { response?: { status?: number } }).response?.status === 'number' &&
        (error as { response: { status: number } }).response.status === 404
      ) {
        return false;
      }
      return failureCount < 2;
    },
  });

export const useVerifyUser = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => verifyUser(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
};

export const useDeactivateUser = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => deactivateUser(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
};


export const useWarnUser = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => warnUser(id, reason),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
};

export const useSuspendUser = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => suspendUser(id, reason),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
};

export const useResolveUserFlags = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => resolveUserFlags(id),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin', 'users'] }),
  });
};
