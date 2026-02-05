/**
 * Dispatch Sheet Service
 * Handles generating and fetching dispatch sheets
 */
import { getSupabase } from './supabase';

export interface DispatchSheetResult {
  success: boolean;
  url?: string;
  path?: string;
  documentId?: string;
  error?: string;
}

/**
 * Generates a dispatch sheet for a load
 * @param loadId - The rate confirmation ID (used as load_id in the function)
 */
export async function generateDispatchSheet(loadId: string): Promise<DispatchSheetResult> {
  const supabase = await getSupabase();
  
  try {
    const response = await supabase.functions.invoke('generate-dispatch-sheet', {
      body: {
        load_id: loadId
      }
    });

    if (response.error) {
      return { success: false, error: response.error.message };
    }

    const data = response.data;
    
    if (data.error) {
      return { success: false, error: data.error };
    }

    return {
      success: true,
      url: data.url,
      path: data.path,
      documentId: data.document_id
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Gets an existing dispatch sheet for a load
 * @param loadId - The load ID to find the dispatch sheet for
 */
export async function getDispatchSheet(loadId: string): Promise<{
  success: boolean;
  document?: {
    id: string;
    image_url: string;
  };
  signedUrl?: string;
  error?: string;
}> {
  const supabase = await getSupabase();
  
  try {
    // Call Edge Function to get URL and track usage (Server-Side Metrics)
    const { data, error } = await supabase.functions.invoke('get-dispatch-sheet-url', {
      body: { load_id: loadId }
    });

    if (error) {
      console.error('Edge Function Error:', error);
      return { success: false, error: error.message };
    }

    if (data.error) {
      return { success: false, error: data.error };
    }

    return {
      success: true,
      signedUrl: data.url,
      document: {
        id: data.document_id || '',
        image_url: data.path
      }
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}
