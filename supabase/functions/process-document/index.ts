// supabase/functions/process-document/index.ts
// Document Processing Edge Function with LLM Integration
// Now simplified to use shared document-processor

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { withLogging } from "../_shared/logger.ts";
import { processDocumentWithAI } from "../_shared/document-processor.ts";
import { authorizeRole } from "../_shared/utils.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProcessRequest {
    document_id: string;
    document_type: string;
    image_url: string; // Storage path
    local_extraction?: string;
}

serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Verify User and Role
        const { profile } = await authorizeRole(req, supabase, ['admin', 'owner', 'dispatcher', 'driver']);

        const body: ProcessRequest = await req.json();
        const { document_id, document_type, image_url } = body;

        // Get organization ID (needed for processor)
        const { data: doc } = await supabase
            .from("documents")
            .select("organization_id")
            .eq("id", document_id)
            .single();

        if (!doc) {
            return new Response(
                JSON.stringify({ error: "Document not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Generate Signed URL for the image so the processor can fetch it
        // image_url is the storage path (e.g. "orgId/folder/file.jpg")
        const { data: signedUrlData, error: signedUrlError } = await supabase
            .storage
            .from("documents")
            .createSignedUrl(image_url, 60);

        if (signedUrlError || !signedUrlData) {
            console.error("Failed to sign URL:", signedUrlError);
            return new Response(
                JSON.stringify({ error: "Failed to access document image" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Call Shared Processor
        const result = await processDocumentWithAI(
            document_id,
            signedUrlData.signedUrl,
            document_type,
            doc.organization_id
        );

        // Log document processing event (Audit)
        // Note: processDocumentWithAI doesn't do this, so we keep it here or add to processor.
        // Keeping it here for now to maintain behavior parity.
        await supabase.rpc('log_document_event', {
            p_document_id: document_id,
            p_organization_id: doc.organization_id,
            p_action: 'process',
            p_storage_path: image_url,
            p_metadata: {
                llm_provider: result.modelUsed,
                confidence: result.confidence,
                document_type,
                processed_at: new Date().toISOString(),
            },
        });

        return new Response(
            JSON.stringify({
                success: true,
                document_id,
                extracted_data: result.extractedData,
                rate_con_id: result.rateConId, // This is the DB UUID
                confidence: result.confidence,
                llm_provider: result.modelUsed,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Document processing error:", error);
        return new Response(
            JSON.stringify({ error: (error as any).message || "Processing failed" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));
