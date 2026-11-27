import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  fetchQuoteSettings,
  updateQuoteSettings,
  type QuoteSettings,
} from '../../../services/adminApi';

const KEY = ['admin', 'settings', 'quotes'];

export const useQuoteSettings = () =>
  useQuery({ queryKey: KEY, queryFn: fetchQuoteSettings, staleTime: 60_000 });

export const useUpdateQuoteSettings = () => {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (dto: QuoteSettings) => updateQuoteSettings(dto),
    onSuccess: (updated) => {
      qc.setQueryData(KEY, updated);
    },
  });
};
