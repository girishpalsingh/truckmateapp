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
    // First check load_dispatch_config for the generated sheet URL
    const { data: config, error: configError } = await supabase
      .from('load_dispatch_config')
      .select('generated_sheet_url')
      .eq('load_id', loadId)
      .maybeSingle();

    if (config?.generated_sheet_url) {
      // Generate a signed URL for the stored PDF
      const { data: signedData } = await supabase
        .storage
        .from('documents')
        .createSignedUrl(config.generated_sheet_url, 3600);

      return {
        success: true,
        signedUrl: signedData?.signedUrl,
        document: {
          id: '',
          image_url: config.generated_sheet_url
        }
      };
    }

    // Fallback: check documents table
    const { data: doc, error: docError } = await supabase
      .from('documents')
      .select('id, image_url')
      .eq('load_id', loadId)
      .eq('ai_data->>subtype', 'dispatch_sheet')
      .maybeSingle();

    if (docError || !doc) {
      return { success: false, error: 'No dispatch sheet found' };
    }

    // Generate signed URL
    const { data: signedData } = await supabase
      .storage
      .from('documents')
      .createSignedUrl(doc.image_url, 3600);

    return {
      success: true,
      document: doc,
      signedUrl: signedData?.signedUrl
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}
