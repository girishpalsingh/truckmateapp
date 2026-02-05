
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { withLogging } from "../_shared/logger.ts";
import { authorizeRole } from "../_shared/utils.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Verify User and Role
        const { profile } = await authorizeRole(req, supabase, ['dispatcher', 'admin', 'owner', 'manager', 'driver']);

        const body = await req.json();
        const { load_id, document_id } = body;

        let finalDocId = document_id;
        let finalPath = '';

        // If load_id provided, find the dispatch sheet document
        if (load_id && !document_id) {
            // First check load_dispatch_config
            const { data: config } = await supabase
                .from('load_dispatch_config')
                .select('generated_sheet_url')
                .eq('load_id', load_id)
                .maybeSingle();

            if (config?.generated_sheet_url) {
                finalPath = config.generated_sheet_url;
            } else {
                 // Fallback to documents search
                const { data: doc } = await supabase
                    .from('documents')
                    .select('id, image_url')
                    .eq('load_id', load_id)
                    .eq('ai_data->>subtype', 'dispatch_sheet')
                    .maybeSingle();
                
                if (doc) {
                    finalDocId = doc.id;
                    finalPath = doc.image_url;
                }
            }
        } else if (document_id) {
             const { data: doc } = await supabase
                .from('documents')
                .select('image_url')
                .eq('id', document_id)
                .single();
             if (doc) finalPath = doc.image_url;
        }

        if (!finalPath) {
             return new Response(
                JSON.stringify({ error: "Dispatch sheet not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Generate Signed URL
        const { data: signedData, error: signedError } = await supabase
            .storage
            .from('documents')
            .createSignedUrl(finalPath, 3600); // 1 hour

        if (signedError || !signedData) {
             throw new Error("Failed to generate signed URL");
        }

        let signedUrl = signedData.signedUrl;
         // Docker host fix (optional, if needed for local dev)
        if (signedUrl.includes('http://kong:8000')) {
             signedUrl = signedUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
        }

        // Track Metric
        await supabase.rpc('increment_user_metric', {
            action_name: 'dispatch_sheet_downloaded',
            resource_id_param: finalDocId || load_id,
            metadata_param: { path: finalPath }
        });

        return new Response(
            JSON.stringify({
                success: true,
                url: signedUrl,
                path: finalPath,
                document_id: finalDocId || load_id
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Error getting dispatch sheet URL:", error);
        return new Response(
            JSON.stringify({ error: (error as any).message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));
