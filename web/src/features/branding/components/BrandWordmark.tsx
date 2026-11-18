import React from 'react';
import { FALLBACK_BRAND, useBrandConfig } from '../hooks/useBrandConfig';
import { splitBrandName } from '../splitBrandName';

/**
 * The dashboard wordmark (kit `.wordmark`: display face, brand colour, accent on
 * the last segment). Falls back to the baked-in brand so the sidebar never
 * renders an empty name while `GET /api/config/locale` is in flight or if the
 * admin's session blocks it.
 *
 * `className` adds kit modifiers such as `wordmark-lg` or `phone-only`. The kit
 * recolours the wordmark on dark surfaces (`.sidebar`, `.hero`, `.on-dark`).
 */
export const BrandWordmark: React.FC<{ className?: string }> = ({ className }) => {
  const { data } = useBrandConfig();
  const name = data?.brand?.appName || FALLBACK_BRAND.appName;
  const [lead, accent] = splitBrandName(name);

  return (
    <span className={['wordmark', className].filter(Boolean).join(' ')}>
      {lead}
      {accent && <span>{accent}</span>}
    </span>
  );
};
