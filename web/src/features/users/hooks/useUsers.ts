import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchUsers,
  fetchUserDetail,
  verifyUser,
  deactivateUser,
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
