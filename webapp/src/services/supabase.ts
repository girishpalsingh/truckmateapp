/**
 * Supabase client configuration
 * Creates a Supabase client using the anon key from app_config.json
 */
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { getConfig } from '@/lib/config';

// Singleton instance
let supabaseClient: SupabaseClient | null = null;

/**
 * Initializes and returns the Supabase client
 * Must be called after config is loaded
 */
export async function getSupabase(): Promise<SupabaseClient> {
  if (supabaseClient) {
    return supabaseClient;
  }

  const config = await getConfig();
  
  supabaseClient = createClient(
    config.supabase.project_url,
    config.supabase.anon_key,
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      }
    }
  );

  return supabaseClient;
}

/**
 * Gets the Supabase client synchronously
 * Will throw if not initialized
 */
export function getSupabaseSync(): SupabaseClient {
  if (!supabaseClient) {
    throw new Error('Supabase client not initialized. Call getSupabase() first.');
  }
  return supabaseClient;
}
