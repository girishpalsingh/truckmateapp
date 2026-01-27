import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import { assert, assertEquals, assertExists } from "https://deno.land/std@0.168.0/testing/asserts.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    Deno.exit(1);
}

// Admin Client
const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Helper: Setup Test Driver
async function setupTestDriver() {
    const email = `test_driver_${Date.now()}@example.com`;
    const password = "password123";

    // 1. Create User
    const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true
    });
    if (createError) throw createError;
    const userId = userData.user.id;

    // 2. Create Organization
    const { data: org, error: orgError } = await supabaseAdmin.from('organizations').insert({
        name: 'Test Org Driver ' + Date.now(),
        mc_dot_number: '7654321'
    }).select().single();
    if (orgError) throw orgError;
    const orgId = org.id;

    // 3. Update Profile (Driver)
    // Note: Assuming trigger creates profile, update it to 'driver'
    const { error: profileError } = await supabaseAdmin.from('profiles').update({
        organization_id: orgId,
        role: 'driver', // explicitly DRIVER
        full_name: 'Test Driver',
        phone_number: '2' + Date.now().toString().slice(-9)
    }).eq('id', userId);
    if (profileError) throw profileError;

    // 4. Sign In
    const { data: sessionData, error: loginError } = await supabaseAdmin.auth.signInWithPassword({
        email,
        password
    });
    if (loginError) throw loginError;

    return {
        user: sessionData.user,
        client: createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
            global: { headers: { Authorization: `Bearer ${sessionData.session?.access_token}` } }
        }),
        orgId
    };
}

Deno.test("Driver Rate Con Flow", async (t) => {
    let testContext: any;

    await t.step("Setup Driver", async () => {
        testContext = await setupTestDriver();
    });

    const { client, orgId, user } = testContext;
    let rateConId: string;
    let documentId: string;

    await t.step("Create Document (as Driver)", async () => {
        // Driver uploads document
        const id = crypto.randomUUID();
        const { data, error } = await client.from('documents').insert({
            id: id,
            organization_id: orgId,
            status: 'pending_review',
            type: 'rate_con',
            image_url: 'dummy/driver.pdf',
            uploaded_by: user.id
        }).select().single();

        if (error) throw error;
        documentId = data.id;
    });

    await t.step("Create Pending Rate Con (as Driver)", async () => {
        // Driver processes/creates rate con (simulated)
        // Ensure created_by is set to user.id
        const id = crypto.randomUUID();
        const { data, error } = await supabaseAdmin.from('rate_confirmations').insert({
            id: id,
            organization_id: orgId,
            broker_name: 'Driver Broker',
            load_id: 'LOAD-DRV-' + Date.now(),
            total_rate: 2000.00,
            status: 'pending',
            document_id: documentId,
            created_by: user.id // IMPORTANT: Must match driver ID
        }).select().single();

        if (error) throw error;
        rateConId = data.id;
    });

    await t.step("Accept Rate Con (as Driver)", async () => {
        const { data, error } = await client.functions.invoke('process-rate-con-response', {
            body: {
                rate_con_id: rateConId,
                action: 'accept',
                edits: {
                    broker_name: 'Driver Accepted Broker'
                }
            }
        });

        if (error) {
            console.error("Edge Function Invoke Error:", error);
            // Check if error has context property which is a Response
            if ((error as any).context && (error as any).context instanceof Response) {
                try {
                    const response = (error as any).context as Response;
                    const text = await response.text();
                    console.error("Error Body Text:", text);
                } catch (e) {
                    console.error("Could not parse error body", e);
                }
            }
            throw error;
        }

        assertExists(data.load_id);
    });
});
