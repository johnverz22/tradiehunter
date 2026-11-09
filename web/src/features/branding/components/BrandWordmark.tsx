import React from 'react';
import { FALLBACK_BRAND, useBrandConfig } from '../hooks/useBrandConfig';
import { splitBrandName } from '../splitBrandName';

/**
 * The dashboard wordmark. Falls back to the baked-in brand so the sidebar never
 * renders an empty name while `GET /api/config/locale` is in flight or if the
 * admin's session blocks it.
 */
export const BrandWordmark: React.FC<{ className?: string }> = ({ className }) => {
  const { data } = useBrandConfig();
  const name = data?.brand?.appName || FALLBACK_BRAND.appName;
  const [lead, accent] = splitBrandName(name);

  return (
    <span className={className} style={{ fontFamily: 'var(--font-display)' }}>
      {lead}
      {accent && <span className="text-[var(--amber)]">{accent}</span>}
    </span>
  );
};
