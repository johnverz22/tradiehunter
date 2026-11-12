import React from 'react';
import { Moon, Sun } from 'lucide-react';

interface ThemeToggleProps {
  theme: 'light' | 'dark';
  onToggle: () => void;
  className?: string;
}

/**
 * Light/dark theme switcher used in the content area (desktop top-right)
 * and in the mobile/tablet TopBar.
 */
export const ThemeToggle: React.FC<ThemeToggleProps> = ({
  theme,
  onToggle,
  className = '',
}) => (
  <button
    type="button"
    onClick={onToggle}
    title={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
    aria-label={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
    className={[
      'h-8 w-8 rounded-full border border-[var(--paper-line)] bg-[var(--paper)]',
      'text-[var(--ink-soft)] hover:text-[var(--ink)] transition-colors',
      'flex items-center justify-center shadow-xs',
      className,
    ].join(' ')}
  >
    {theme === 'light' ? (
      <Moon size={14} aria-hidden="true" />
    ) : (
      <Sun size={14} aria-hidden="true" />
    )}
  </button>
);
