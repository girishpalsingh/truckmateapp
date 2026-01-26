import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// --- CONFIGURATION ---
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SERVICE_ROLE_KEY) {
    console.error("Error: SUPABASE_SERVICE_ROLE_KEY is required.");
    Deno.exit(1);
}

// Admin client for setup/cleanup only
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Configs
const TEST_PHONE = "1234567880"; // Must match config.toml [auth.sms.test_otp]
const TEST_OTP = "123456";
const NYC = { lat: 40.7128, lng: -74.0060 };
const BOS = { lat: 42.3601, lng: -71.0589 };

// --- HELPERS ---
function interpolatePoints(start: { lat: number, lng: number }, end: { lat: number, lng: number }, steps: number) {
    const points = [];
    for (let i = 0; i <= steps; i++) {
        const ratio = i / steps;
        points.push({
            lat: start.lat + (end.lat - start.lat) * ratio,
            lng: start.lng + (end.lng - start.lng) * ratio
        });
    }
    return points;
}

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

async function step(name: string, fn: () => Promise<any>) {
    console.log(`\n🔹 STEP: ${name}`);
    try {
        const result = await fn();
        console.log(`   ✅ Success`);
        return result;
    } catch (e) {
        console.error(`   ❌ FAILED: ${e.message}`);
        console.error(e);
        Deno.exit(1);
    }
}

