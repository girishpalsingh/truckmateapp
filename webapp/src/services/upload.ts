/**
 * Document Upload Service
 * Handles uploading rate confirmations to Supabase storage and processing
 */
import { getSupabase } from './supabase';

// Types for rate confirmation data
export interface RateConfirmation {
  id: string;
  rc_id: number;
  load_id: string;
  organization_id: string;
  broker_name: string;
  broker_mc: string;
  broker_phone: string;
  broker_email: string;
  carrier_name: string;
  total_rate: number;
  currency: string;
  risk_score: 'RED' | 'YELLOW' | 'GREEN' | 'UNKNOWN';
  status: string;
  document_id: string;
  created_at: string;
}

export interface RCStop {
  stop_id: number;
  stop_sequence: number;
  stop_type: 'Pickup' | 'Delivery';
  facility_address: string;
  contact_name: string;
  contact_phone: string;
  scheduled_arrival: string;
  special_instructions: string;
}

export interface DocumentRecord {
  id: string;
  organization_id: string;
  type: string;
  image_url: string;
  status: string;
  ai_data: Record<string, unknown>;
}

export interface UploadResult {
  success: boolean;
  documentId?: string;
  storagePath?: string;
  error?: string;
}

export interface ProcessResult {
  success: boolean;
  rateConId?: string;
  extractedData?: Record<string, unknown>;
  confidence?: number;
  error?: string;
}

/**
 * Uploads a rate confirmation file to Supabase storage
 * @param file - The file to upload
 * @param organizationId - The organization ID for the storage path
 */
export async function uploadRateCon(
  file: File,
  organizationId: string
): Promise<UploadResult> {
  const supabase = await getSupabase();
  
  // Generate a unique path
  const timestamp = Date.now();
  const fileName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
  const storagePath = `${organizationId}/rate_cons/${timestamp}_${fileName}`;
  
  try {
    // Upload file to storage
    const { data, error } = await supabase
      .storage
      .from('documents')
      .upload(storagePath, file, {
        cacheControl: '3600',
        upsert: false
      });

    if (error) {
      return { success: false, error: error.message };
    }

    // Create document record in database
    const { data: docRecord, error: docError } = await supabase
      .from('documents')
      .insert({
        organization_id: organizationId,
        type: 'rate_con',
        image_url: storagePath,
        status: 'pending_review'
      })
      .select()
      .single();

    if (docError) {
      return { success: false, error: docError.message };
    }

    return {
      success: true,
      documentId: docRecord.id,
      storagePath: storagePath
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Processes an uploaded document using AI
 * @param documentId - The document ID to process
 * @param imageUrl - The storage path of the image
 */
export async function processDocument(
  documentId: string,
  imageUrl: string
): Promise<ProcessResult> {
  const supabase = await getSupabase();
  
  try {
    const response = await supabase.functions.invoke('process-document', {
      body: {
        document_id: documentId,
        document_type: 'rate_con',
        image_url: imageUrl
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
      rateConId: data.rate_con_id,
      extractedData: data.extracted_data,
      confidence: data.confidence
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Gets a rate confirmation by ID with all related data
 * @param rateConId - The rate confirmation UUID
 */
export async function getRateConfirmation(rateConId: string): Promise<{
  success: boolean;
  rateCon?: RateConfirmation;
  stops?: RCStop[];
  error?: string;
}> {
  const supabase = await getSupabase();
  
  try {
    const { data, error } = await supabase
      .from('rate_confirmations')
      .select(`
        *,
        rc_stops (*),
        rc_dispatch_instructions (*),
        rc_charges (*),
        rc_risk_clauses (*)
      `)
      .eq('id', rateConId)
      .single();

    if (error) {
      return { success: false, error: error.message };
    }

    return {
      success: true,
      rateCon: data,
      stops: data.rc_stops
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}

/**
 * Lists all rate confirmations for an organization
 * @param organizationId - The organization ID
 */
export async function listRateConfirmations(organizationId: string): Promise<{
  success: boolean;
  rateCons?: RateConfirmation[];
  error?: string;
}> {
  const supabase = await getSupabase();
  
  try {
    const { data, error } = await supabase
      .from('rate_confirmations')
      .select('*')
      .eq('organization_id', organizationId)
      .order('created_at', { ascending: false });

    if (error) {
      return { success: false, error: error.message };
    }

    return {
      success: true,
      rateCons: data
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return { success: false, error: errorMessage };
  }
}
