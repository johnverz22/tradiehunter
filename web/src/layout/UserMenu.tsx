/**
 * UserMenu — avatar + name + logout button.
 * Shared between the desktop sidebar footer and the mobile drawer footer.
 */
import React from 'react';
import { LogOut, UserRound } from 'lucide-react';

interface UserMenuProps {
  adminName: string;
  onLogout: () => void;
  /** 'dark' (sidebar/drawer) or 'light' (topbar). */
  variant?: 'dark' | 'light';
}

export const UserMenu: React.FC<UserMenuProps> = ({
  adminName,
  onLogout,
  variant = 'dark',
}) => {
  const isDark = variant === 'dark';
  return (
    <div className={`flex items-center gap-3 px-1 ${isDark ? '' : ''}`}>
      <span
        className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${
          isDark ? 'bg-white/15' : 'bg-[var(--brand-100)]'
        }`}
        aria-hidden="true"
      >
        <UserRound
          size={16}
          className={isDark ? 'text-white' : 'text-[var(--brand-700)]'}
        />
      </span>
      <span className="min-w-0 flex-1">
        <span
          className={`block text-[13px] font-medium truncate ${isDark ? 'text-white' : 'text-[var(--ink)]'}`}
          title={adminName}
        >
          {adminName}
        </span>
        <span className={`block text-[11px] ${isDark ? 'text-white/60' : 'text-[var(--ink-soft)]'}`}>
          Administrator
        </span>
      </span>
      <button
        onClick={onLogout}
        title="Logout"
        aria-label="Logout"
        className={`p-2 rounded transition-colors shrink-0 min-h-[44px] min-w-[44px] flex items-center justify-center ${
          isDark
            ? 'text-white/70 hover:text-white hover:bg-white/10'
            : 'text-[var(--ink-soft)] hover:text-[var(--ink)] hover:bg-[var(--paper)]'
        }`}
      >
        <LogOut size={15} aria-hidden="true" />
      </button>
    </div>
  );
};
