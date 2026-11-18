import React from 'react';
import { Moon, Sun } from 'lucide-react';
import { IconButton } from './Button';

interface ThemeToggleProps {
  theme: 'light' | 'dark';
  onToggle: () => void;
  className?: string;
}

/**
 * Light/dark theme switcher used in the content area (desktop top-right)
 * and in the mobile/tablet TopBar.
 *
 * Renders the kit ghost icon button (COMPONENTS.md "Top bar": the theme
 * button has a label). The label names the action for the current state, and
 * the icon shows the theme it switches to.
 */
export const ThemeToggle: React.FC<ThemeToggleProps> = ({
  theme,
  onToggle,
  className,
}) => {
  const label = theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode';
  return (
    <IconButton
      kind="ghost"
      label={label}
      title={label}
      onClick={onToggle}
      className={className}
    >
      {theme === 'light' ? <Moon size={20} /> : <Sun size={20} />}
    </IconButton>
  );
};
