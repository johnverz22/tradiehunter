import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchSettings, updateSettings, type AdminSettings } from '../../../services/adminApi';

export const useSettings = () =>
  useQuery({
    queryKey: ['admin', 'settings'],
    queryFn: fetchSettings,
    staleTime: 60_000,
  });

export const useUpdateSettings = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (dto: AdminSettings) => updateSettings(dto),
    onSuccess: (updated) => {
      qc.setQueryData(['admin', 'settings'], updated);
    },
  });
};
