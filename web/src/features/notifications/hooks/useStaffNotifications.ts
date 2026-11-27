import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchStaffNotifications,
  markAllStaffNotificationsRead,
  markStaffNotificationRead,
} from '../../../services/adminApi';

const NOTIFICATIONS_KEY = ['admin', 'notifications'] as const;

export const useStaffNotifications = (limit = 20) =>
  useQuery({
    queryKey: [...NOTIFICATIONS_KEY, { limit }],
    queryFn: () => fetchStaffNotifications({ limit }),
    refetchInterval: 30_000,
    refetchOnWindowFocus: true,
    staleTime: 15_000,
  });

export const useMarkNotificationRead = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => markStaffNotificationRead(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: NOTIFICATIONS_KEY });
    },
  });
};

export const useMarkAllNotificationsRead = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => markAllStaffNotificationsRead(),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: NOTIFICATIONS_KEY });
    },
  });
};
