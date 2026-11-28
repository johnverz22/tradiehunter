import React from 'react';
import { FALLBACK_BRAND, useBrandConfig } from '../hooks/useBrandConfig';

/**
 * Decorative TradieHunter house-and-hammer emblem (`kit.css` `.brand-mark`).
 * Automatically hidden when white-labelled to a different `appName`.
 */
export const BrandMark: React.FC<{ size?: number; className?: string }> = ({
  size = 28,
  className,
}) => {
  const { data } = useBrandConfig();
  const appName = data?.brand?.appName || FALLBACK_BRAND.appName;
  if (appName !== 'TradieHunter') return null;

  return (
    <span className={['brand-mark', className].filter(Boolean).join(' ')} aria-hidden="true">
      <img className="brand-mark-light" src="/brand/logo.svg" width={size} height={size} alt="" />
      <img className="brand-mark-dark" src="/brand/logo-white.svg" width={size} height={size} alt="" />
    </span>
  );
};
