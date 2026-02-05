'use client';

/**
 * Theme Toggle Component
 * A button to switch between light and dark themes
 */
import React from 'react';
import { useTheme } from '@/contexts/ThemeContext';
import './ThemeToggle.css';

/**
 * ThemeToggle button component
 * Displays sun icon for dark mode, moon icon for light mode
 */
export function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();

  return (
    <button 
      className="theme-toggle"
      onClick={toggleTheme}
      aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
      title={theme === 'dark' ? 'Switch to light mode / ਲਾਈਟ ਮੋਡ' : 'Switch to dark mode / ਡਾਰਕ ਮੋਡ'}
    >
      {theme === 'dark' ? (
        // Sun icon for switching TO light mode
        <span className="theme-icon">☀️</span>
      ) : (
        // Moon icon for switching TO dark mode
        <span className="theme-icon">🌙</span>
      )}
    </button>
  );
}

export default ThemeToggle;
