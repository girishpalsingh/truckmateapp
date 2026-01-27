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

// Helper: Setup Test User
async function setupTestUser() {
    const email = `test_dispatcher_${Date.now()}@example.com`;
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
        name: 'Test Org ' + Date.now(),
        mc_dot_number: '1234567'
    }).select().single();
    if (orgError) throw orgError;
    const orgId = org.id;

    // 3. Update Profile (Dispatcher) - Trigger likely created it
    const { error: profileError } = await supabaseAdmin.from('profiles').update({
        organization_id: orgId,
        role: 'dispatcher',
        full_name: 'Test Dispatcher',
        phone_number: '1' + Date.now().toString().slice(-9) // Unique phone
    }).eq('id', userId);
    if (profileError) throw profileError;

    // 4. Sign In to get Token
    const { data: sessionData, error: loginError } = await supabaseAdmin.auth.signInWithPassword({
        email,
        password
    });
    if (loginError) throw loginError;

    return {
        user: sessionData.user,
        session: sessionData.session,
        orgId,
        client: createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
            global: { headers: { Authorization: `Bearer ${sessionData.session?.access_token}` } }
        })
    };
}

// Encapsulate Test
Deno.test("Rate Con Flow", async (t) => {
    let testContext: any;

    await t.step("Setup User", async () => {
        testContext = await setupTestUser();
        console.log(`User created: ${testContext.user.id}, Org: ${testContext.orgId}`);
    });

    const { client, orgId, user } = testContext;
    let rateConId: string;
    let documentId: string;

    await t.step("Create Document", async () => {
        const id = crypto.randomUUID();
        const { data, error } = await supabaseAdmin.from('documents').insert({
            id: id,
            organization_id: orgId,
            status: 'pending_review',
            type: 'rate_con',
            image_url: 'dummy/path.pdf',
            uploaded_by: user.id
        }).select().single();

        if (error) throw error;
        documentId = data.id;
        console.log(`Document Created: ${documentId}`);
    });

    await t.step("Create Pending Rate Con", async () => {
        const id = crypto.randomUUID();
        const { data, error } = await supabaseAdmin.from('rate_confirmations').insert({
            id: id,
            organization_id: orgId,
            broker_name: 'Test Broker',
            load_id: 'LOAD-' + Date.now(),
            total_rate: 1500.00,
            status: 'pending',
            document_id: documentId
        }).select().single();

        if (error) {
            console.error("Create RC Error", error);
            throw error;
        }
        rateConId = data.id;
        console.log(`Rate Con Created: ${rateConId}`);
    });

    await t.step("Accept Rate Con", async () => {
        // Use client with user token
        const { data, error } = await client.functions.invoke('process-rate-con-response', {
            body: {
                rate_con_id: rateConId,
                action: 'accept',
                edits: {
                    broker_name: 'Accepted Broker'
                }
            }
        });

        if (error) {
            console.error("Edge Func Error", error);
            throw error;
        }
        console.log("Edge Func Result:", data);

        assertExists(data.load_id);
    });

    await t.step("Verify Load Created", async () => {
        // Check Load
        // To verify correct linking, we look for load with active_rate_con_id matching the serial ID of our RC
        const { data: rc } = await supabaseAdmin.from('rate_confirmations').select().eq('id', rateConId).single();
        assertEquals(rc.status, 'approved');
        assertEquals(rc.broker_name, 'Accepted Broker');

        const { data: loadCheck } = await supabaseAdmin.from('loads')
            .select()
            .eq('active_rate_con_id', rc.rc_id)
            .single();

        assertExists(loadCheck, "Load should exist for RC Serial ID " + rc.rc_id);
        assertEquals(loadCheck.status, 'created');
        assertEquals(loadCheck.broker_name, 'Accepted Broker');
        assertEquals(loadCheck.organization_id, orgId);
    });
});
