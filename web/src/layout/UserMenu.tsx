/**
 * UserMenu — who is signed in (sidebar / drawer footer).
 *
 * An identity row (avatar with initials, name, "Administrator") drawn with the
 * kit `.nav-item` so it sits on the dark sidebar. Rendered inside a
 * `.sidebar-foot` supplied by the parent. Logout lives in the top bar.
 */
import React from 'react';

interface UserMenuProps {
  adminName: string;
}

/** Up to two initials for the avatar ("Sam Harris" → "SH"). */
function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const letters =
    parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] ?? '').slice(0, 1);
  return (letters || 'A').toUpperCase();
}

export const UserMenu: React.FC<UserMenuProps> = ({ adminName }) => (
  <div className="nav-item nav-item-static">
    <span className="avatar avatar-sm" aria-hidden="true">{initials(adminName)}</span>
    <span className="nav-label" title={adminName}>
      {adminName}
      <small>Administrator</small>
    </span>
  </div>
);