async function main() {
    console.log("🚀 Starting End-to-End Journey Workflow Test");

    // Read Config for Anon Key
    const configText = await Deno.readTextFile("config/app_config.json");
    const config = JSON.parse(configText);
    const ANON_KEY = config.supabase.anon_key;
    const PROJECT_URL = config.supabase.project_url;

    // Global State
    let supabaseUser: any;
    let userId: string;
    let organizationId: string;
    let documentId: string;
    let rateConId: string;
    let loadId: string;
    let tripId: string;

    // 1. Login
    await step("Login with Phone/OTP", async () => {
        // Init client with ANON key
        const client = createClient(SUPABASE_URL, ANON_KEY);

        // SignIn
        console.log(`   Sending OTP to ${TEST_PHONE}...`);
        const { error: signInError } = await client.auth.signInWithOtp({
            phone: TEST_PHONE
        });
        if (signInError) throw signInError;

        console.log(`   Verifying OTP ${TEST_OTP}...`);
        const { data: sessionData, error: verifyError } = await client.auth.verifyOtp({
            phone: TEST_PHONE,
            token: TEST_OTP,
            type: 'sms'
        });

        if (verifyError) throw verifyError;
        if (!sessionData.session) throw new Error("No session returned");

        // Create authenticated client
        supabaseUser = createClient(SUPABASE_URL, ANON_KEY, {
            global: { headers: { Authorization: `Bearer ${sessionData.session.access_token}` } }
        });

        userId = sessionData.user.id;
        console.log(`   User Logged In: ${userId}`);

        // Ensure Profile & Org (using Admin to guarantee setup if new user)
        // Check if profile exists
        const { data: profile } = await supabaseAdmin.from('profiles').select('*').eq('id', userId).single();
        if (!profile) {
            console.log("   Creating Profile & Org...");
            const { data: org } = await supabaseAdmin.from('organizations').insert({
                name: "Test Trucking Co",
                mc_dot_number: "123456"
            }).select().single();
            if (!org) throw new Error("Failed to create org");

            await supabaseAdmin.from('profiles').insert({
                id: userId,
                organization_id: org.id,
                role: 'driver',
                full_name: 'Test Driver Phone',
                phone_number: TEST_PHONE
            });
            organizationId = org.id;
        } else {
            if (!profile.organization_id) {
                // Fix org ?? 
                // Just create one
                const { data: org } = await supabaseAdmin.from('organizations').insert({ name: "Fixed Org" }).select().single();
                await supabaseAdmin.from('profiles').update({ organization_id: org.id }).eq('id', userId);
                organizationId = org.id;
            } else {
                organizationId = profile.organization_id;
            }
        }
        console.log(`   Organization ID: ${organizationId}`);
    });

    // 2. Upload & Process Document
    await step("Process Rate Confirmation (Mock)", async () => {
        // Ensure bucket exists
        await supabaseAdmin.storage.createBucket('documents', { public: false }); // Ignore error if exists

        // Upload dummy PDF
        const fileName = `test_rc_${Date.now()}.pdf`;
        const filePath = `${organizationId}/uploads/${fileName}`;

        // Read local dummy.pdf
        let fileBody;
        try {
            fileBody = await Deno.readFile("supabase/testing/dummy.pdf");
        } catch (e) {
            // Create dummy content if missing
            fileBody = new TextEncoder().encode("Dummy PDF Content");
        }

        console.log(`   Uploading ${fileName}...`);
        const { error: uploadError } = await supabaseUser.storage
            .from('documents')
            .upload(filePath, fileBody, { contentType: 'application/pdf' });

        if (uploadError) throw uploadError;

        // Insert Document Record
        console.log("   Inserting Document Record...");
        const { data: doc, error: docError } = await supabaseUser.from('documents').insert({
            organization_id: organizationId,
            type: 'rate_con',
            status: 'pending_review',
            image_url: filePath,
            uploaded_by: userId // Required for notifications
            // Note: process-document expects 'image_url' in body to be reference to storage path?
        }).select().single();

        if (docError) throw docError;
        documentId = doc.id;
        console.log(`   Document ID: ${documentId}`);

        // Call Process Function
        console.log("   Invoking process-document...");
        const { data: procData, error: procError } = await supabaseUser.functions.invoke('process-document', {
            body: {
                document_id: documentId,
                document_type: 'rate_con',
                image_url: filePath
            }
        });

        if (procError) throw procError;
        console.log(`   Process Response:`, procData);

        if (!procData.rate_con_id) throw new Error("No rate_con_id returned from processing");
        rateConId = procData.rate_con_id;
    });

    // 3. Create Trip (Client Logic)
    await step("Create Trip from Rate Con", async () => {
        // 1. Create Load
        console.log("   Creating Load...");
        const { data: load, error: loadError } = await supabaseUser.from('loads').insert({
            organization_id: organizationId,
            rate_confirmation_id: rateConId,
            status: 'assigned'
        }).select().single();

        if (loadError) throw loadError;
        loadId = load.id;
        console.log(`   Load ID: ${loadId}`);

        // 2. Create Trip
        console.log("   Creating Trip...");
        const { data: trip, error: tripError } = await supabaseUser.from('trips').insert({
            organization_id: organizationId,
            load_id: loadId,
            driver_id: userId,
            status: 'deadhead', // Initial status
            origin_address: "New York, NY", // Mocked from RC?
            destination_address: "Boston, MA"
        }).select().single();

        if (tripError) throw tripError;
        tripId = trip.id;
        console.log(`   Trip ID: ${tripId}`);
    });

    // 4. Generate Dispatch Sheet
    await step("Generate Dispatch Sheet", async () => {
        const { data, error } = await supabaseUser.functions.invoke('generate-dispatch-sheet', {
            body: {
                trip_id: tripId,
                load_id: loadId
            }
        });

        if (error) throw error;
        console.log("   Dispatch Sheet Response:", data);
        if (!data.success) throw new Error("Dispatch Sheet generation reported failure");
    });

    // 5. Start Trip & Record Locations
    await step("Start Trip & Simulate Journey", async () => {
        // Start Trip
        console.log("   Starting Trip (Status -> active)...");
        const { error: updateError } = await supabaseUser.from('trips')
            .update({ status: 'active', odometer_start: 10000 })
            .eq('id', tripId);

        if (updateError) throw updateError;

        // Register Device (Needed for record-location?)
        // The record-location function takes device_id.
        // Let's ensure a device exists for this user.
        // We'll upsert one.
        const deviceId = "test-device-phone-1";
        const { data: device, error: devError } = await supabaseAdmin.from('devices').upsert({
            user_id: userId,
            organization_id: organizationId,
            device_fingerprint: "fingerprint-1",
            device_type: 'script',
            // id: deviceId // Don't force ID, let it generate or match fingerprint
        }, { onConflict: 'device_fingerprint' })
            .select()
            .single();

        if (devError) throw devError;
        const finalDeviceId = device.id;

        // Loop Locations
        const points = interpolatePoints(NYC, BOS, 10);

        console.log(`   Recording ${points.length} locations...`);
        for (let i = 0; i < points.length; i++) {
            const point = points[i];
            const payload = {
                trip_id: tripId,
                device_id: finalDeviceId,
                latitude: point.lat,
                longitude: point.lng,
                speed: 65,
                heading: 45,
                accuracy: 5,
                altitude: 10,
                timestamp: new Date().toISOString()
            };

            // Invoke record-location
            // Note: Using `invoke` automatically handles Auth header for the user!
            const { data: locData, error: locError } = await supabaseUser.functions.invoke('record-location', {
                body: payload
            });

            if (locError) {
                console.error(`   Failed to record point ${i}:`, locError);
                // We fail fast? User said: "failure of any step will mean next step is not executed".
                // This is inside the step. I will throw.
                throw locError;
            }
            // console.log(`   Point ${i} OK`);
            await sleep(200); // Slight delay
        }
    });

    console.log("\n✅ WORKFLOW COMPLETE");

    // Serve Map
    console.log("\nLast Step: Visualization");
    const port = 6500;
    const handler = async (req: Request): Promise<Response> => {
        const url = new URL(req.url);
        if (url.pathname === "/") {
            const html = await Deno.readTextFile("supabase/testing/journey_map.html");
            return new Response(html, { headers: { "content-type": "text/html" } });
        }
        return new Response("Not Found", { status: 404 });
    };

    console.log(`> View Map at: http://localhost:${port}/?url=${encodeURIComponent(PROJECT_URL || SUPABASE_URL)}&key=${ANON_KEY}&trip_id=${tripId}`);
    await Deno.serve({ port }, handler);
}

main();
