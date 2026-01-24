
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { generateDispatchSheetPDF } from './dispatch-sheet-template.ts';
import { withLogging } from "../_shared/logger.ts";
import { NotificationService } from "../_shared/notification-service.ts";
import { authorizeRole } from "../_shared/utils.ts";

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
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Verify User and Role in one step
        const profile = await authorizeRole(req, supabase, ['dispatcher', 'admin', 'owner', 'driver']);

        const body: { trip_id?: string; load_id?: string } = await req.json();
        const { trip_id, load_id } = body;

        if (!trip_id && !load_id) {
            throw new Error("Missing trip_id or load_id");
        }

        let rateCons: any[] = [];
        let contextId = trip_id || load_id!;
        let organizationId = "";

        // 1. Fetch Data
        if (trip_id) {
            console.log(`Fetching loads for Trip: ${trip_id}`);
            const { data: tripData, error: tripError } = await supabase
                .from('trip_loads')
                .select(`
                    load_id,
                    loads (
                        rate_confirmation_id,
                        organization_id,
                        rate_confirmations (
                            *,
                            stops (*),
                            rate_con_dispatcher_instructions (*)
                        )
                    )
                `)
                .eq('trip_id', trip_id);

            if (tripError) throw tripError;

            // Extract valid rate confirmations
            rateCons = tripData
                .map((t: any) => t.loads?.rate_confirmations)
                .filter((r: any) => r !== null && r !== undefined);

            if (tripData.length > 0) {
                organizationId = tripData[0].loads?.organization_id;
            }
        }

        if (rateCons.length === 0 && load_id) {
            console.log(`Fetching Rate Con directly for Load/RC ID: ${load_id}`);
            // Fallback: Check if load_id is actually a rate_con_id (legacy) OR a loads.id
            // First try as rate_con_id (Legacy support for current tests)
            const { data: rc, error: rcError } = await supabase
                .from('rate_confirmations')
                .select('*, stops(*), rate_con_dispatcher_instructions(*)')
                .eq('id', load_id)
                .maybeSingle();

            if (rc) {
                rateCons = [rc];
                organizationId = rc.organization_id;
            } else {
                // Try as loads.id
                const { data: loadData } = await supabase
                    .from('loads')
                    .select(`
                        rate_confirmation_id,
                        organization_id,
                        rate_confirmations (
                            *,
                            stops (*),
                            rate_con_dispatcher_instructions (*)
                        )
                    `)
                    .eq('id', load_id)
                    .maybeSingle();

                if (loadData?.rate_confirmations) {
                    rateCons = [loadData.rate_confirmations];
                    organizationId = loadData.organization_id;
                }
            }
        }

        if (rateCons.length === 0) {
            throw new Error("No rate confirmations found for the provided ID");
        }

        // 2. Aggregate Data
        // Merge stops
        let allStops: any[] = [];
        rateCons.forEach(rc => {
            if (rc.stops) allStops = allStops.concat(rc.stops);
        });

        // Sort stops by scheduled_arrival
        allStops.sort((a, b) => {
            const dateA = new Date(a.scheduled_arrival || 0).getTime();
            const dateB = new Date(b.scheduled_arrival || 0).getTime();
            return dateA - dateB;
        });

        // Merge Instructions and Driver View
        let allInstructions: any[] = [];
        let combinedDriverView: any = { special_equipment_needed: [], transit_requirements: [] };

        rateCons.forEach(rc => {
            if (rc.rate_con_dispatcher_instructions) {
                allInstructions = allInstructions.concat(rc.rate_con_dispatcher_instructions);
            }
            if (rc.driver_view_data) {
                if (rc.driver_view_data.special_equipment_needed) {
                    combinedDriverView.special_equipment_needed.push(...rc.driver_view_data.special_equipment_needed);
                }
                if (rc.driver_view_data.transit_requirements) {
                    combinedDriverView.transit_requirements.push(...rc.driver_view_data.transit_requirements);
                }
            }
        });

        // Deduplicate simple arrays in driver view
        combinedDriverView.special_equipment_needed = [...new Set(combinedDriverView.special_equipment_needed)];
        combinedDriverView.transit_requirements = [...new Set(combinedDriverView.transit_requirements)];


        // 3. Generate PDF
        const pdfBytes = await generateDispatchSheetPDF({
            rateConId: rateCons.map(r => r.rate_con_id).join(', '), // Combined Ref
            brokerName: rateCons.map(r => r.broker_name).filter(Boolean).join(' & '),
            stops: allStops,
            dispatchInstructions: allInstructions,
            loadId: contextId,
            driverView: combinedDriverView
        });

        // 4. Upload to Storage
        // New Path: organization/trip_id/dispatch_documents/dispatcher_sheet.pdf
        const folderPath = trip_id ? `${organizationId}/${trip_id}/dispatch_documents` : `${organizationId}/${contextId}/dispatch_documents`;
        const fileName = `${folderPath}/dispatcher_sheet.pdf`;

        console.log(`Uploading to: ${fileName}`);

        const { data: uploadData, error: uploadError } = await supabase
            .storage
            .from('documents')
            .upload(fileName, pdfBytes, {
                contentType: 'application/pdf',
                upsert: true
            });

        if (uploadError) {
            console.error("Upload error:", uploadError);
            throw new Error("Failed to upload dispatcher sheet");
        }

        // 5. Create Document Record & Link
        const { data: docRecord, error: docError } = await supabase
            .from('documents')
            .insert({
                organization_id: organizationId,
                trip_id: trip_id || null,
                load_id: load_id || null,
                type: 'other',
                image_url: fileName,
                status: 'approved',
                ai_data: { subtype: 'dispatch_sheet', source_id: contextId },
                created_at: new Date().toISOString()
            })
            .select()
            .single();

        if (docError) console.error("Error creating document record:", docError);

        // Link to Trip if applicable
        if (trip_id && docRecord) {
            const { error: tripUpdateError } = await supabase
                .from('trips')
                .update({ dispatch_document_id: docRecord.id })
                .eq('id', trip_id);
            if (tripUpdateError) console.error("Error linking doc to trip:", tripUpdateError);
        }

        // Legacy: Update load_dispatch_config if load_id used
        if (load_id) {
            await supabase.from('load_dispatch_config').upsert({
                load_id: load_id,
                organization_id: organizationId,
                generated_sheet_url: fileName,
                updated_at: new Date().toISOString()
            }, { onConflict: 'load_id' });
        }


        // 6. Generate Signed URL (30 Days)
        const expirationSeconds = 30 * 24 * 3600; // 30 days
        const { data: signedUrlData, error: signedUrlError } = await supabase
            .storage
            .from('documents')
            .createSignedUrl(fileName, expirationSeconds);

        if (signedUrlError) {
            console.error("Error creating signed URL:", signedUrlError);
        }

        let finalUrl = signedUrlData?.signedUrl || fileName;

        // Fix for local development: Replace kong:8000 with a reachable address for the simulator
        if (finalUrl.includes('http://kong:8000')) {
            // Standard mapping: kong:8000 (inside Docker) -> 127.0.0.1:54321 (outside for simulator)
            // We use 127.0.0.1:54321 which is the default Supabase local gateway port
            finalUrl = finalUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
            console.log(`Local Supabase detected. Proactively replaced kong:8000 with reachable simulator address.`);
        }

        console.log(`Dispatcher Sheet Generated: ${finalUrl}`);

        // 7. Send Notification
        const notificationService = new NotificationService(supabase);
        await notificationService.sendNotification({
            userId: profile.id,
            organizationId: organizationId,
            title: "Dispatcher Sheet Ready",
            body: `Dispatch sheet has been generated.`,
            data: {
                trip_id: trip_id,
                load_id: load_id,
                action: 'open_dispatch_sheet',
                url: finalUrl,
                path: fileName
            },
            type: 'dispatch_sheet'
        });

        return new Response(
            JSON.stringify({
                success: true,
                message: "Dispatcher sheet created",
                url: finalUrl,
                path: fileName,
                document_id: docRecord?.id
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
