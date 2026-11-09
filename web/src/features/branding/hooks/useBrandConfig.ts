import { useQuery } from '@tanstack/react-query';
import { fetchAppConfig, type BrandConfig } from '../../../services/adminApi';

/**
 * Used until (or unless) `GET /api/config/locale` answers. The login screen
 * renders this before any session exists, so it can never rely on the query
 * alone.
 */
export const FALLBACK_BRAND: BrandConfig = {
  appName: 'TradieFixo',
  supportEmail: 'support@tradiefixo.nz',
  supportHoursDisplay: '8am – 6pm NZT, Mon–Fri',
};

const BRAND_KEY = ['config', 'app'] as const;

/**
 * White-label branding comes from the backend's `Brand` config section, so a
 * partner rebrand is a server-side config change rather than a rebuild of this
 * dashboard. Long staleTime: the brand name is fixed for the life of a session.
 */
export const useBrandConfig = () =>
  useQuery({
    queryKey: BRAND_KEY,
    queryFn: fetchAppConfig,
    staleTime: 60 * 60 * 1000,
    gcTime: 60 * 60 * 1000,
    retry: 1,
    // The config endpoint is public; a cold cache on the login screen should not
    // hold up the wordmark.
    refetchOnWindowFocus: false,
  });

/** Brand name with a safe fallback, for render paths that must not be blank. */
export const useAppName = () => {
  const { data } = useBrandConfig();
  return data?.brand?.appName || FALLBACK_BRAND.appName;
};
