
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { generateDispatchSheetPDF } from './dispatch-sheet-template.ts';
import { withLogging } from "../_shared/logger.ts";
import { authorizeUser } from "../_shared/auth.ts";
import { NotificationService } from "../_shared/notification-service.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
    load_id?: string;
    organization_id: string; // usually inferred from auth but good to have explicit
}

serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const user = await authorizeUser(req);
        if (!user) throw new Error("Unauthorized");

        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        const body: RequestBody = await req.json();
        const { load_id } = body;

        if (!load_id) {
            throw new Error("Missing load_id");
        }

        // 1. Fetch Data
        const { data: rateCon, error: rcError } = await supabase
            .from('rate_confirmations')
            .select('*, stops(*), rate_con_dispatcher_instructions(*)')
            .eq('id', load_id)
            .single();

        if (rcError) {
            console.error("Error fetching rate con:", rcError);
            throw new Error("Could not find Rate Confirmation/Load details");
        }

        // 2. Create PDF using Template
        const pdfBytes = await generateDispatchSheetPDF({
            rateConId: rateCon.rate_con_id,
            brokerName: rateCon.broker_name,
            stops: rateCon.stops,
            dispatchInstructions: rateCon.rate_con_dispatcher_instructions,
            loadId: load_id
        });

        // 3. Upload to Storage
        const fileName = `${rateCon.organization_id}/${load_id}/dispatch_sheet_${Date.now()}.pdf`;
        const { data: uploadData, error: uploadError } = await supabase
            .storage
            .from('documents') // Using documents bucket
            .upload(fileName, pdfBytes, {
                contentType: 'application/pdf',
                upsert: true
            });

        if (uploadError) {
            console.error("Upload error:", uploadError);
            throw new Error("Failed to upload dispatcher sheet");
        }

        // 4. Update DB
        const { error: configError } = await supabase
            .from('load_dispatch_config')
            .upsert({
                load_id: load_id,
                organization_id: rateCon.organization_id,
                generated_sheet_url: fileName,
                updated_at: new Date().toISOString()
            }, { onConflict: 'load_id' });

        if (configError) {
            console.error("Config update error:", configError);
        }

        // 5. Generate Signed URL
        const { data: signedUrlData } = await supabase
            .storage
            .from('documents')
            .createSignedUrl(fileName, 3600);

        const finalUrl = signedUrlData?.signedUrl || fileName;
        console.log(`Dispatcher Sheet Generated: ${finalUrl}`);

        // 6. Send Notification
        const notificationService = new NotificationService(supabase);
        await notificationService.sendNotification({
            userId: user.id,
            organizationId: rateCon.organization_id,
            title: "Dispatcher Sheet Ready",
            body: `Dispatch sheet for ${rateCon.rate_con_id} has been generated.`,
            data: {
                load_id: load_id,
                action: 'open_dispatch_sheet',
                url: finalUrl
            },
            type: 'dispatch_sheet'
        });

        return new Response(
            JSON.stringify({
                success: true,
                message: "Dispatcher sheet created",
                url: finalUrl,
                path: fileName
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Error generating dispatch sheet:", error);
        return new Response(
            JSON.stringify({ error: (error as any).message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));
