
import { createClient } from "@supabase/supabase-js";
import Handlebars from "https://esm.sh/handlebars@4.7.7";
import { withLogging } from "../_shared/logger.ts";
import { NotificationService } from "../_shared/notification-service.ts";
import { authorizeRole } from "../_shared/utils.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => withLogging(req, async (req) => {
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
        const { profile } = await authorizeRole(req, supabase, ['dispatcher', 'admin', 'owner', 'driver']);

        const body: { trip_id?: string; load_id?: string } = await req.json();
        const { trip_id, load_id } = body;

        if (!trip_id && !load_id) {
            return new Response(
                JSON.stringify({ error: "Missing trip_id or load_id" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        let rateCons: any[] = [];
        let contextId = trip_id || load_id!;
        let organizationId = "";


        // ---------------------------------------------------------
        // 1. Fetch Data (Updated for New Schema)
        // ---------------------------------------------------------
        if (trip_id) {
            console.log(`Fetching loads for Trip: ${trip_id}`);
            // Step 1: Get load IDs from trip_loads
            const { data: tripLoads, error: tlError } = await supabase
                .from('trip_loads')
                .select('load_id')
                .eq('trip_id', trip_id);

            if (tlError) throw tlError;

            const loadIds = tripLoads?.map((tl: any) => tl.load_id) || [];

            if (loadIds.length > 0) {
                // Step 2: Fetch Loads with Rate Cons
                const { data: loadsData, error: loadsError } = await supabase
                    .from('loads')
                    .select(`
                        active_rate_con_id,
                        organization_id,
                        rate_confirmations!active_rate_con_id (
                            *,
                            rc_stops (*),
                            rc_dispatch_instructions (*)
                        )
                    `)
                    .in('id', loadIds);

                if (loadsError) throw loadsError;

                // Map deeply nested rate confirmations
                rateCons = loadsData
                    .map((l: any) => l.rate_confirmations)
                    .filter((r: any) => r !== null && r !== undefined);

                if (loadsData.length > 0) {
                    organizationId = loadsData[0].organization_id;
                }
            } else {
                console.log('No loads found for this trip.');
            }
        }

        if (rateCons.length === 0 && load_id) {
            console.log(`Fetching Load directly: ${load_id}`);
            // Fallback logic for direct Load ID
            // Check if load_id is actually the RC ID (internal UUID) or the Load Table ID

            // Try fetching RC directly assuming load_id might be passed as rc.id
            const { data: rc, error: rcError } = await supabase
                .from('rate_confirmations')
                .select('*, rc_stops(*), rc_dispatch_instructions(*)')
                .eq('id', load_id)
                .maybeSingle();

            if (rcError) console.log("Error fetching RC by ID:", rcError);

            if (rc) {
                console.log("Found RC by direct ID match");
                rateCons = [rc];
                organizationId = rc.organization_id;
            } else {
                console.log("Looking up Load to find RC...");
                const { data: loadData, error: loadError } = await supabase
                    .from('loads')
                    .select(`
                        rate_confirmation_id,
                        organization_id,
                        rate_confirmations (
                            *,
                            rc_stops (*),
                            rc_dispatch_instructions (*)
                        )
                    `)
                    .eq('id', load_id)
                    .maybeSingle();

                if (loadError) console.log("Error fetching Load:", loadError);
                if (loadData) {
                    console.log("Load Data found:", JSON.stringify(loadData));
                    if (loadData.rate_confirmations) {
                        rateCons = [loadData.rate_confirmations];
                        organizationId = loadData.organization_id;
                    } else {
                        console.log("Load found but NO rate_confirmations relation data");
                    }
                } else {
                    console.log("No Load found for ID:", load_id);
                }
            }
        }

        if (rateCons.length === 0) {
            return new Response(
                JSON.stringify({ error: "No rate confirmations found for the provided ID" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // ---------------------------------------------------------
        // 2. Aggregate Data
        // ---------------------------------------------------------
        let allStops: any[] = [];
        // New Schema: rc_stops
        rateCons.forEach(rc => { if (rc.rc_stops) allStops = allStops.concat(rc.rc_stops); });
        allStops.sort((a, b) => new Date(a.scheduled_arrival || 0).getTime() - new Date(b.scheduled_arrival || 0).getTime());

        let allInstructions: any[] = []; // Action items
        let combinedDriverView: any = { special_equipment_needed: [], transit_requirements: [], transit_requirements_punjabi: [] };

        rateCons.forEach(rc => {
            // New Schema: rc_dispatch_instructions is a single object (or array of 1?) per RC usually, but relation might return array
            // Check relations. It returns array usually if One-to-Many, but here it is One-to-One mostly. 
            // Supabase returns array [] for hasMany or single {} for hasOne depending on query. 
            // Since we didn't specify !inner, it returns array [].

            const instrs = rc.rc_dispatch_instructions || [];
            if (Array.isArray(instrs)) {
                instrs.forEach(inst => {
                    // Action Items (Array of objects)
                    if (inst.action_items && Array.isArray(inst.action_items)) {
                        allInstructions = allInstructions.concat(inst.action_items);
                    }

                    // Summaries & Reqs (Arrays of strings or JSON)
                if (inst.special_equip_en) combinedDriverView.special_equipment_needed.push(...inst.special_equip_en);
                if (inst.transit_reqs_en) combinedDriverView.transit_requirements.push(...inst.transit_reqs_en);
                if (inst.transit_reqs_punjabi) combinedDriverView.transit_requirements_punjabi.push(...inst.transit_reqs_punjabi);
                });
            } else if (instrs) {
                // Single object case
                const inst = instrs as any;
                if (inst.action_items) allInstructions = allInstructions.concat(inst.action_items);
                if (inst.special_equip_en) combinedDriverView.special_equipment_needed.push(...inst.special_equip_en);
                if (inst.transit_reqs_punjabi) combinedDriverView.transit_requirements_punjabi.push(...inst.transit_reqs_punjabi);
            }
        });

        // Deduplicate
        combinedDriverView.special_equipment_needed = [...new Set(combinedDriverView.special_equipment_needed)];
        combinedDriverView.transit_requirements = [...new Set(combinedDriverView.transit_requirements)];
        combinedDriverView.transit_requirements_punjabi = [...new Set(combinedDriverView.transit_requirements_punjabi)];


        // ---------------------------------------------------------
        // 2.1 Fetch Organization Details (Unchanged)
        // ---------------------------------------------------------
        const { data: orgData } = await supabase
            .from('organizations')
            .select('name, registered_address, logo_image_link, mc_dot_number')
            .eq('id', organizationId)
            .maybeSingle();

        let orgLogoUrl = '';
        if (orgData?.logo_image_link) {
            try {
                // If it's already a full generic URL (e.g. from a public bucket or external), try to fetch it
                // If it's a storage path, download it from Supabase storage

                let blob: Blob | null = null;
                let mimeType = 'image/png'; // Default

                if (orgData.logo_image_link.startsWith('http')) {
                    // External URL
                    // Already a full URL
                    console.log("Using external logo URL:", orgData.logo_image_link);
                    orgLogoUrl = orgData.logo_image_link;
                } else {
                    console.log("Processing Logo Path:", orgData.logo_image_link);

                    // 1. Generate & Log Public URL (for debugging/fallback)
                    const { data: publicData } = supabase
                        .storage
                        .from('assets')
                        .getPublicUrl(orgData.logo_image_link);

                    if (publicData?.publicUrl) {
                        console.log("Public URL Candidate (Assets):", publicData.publicUrl);
                    }

                    // 2. Try Signed URL (Primary for Private Buckets)
                    const { data: signedData, error: signedError } = await supabase
                        .storage
                        .from('assets')
                        .createSignedUrl(orgData.logo_image_link, 3600); // 1 hour expiration

                    if (signedData?.signedUrl) {
                        console.log("Generated Signed URL (Assets):", signedData.signedUrl);
                        orgLogoUrl = signedData.signedUrl;
                    } else {
                        console.error("Signed URL generation failed:", signedError);
                        // Fallback to Public URL if Signed fails
                        if (publicData?.publicUrl) {
                            console.log("Falling back to Public URL.");
                            orgLogoUrl = publicData.publicUrl;
                        }
                    }

                    // FIX for Local Docker Dev: Replace 'kong' with 'host.docker.internal'
                    if (orgLogoUrl && (orgLogoUrl.includes('kong') || orgLogoUrl.includes('supabase_kong'))) {
                        console.log("Replacing internal 'kong' host with 'host.docker.internal:54321'");
                        // Replace protocol://hostname:port with http://host.docker.internal:54321
                        orgLogoUrl = orgLogoUrl.replace(/https?:\/\/[^\/]+/, 'http://host.docker.internal:54321');
                    }
                }

                if (blob) {
                    const buffer = await blob.arrayBuffer();
                    const bytes = new Uint8Array(buffer);
                    let binary = '';
                    const len = bytes.byteLength;
                    for (let i = 0; i < len; i++) {
                        binary += String.fromCharCode(bytes[i]);
                    }
                    const base64 = btoa(binary);

                    orgLogoUrl = `data:${mimeType};base64,${base64}`;
                    console.log("Logo converted to base64 successfully.");
                } else {
                    console.log("Failed to download logo logic.");
                }

            } catch (e) {
                console.log("Logo processing exception:", e);
            }
        }

        // Fallback for testing
        if (!orgLogoUrl) {
            orgLogoUrl = "https://placehold.co/200x60?text=Logo+Missing";
        }
        // No need to replace kong host for base64 or placeholder

        const formatAddress = (addr: any) => {
            if (!addr) return '';
            if (typeof addr === 'string') return addr;
            const line1 = addr.address_line1 || addr.street || '';
            const city = addr.city || '';
            const state = addr.state || addr.province || '';
            const zip = addr.zip || addr.postal_code || '';
            return [line1, `${city}, ${state} ${zip}`].filter(Boolean).join('<br/>');
        };
        const orgAddress = formatAddress(orgData?.registered_address);
        const orgName = orgData?.name || 'TruckMate';
        const mcDotNumber = orgData?.mc_dot_number || '';


        // ---------------------------------------------------------
        // 3. Prepare HTML with Handlebars
        // ---------------------------------------------------------

        const { dispatchSheetTemplate } = await import('./templates/dispatch-sheet-template.ts');

        // Helper to format date in PST
        const formatDate = (d: string) => {
            if (!d) return 'TBD';
            return new Date(d).toLocaleString('en-US', {
                timeZone: 'America/Los_Angeles',
                year: 'numeric', month: 'numeric', day: 'numeric',
                hour: '2-digit', minute: '2-digit', timeZoneName: 'short'
            });
        };

        const stopsMapped = allStops.map((stop: any) => {
            const badgeClass = stop.stop_type?.toLowerCase().includes('pickup') ? 'bg-pickup' :
                stop.stop_type?.toLowerCase().includes('delivery') ? 'bg-delivery' : 'bg-other';

            let cityState = '';
            // New schema: facility_address is TEXT.
            const addressRaw = stop.facility_address || stop.address || '';

            // Try to extract City/State manually if not provided separately (new schema doesn't have city/state columns)
            if (addressRaw) {
                const parts = addressRaw.split(',').map((p: string) => p.trim());
                if (parts.length >= 2) {
                    const stateZip = parts[parts.length - 1];
                    const city = parts[parts.length - 2];
                    const stateParts = stateZip.split(' ');
                    const state = stateParts[0];

                    if (city && state) {
                        cityState = `${city}, ${state}`;
                    }
                }
            }
            if (!cityState) cityState = 'Location TBD';

            const mapLink = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addressRaw || cityState)}`;

            return {
                badgeClass,
                stopType: stop.stop_type,
                cityState,
                address: addressRaw,
                mapLink,
                scheduledArrival: formatDate(stop.scheduled_arrival),
                notes: stop.special_instructions || '-',
                notes_punjabi: stop.special_instructions_punjabi || ''
            };
        });

        // Instructions Mapping from Action Items
        const instructionsMapped = allInstructions.map((i: any) => ({
            title_en: i.title_en || 'Instruction',
            description_en: i.description_en || '',
            hasPunjabi: !!(i.title_punjab || i.title_punjabi || i.description_punjab || i.description_punjabi),
            title_punjab: i.title_punjab || i.title_punjabi || '', // Handle both keys just in case
            description_punjab: i.description_punjab || i.description_punjabi || ''
        }));

        // Pickup / Delivery Summaries
        let pickupSummaries: any[] = [];
        let deliverySummaries: any[] = [];
        
        rateCons.forEach(rc => {
             const instrs = rc.rc_dispatch_instructions || [];
             const list = Array.isArray(instrs) ? instrs : (instrs ? [instrs] : []);
             list.forEach((inst: any) => {
                 if (inst.pickup_summary || inst.pickup_summary_punjabi) {
                     pickupSummaries.push({
                         text: inst.pickup_summary,
                         punjabi: inst.pickup_summary_punjabi
                     });
                 }
                 if (inst.delivery_summary || inst.delivery_summary_punjabi) {
                     deliverySummaries.push({
                         text: inst.delivery_summary,
                         punjabi: inst.delivery_summary_punjabi
                     });
                 }
             });
        });

        // Unique by text to avoid dups
        // Simple dedupe by stringifying
        pickupSummaries = [...new Map(pickupSummaries.map(item => [JSON.stringify(item), item])).values()];
        deliverySummaries = [...new Map(deliverySummaries.map(item => [JSON.stringify(item), item])).values()];


        // Rate Cons ID list (using load_id field from new schema)
        const refIds = rateCons.map(r => r.load_id || r.rate_con_id).filter(Boolean).join(', ');

        const templateData = {
            orgLogoUrl,
            orgName,
            orgAddress,
            mcDotNumber,
            tripId: trip_id || '-',
            refIds: refIds,
            brokerName: rateCons.map(r => r.broker_name).filter(Boolean).join(' & '),
            generatedDate: new Date().toLocaleString('en-US', { timeZone: 'America/Los_Angeles' }),
            stops: stopsMapped,
            equipment: combinedDriverView.special_equipment_needed.join(', '),
            transit: combinedDriverView.transit_requirements.join(', '),
            transit_punjabi: combinedDriverView.transit_requirements_punjabi.join(', '),
            instructions: instructionsMapped,
            pickupSummaries,
            deliverySummaries
        };

        const compiledTemplate = Handlebars.compile(dispatchSheetTemplate);
        const htmlContent = compiledTemplate(templateData);

        // ... output to PDF service (rest is unchanged)

        // ---------------------------------------------------------
        // 4. Call PDF Microservice
        // ---------------------------------------------------------
        const folderPath = trip_id
            ? `${organizationId}/${trip_id}/dispatch_documents`
            : `${organizationId}/${contextId}/dispatch_documents`;
        const fileName = `${folderPath}/dispatcher_sheet.pdf`;

        // ... (Calls to fetch and creating document record, same as before)
        console.log(`Calling PDF Service for: ${fileName}`);

        const pdfResponse = await fetch(PDF_SERVICE_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${supabaseServiceKey}`
            },
            body: JSON.stringify({
                bucketName: "documents",
                uploadPath: fileName,
                html: htmlContent,
                css: ""
            })
        });

        if (!pdfResponse.ok) {
            const errText = await pdfResponse.text();
            throw new Error(`PDF Service Failed [${pdfResponse.status}]: ${errText}`);
        }

        const pdfResult = await pdfResponse.json();
        const { data: docRecord, error: docError } = await supabase
            .from('documents')
            .insert({
                organization_id: organizationId,
                trip_id: trip_id || null,
                load_id: load_id || null,
                uploaded_by: profile.id,
                type: 'other',
                image_url: fileName,
                status: 'approved',
                ai_data: { subtype: 'dispatch_sheet', source_id: contextId },
                created_at: new Date().toISOString()
            })
            .select()
            .single();

        if (docError) console.error("Error creating document record:", docError);

        if (trip_id && docRecord) {
            await supabase.from('trips').update({ dispatch_document_id: docRecord.id }).eq('id', trip_id);
        }

        if (load_id) {
            await supabase.from('load_dispatch_config').upsert({
                load_id: load_id,
                organization_id: organizationId,
                generated_sheet_url: fileName,
                updated_at: new Date().toISOString()
            }, { onConflict: 'load_id' });
        }

        const { data: signedUrlData } = await supabase
            .storage
            .from('documents')
            .createSignedUrl(fileName, 30 * 24 * 3600);

        let finalUrl = signedUrlData?.signedUrl || fileName;
        if (finalUrl.includes('http://kong:8000')) {
            finalUrl = finalUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
        }

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