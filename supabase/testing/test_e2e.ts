import { createClient } from '@supabase/supabase-js';
import * as fs from 'node:fs';
import * as path from 'node:path';

// Parse arguments
const args = process.argv.slice(2);
if (args.length < 3) {
    console.error("Usage: npx ts-node test_e2e.ts <PHONE_NUMBER> <OTP> <PDF_PATH>");
    process.exit(1);
}

const [phoneNumber, otp, pdfPath] = args;

// Configuration - Defaults to local Supabase
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltbiIsInJvbGUiOiJYW5vbiIsImlhdCI6MTY2NjY2NjY2NiwiZXhwIjozNzMzMzMzMzMzOH0.K3Z7zI7zI7zI7zI7zI7zI7zI7zI7zI7zI7zI7zI7zI0'; // Default local anon key
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY; // Only needed if we need admin bypass, mostly we act as user

// Function URLs (Local)
const FUNCTIONS_URL = SUPABASE_URL + '/functions/v1';

async function main() {
    console.log(`Starting E2E Test with:
  Phone: ${phoneNumber}
  PDF: ${pdfPath}
  URL: ${SUPABASE_URL}\n`);

    // 1. Initialize Supabase Client
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

    try {
        // 2. Login via Edge Function (auth-otp)
        console.log("-> Sending OTP...");
        const sendResponse = await fetch(`${FUNCTIONS_URL}/auth-otp`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
            },
            body: JSON.stringify({
                action: 'send',
                phone_number: phoneNumber
            })
        });

        if (!sendResponse.ok) {
            throw new Error(`Send OTP failed: ${await sendResponse.text()}`);
        }
        console.log("✅ OTP Sent!");

        console.log("-> Authenticating (Verify OTP)...");
        const loginResponse = await fetch(`${FUNCTIONS_URL}/auth-otp`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
            },
            body: JSON.stringify({
                action: 'verify',
                phone_number: phoneNumber,
                otp: otp
            })
        });

        if (!loginResponse.ok) {
            throw new Error(`Login failed: ${await loginResponse.text()}`);
        }

        const loginData = await loginResponse.json();
        console.log("✅ Authenticated!");

        // Check if session exists in response (as per auth-otp code)
        if (!loginData.session || !loginData.session.access_token) {
            throw new Error("No session returned from login.");
        }

        const accessToken = loginData.session.access_token;
        const organizationId = loginData.profile.organization_id;
        const userId = loginData.user.id;
        console.log(`   User ID: ${userId}`);
        console.log(`   Org ID: ${organizationId}`);

        // Create authenticated client
        const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            global: { headers: { Authorization: `Bearer ${accessToken}` } }
        });

        // 3. Upload File
        console.log("\n-> Uploading Rate Confirmation...");
        if (!fs.existsSync(pdfPath)) {
            throw new Error(`File not found: ${pdfPath}`);
        }
        const fileBuffer = fs.readFileSync(pdfPath);
        const fileName = `rate_cons/${Date.now()}_test.pdf`;
        const storagePath = `${organizationId}/${fileName}`;

        const { data: uploadData, error: uploadError } = await authClient
            .storage
            .from('documents')
            .upload(storagePath, fileBuffer, {
                contentType: 'application/pdf'
            });

        if (uploadError) throw uploadError;
        console.log(`✅ Uploaded to: ${uploadData.path}`);

        // 4. Create Document Record
        console.log("\n-> Creating Document Record...");
        const { data: docRecord, error: docError } = await authClient
            .from('documents')
            .insert({
                organization_id: organizationId,
                type: 'rate_con',
                status: 'pending_review',
                image_url: uploadData.path, // Storage path
                uploaded_by: userId
            })
            .select()
            .single();

        if (docError) throw docError;
        console.log(`✅ Document Record Created: ${docRecord.id}`);

        // 5. Process Document
        console.log("\n-> Processing Document (Call process-document)...");
        const processResponse = await fetch(`${FUNCTIONS_URL}/process-document`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                document_id: docRecord.id,
                document_type: 'rate_con',
                image_url: uploadData.path
            })
        });

        if (!processResponse.ok) {
            throw new Error(`Processing failed: ${await processResponse.text()}`);
        }

        const processData = await processResponse.json();
        console.log("✅ Document Processed!");
        console.log(`   Confidence: ${processData.confidence}`);
        console.log(`   Rate Con ID: ${processData.rate_con_id}`);

        const rateConId = processData.rate_con_id;
        if (!rateConId) throw new Error("No rate_con_id returned from processor.");

        // Verify Rate Con Visibility
        console.log(`\n-> Verifying Rate Con Visibility (ID: ${rateConId})...`);
        const { data: checkRc, error: checkRcError } = await authClient
            .from('rate_confirmations')
            .select('id, organization_id')
            .eq('id', rateConId)
            .single();

        if (checkRcError || !checkRc) {
            console.error("❌ Rate Con NOT visible to user:", checkRcError);
            // We can proceed to see if FK fails, or stop here.
            // Let's stop to make it clear.
            throw new Error(`Rate Con ${rateConId} is not visible to user. RLS Issue?`);
        }
        console.log(`✅ Rate Con Visible. Org: ${checkRc.organization_id}`);

        // 6. Create Load & Trip
        console.log("\n-> Creating Load & Trip...");

        // Create Load
        const { data: load, error: loadError } = await authClient
            .from('loads')
            .insert({
                organization_id: organizationId,
                rate_confirmation_id: rateConId,
                status: 'assigned'
            })
            .select()
            .single();

        if (loadError) throw loadError;
        console.log(`✅ Load Created: ${load.id}`);

        // Create Trip
        const { data: trip, error: tripError } = await authClient
            .from('trips')
            .insert({
                organization_id: organizationId,
                driver_id: userId, // Assigning to self for test
                status: 'active'
            })
            .select()
            .single();

        if (tripError) throw tripError;
        console.log(`✅ Trip Created: ${trip.id}`);

        // Link Trip & Load
        const { error: linkError } = await authClient
            .from('trip_loads')
            .insert({
                trip_id: trip.id,
                load_id: load.id
            });

        if (linkError) throw linkError;
        console.log(`✅ Trip linked to Load.`);

        // 7. Generate Dispatch Sheet
        console.log("\n-> Generating Dispatch Sheet...");
        const dispatchResponse = await fetch(`${FUNCTIONS_URL}/generate-dispatch-sheet`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
                trip_id: trip.id
            })
        });

        if (!dispatchResponse.ok) {
            throw new Error(`Dispatch sheet generation failed: ${await dispatchResponse.text()}`);
        }

        const dispatchData = await dispatchResponse.json();
        console.log("✅ Dispatch Sheet Generated!");
        console.log(`   URL: ${dispatchData.url}`);
        console.log(`   Path: ${dispatchData.path}`);

        console.log("\n🎉 E2E Test Completed Successfully!");

    } catch (err: any) {
        console.error("\n❌ Test Failed:", err.message);
        if (err.cause) console.error("Cause:", err.cause);
        process.exit(1);
    }
}

main();
