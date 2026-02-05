/**
 * Configuration loader for the webapp
 * Loads Supabase credentials from app_config.json
 */

// Interface for the app configuration
export interface AppConfig {
  project_name: string;
  version: string;
  supabase: {
    project_url: string;
    anon_key: string;
  };
  development: {
    enabled: boolean;
    default_otp: string;
    skip_twilio: boolean;
  };
}

// Default config (will be overwritten by fetched config)
let cachedConfig: AppConfig | null = null;

/**
 * Fetches and caches the app configuration
 * Must be called from client-side code
 */
export async function getConfig(): Promise<AppConfig> {
  if (cachedConfig) {
    return cachedConfig;
  }

  try {
    const response = await fetch('/config/app_config.json');
    if (!response.ok) {
      throw new Error('Failed to load config');
    }
    cachedConfig = await response.json();
    return cachedConfig!;
  } catch (error) {
    console.error('Error loading config:', error);
    // Fallback to local development defaults
    return {
      project_name: 'TruckMate',
      version: '1.0.0',
      supabase: {
        project_url: 'http://127.0.0.1:54321',
        anon_key: ''
      },
      development: {
        enabled: true,
        default_otp: '123456',
        skip_twilio: true
      }
    };
  }
}

/**
 * Synchronous config getter - requires config to be pre-loaded
 */
export function getConfigSync(): AppConfig | null {
  return cachedConfig;
}
