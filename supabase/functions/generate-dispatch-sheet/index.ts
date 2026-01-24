
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Handlebars from "https://esm.sh/handlebars@4.7.7";
import { withLogging } from "../_shared/logger.ts";
import { NotificationService } from "../_shared/notification-service.ts";
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
        // Config: URL of your PDF Microservice
        const PDF_SERVICE_URL = Deno.env.get("PDF_SERVICE_URL") || `${supabaseUrl}/functions/v1/generate-pdf`;

        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        // Verify User and Role
        const profile = await authorizeRole(req, supabase, ['dispatcher', 'admin', 'owner', 'driver']);

        const body: { trip_id?: string; load_id?: string } = await req.json();
        const { trip_id, load_id } = body;

        if (!trip_id && !load_id) {
            throw new Error("Missing trip_id or load_id");
        }

        let rateCons: any[] = [];
        let contextId = trip_id || load_id!;
        let organizationId = "";

        // ---------------------------------------------------------
        // 1. Fetch Data
        // ---------------------------------------------------------
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

            rateCons = tripData
                .map((t: any) => t.loads?.rate_confirmations)
                .filter((r: any) => r !== null && r !== undefined);

            if (tripData.length > 0) {
                organizationId = tripData[0].loads?.organization_id;
            }
        }

        if (rateCons.length === 0 && load_id) {
            // Fallback logic for direct Load ID
            const { data: rc } = await supabase
                .from('rate_confirmations')
                .select('*, stops(*), rate_con_dispatcher_instructions(*)')
                .eq('id', load_id)
                .maybeSingle();

            if (rc) {
                rateCons = [rc];
                organizationId = rc.organization_id;
            } else {
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

        // ---------------------------------------------------------
        // 2. Aggregate Data
        // ---------------------------------------------------------
        let allStops: any[] = [];
        rateCons.forEach(rc => { if (rc.stops) allStops = allStops.concat(rc.stops); });
        allStops.sort((a, b) => new Date(a.scheduled_arrival || 0).getTime() - new Date(b.scheduled_arrival || 0).getTime());

        let allInstructions: any[] = [];
        let combinedDriverView: any = { special_equipment_needed: [], transit_requirements: [] };

        rateCons.forEach(rc => {
            if (rc.rate_con_dispatcher_instructions) {
                allInstructions = allInstructions.concat(rc.rate_con_dispatcher_instructions);
            }
            if (rc.driver_view_data) {
                combinedDriverView.special_equipment_needed.push(...(rc.driver_view_data.special_equipment_needed || []));
                combinedDriverView.transit_requirements.push(...(rc.driver_view_data.transit_requirements || []));
            }
        });

        // Deduplicate
        combinedDriverView.special_equipment_needed = [...new Set(combinedDriverView.special_equipment_needed)];
        combinedDriverView.transit_requirements = [...new Set(combinedDriverView.transit_requirements)];


        // ---------------------------------------------------------
        // 2.1 Fetch Organization Details
        // ---------------------------------------------------------
        const { data: orgData } = await supabase
            .from('organizations')
            .select('name, registered_address, logo_image_link')
            .eq('id', organizationId)
            .maybeSingle();

        let orgLogoUrl = '';
        if (orgData?.logo_image_link) {
            if (orgData.logo_image_link.startsWith('http')) {
                orgLogoUrl = orgData.logo_image_link;
            } else {
                // Try 'assets' bucket first (user preferred), then 'public'
                try {
                    const { data: signedLogo, error } = await supabase.storage.from('assets').createSignedUrl(orgData.logo_image_link, 3600);
                    if (signedLogo) {
                        orgLogoUrl = signedLogo.signedUrl;
                    } else if (error) {
                        console.log("Logo signing error (assets bucket), trying public:", error.message);
                        // Fallback to public
                        const { data: signedLogoPublic, error: errorPublic } = await supabase.storage.from('public').createSignedUrl(orgData.logo_image_link, 3600);
                        if (signedLogoPublic) orgLogoUrl = signedLogoPublic.signedUrl;
                    }
                } catch (e) {
                    console.log("Logo signing exception:", e);
                }
            }
        }

        // Fallback for testing if logo is missing
        if (!orgLogoUrl) {
            orgLogoUrl = "https://placehold.co/200x60?text=Logo+Missing";
        }

        // Fix for local simulator (Kong internal host)
        if (orgLogoUrl && orgLogoUrl.includes('http://kong:8000')) {
            orgLogoUrl = orgLogoUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
        }

        const formatAddress = (addr: any) => {
            if (!addr) return '';
            if (typeof addr === 'string') return addr;
            const line1 = addr.address_line1 || addr.street || '';
            const city = addr.city || '';
            const state = addr.state || addr.province || '';
            const zip = addr.zip || addr.postal_code || '';
            // Use <br/> for HTML line break to be handled by triple-stash {{{ }}} in Handlebars
            return [line1, `${city}, ${state} ${zip}`].filter(Boolean).join('<br/>');
        };
        const orgAddress = formatAddress(orgData?.registered_address);
        const orgName = orgData?.name || 'TruckMate';
        console.log("DEBUG LOGO URL:", orgLogoUrl);


        // ---------------------------------------------------------
        // 3. Prepare HTML with Handlebars
        // ---------------------------------------------------------

        const { dispatchSheetTemplate } = await import('./templates/dispatch-sheet-template.ts');

        // Helper to format date
        const formatDate = (d: string) => d ? new Date(d).toLocaleString() : 'TBD';

        const stopsMapped = allStops.map((stop: any) => {
            const badgeClass = stop.stop_type?.toLowerCase().includes('pickup') ? 'bg-pickup' :
                stop.stop_type?.toLowerCase().includes('delivery') ? 'bg-delivery' : 'bg-other';

            let cityState = stop.city && stop.state ? `${stop.city}, ${stop.state}` : '';

            if (!cityState && stop.address) {
                // Fallback: Try to parse "City, State Zip" from address string
                // Example: "1500 Blair Rd, Carteret, NJ 07008"
                const parts = stop.address.split(',').map((p: string) => p.trim());
                if (parts.length >= 2) {
                    // Assume format: [..., City, State Zip]
                    const stateZip = parts[parts.length - 1]; // "NJ 07008"
                    const city = parts[parts.length - 2];     // "Carteret"

                    // Extract state from "NJ 07008" -> "NJ"
                    const stateParts = stateZip.split(' ');
                    const state = stateParts[0];

                    if (city && state) {
                        cityState = `${city}, ${state}`;
                    }
                }
            }

            if (!cityState) cityState = 'Location TBD';

            return {
                badgeClass,
                stopType: stop.stop_type,
                cityState,
                address: stop.address || '',
                scheduledArrival: formatDate(stop.scheduled_arrival),
                notes: stop.special_instructions || stop.notes || '-'
            };
        });

        const instructionsMapped = allInstructions.map((i: any) => ({
            title_en: i.title_en || 'Instruction',
            description_en: i.description_en || '',
            hasPunjabi: !!(i.title_punjab || i.description_punjab),
            title_punjab: i.title_punjab || '',
            description_punjab: i.description_punjab || ''
        }));

        const templateData = {
            orgLogoUrl,
            orgName,
            orgAddress,
            refIds: rateCons.map(r => r.rate_con_id).join(', '),
            brokerName: rateCons.map(r => r.broker_name).filter(Boolean).join(' & '),
            generatedDate: new Date().toLocaleString(),
            stops: stopsMapped,
            equipment: combinedDriverView.special_equipment_needed.join(', '),
            transit: combinedDriverView.transit_requirements.join(', '),
            instructions: instructionsMapped
        };

        const compiledTemplate = Handlebars.compile(dispatchSheetTemplate);
        const htmlContent = compiledTemplate(templateData);

        console.log("DEBUG HTML CONTENT LEN:", htmlContent.length);

        // ---------------------------------------------------------
        // 4. Call PDF Microservice
        // ---------------------------------------------------------

        // Define path explicitly (Microservice needs to know WHERE to put it)
        const folderPath = trip_id
            ? `${organizationId}/${trip_id}/dispatch_documents`
            : `${organizationId}/${contextId}/dispatch_documents`;
        const fileName = `${folderPath}/dispatcher_sheet.pdf`;

        console.log(`Calling PDF Service for: ${fileName}`);

        const pdfResponse = await fetch(PDF_SERVICE_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                // Pass Service Role Key to bypass Gateway/Auth checks in the Microservice
                "Authorization": `Bearer ${supabaseServiceKey}`
            },
            body: JSON.stringify({
                bucketName: "documents", // Target Bucket
                uploadPath: fileName,    // Target Path
                html: htmlContent,
                css: "" // Included in template
            })
        });

        if (!pdfResponse.ok) {
            const errText = await pdfResponse.text();
            throw new Error(`PDF Service Failed [${pdfResponse.status}]: ${errText}`);
        }

        const pdfResult = await pdfResponse.json();
        console.log(`PDF Service Success: ${pdfResult.fullUrl}`);

        // ---------------------------------------------------------
        // 5. Create Document Record
        // ---------------------------------------------------------
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

        // Link to Trip
        if (trip_id && docRecord) {
            await supabase.from('trips').update({ dispatch_document_id: docRecord.id }).eq('id', trip_id);
        }

        // Legacy Config Update
        if (load_id) {
            await supabase.from('load_dispatch_config').upsert({
                load_id: load_id,
                organization_id: organizationId,
                generated_sheet_url: fileName,
                updated_at: new Date().toISOString()
            }, { onConflict: 'load_id' });
        }

        // ---------------------------------------------------------
        // 6. Generate Signed URL
        // ---------------------------------------------------------
        const { data: signedUrlData } = await supabase
            .storage
            .from('documents')
            .createSignedUrl(fileName, 30 * 24 * 3600);

        let finalUrl = signedUrlData?.signedUrl || fileName;

        // Fix for local simulator
        if (finalUrl.includes('http://kong:8000')) {
            finalUrl = finalUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
        }

        // ---------------------------------------------------------
        // 7. Send Notification
        // ---------------------------------------------------------
        const notificationService = new NotificationService(supabase);
        await notificationService.sendNotification({
            userId: profile.id,
            organizationId: organizationId,
            title: "Dispatcher Sheet Ready",
            body: `Dispatch sheet has been generated.`,
            data: { trip_id, load_id, action: 'open_dispatch_sheet', url: finalUrl, path: fileName },
            type: 'dispatch_sheet'
        });

        return new Response(
            JSON.stringify({
                success: true,
                message: "Dispatcher sheet created",
                url: finalUrl,
                path: fileName,
                document_id: docRecord?.id,
                html_debug: htmlContent // Debugging aid
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