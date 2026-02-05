'use client';

/**
 * Theme Context
 * Provides theme state (light/dark) throughout the app with persistence
 */
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

// Theme types
type Theme = 'light' | 'dark';

// Interface for the context value
interface ThemeContextValue {
  theme: Theme;
  toggleTheme: () => void;
  setTheme: (theme: Theme) => void;
}

// Create the context with default values
const ThemeContext = createContext<ThemeContextValue>({
  theme: 'dark',
  toggleTheme: () => {},
  setTheme: () => {}
});

// Custom hook to use the theme context
export const useTheme = () => useContext(ThemeContext);

// Props for the provider component
interface ThemeProviderProps {
  children: ReactNode;
}

// Local storage key for theme persistence
const THEME_STORAGE_KEY = 'truckmate-theme';

/**
 * ThemeProvider component
 * Wraps the app to provide theme state with localStorage persistence
 */
export function ThemeProvider({ children }: ThemeProviderProps) {
  // Start with dark theme (will be updated from localStorage on mount)
  const [theme, setThemeState] = useState<Theme>('dark');
  const [mounted, setMounted] = useState(false);

  // Load saved theme from localStorage on mount
  useEffect(() => {
    const savedTheme = localStorage.getItem(THEME_STORAGE_KEY) as Theme | null;
    if (savedTheme && (savedTheme === 'light' || savedTheme === 'dark')) {
      setThemeState(savedTheme);
    }
    setMounted(true);
  }, []);

  // Apply theme class to document body when theme changes
  useEffect(() => {
    if (mounted) {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem(THEME_STORAGE_KEY, theme);
    }
  }, [theme, mounted]);

  // Toggle between light and dark themes
  const toggleTheme = () => {
    setThemeState(prev => prev === 'dark' ? 'light' : 'dark');
  };

  // Set a specific theme
  const setTheme = (newTheme: Theme) => {
    setThemeState(newTheme);
  };

  const contextValue: ThemeContextValue = {
    theme,
    toggleTheme,
    setTheme
  };

  // Prevent flash of incorrect theme on initial render
  if (!mounted) {
    return null;
  }

  return (
    <ThemeContext.Provider value={contextValue}>
      {children}
    </ThemeContext.Provider>
  );
}

export default ThemeContext;
