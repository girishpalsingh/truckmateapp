#!/usr/bin/env node

/**
 * Script to test full dispatcher sheet flow
 * 
 * Usage: node test-dispatcher-sheet-flow.js <phone_number> <file_path>
 * 
 * Flow:
 * 1. Login user via auth-otp (send + verify)
 * 2. Upload file to 'documents' bucket
 * 3. Create record in 'documents' table
 * 4. Call process-document edge function -> returns rate_con_id
 * 5. Create Load record linked to rate_con
 * 6. Create Trip record
 * 7. Create Trip_Load linkage
 * 8. Call generate-dispatch-sheet edge function
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Read Supabase credentials from config
const configPath = path.join(__dirname, '..', 'config', 'app_config.json');

function loadConfig() {
    try {
        const configData = fs.readFileSync(configPath, 'utf8');
        return JSON.parse(configData);
    } catch (error) {
        console.error(`Error reading config file at ${configPath}:`, error.message);
        process.exit(1);
    }
}

async function main() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error('Usage: node test-dispatcher-sheet-flow.js <phone_number> <file_path>');
        process.exit(1);
    }

    const phoneNumber = args[0];
    const filePath = args[1];
    const defaultOtp = '123456';

    if (!fs.existsSync(filePath)) {
        console.error(`File not found: ${filePath}`);
        process.exit(1);
    }

    console.log(`\n🚀 Starting Dispatcher Sheet Flow Test`);
    console.log(`   Phone: ${phoneNumber}`);
    console.log(`   File:  ${filePath}\n`);

    const config = loadConfig();
    const supabaseUrl = config.supabase.project_url;
    const supabaseAnonKey = config.supabase.anon_key;

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    try {
        // -------------------------------------------------------------
        // Step 1: Login
        // -------------------------------------------------------------
        console.log(`[1/8] 🔐 Authenticating ${phoneNumber}...`);

        // A. Send OTP
        const { error: sendError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'send', phone_number: phoneNumber }
        });
        if (sendError) throw new Error(`Send OTP failed: ${sendError.message}`);

        // B. Verify OTP
        const { data: verifyData, error: verifyError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'verify', phone_number: phoneNumber, otp: defaultOtp }
        });

        if (verifyError) throw new Error(`Verify OTP failed: ${verifyError.message}`);
        if (!verifyData.session || !verifyData.organization) {
            throw new Error('Login successful but missing session or organization data.');
        }

        const session = verifyData.session;
        const organization = verifyData.organization;
        const userId = session.user.id;
        const orgId = organization.id;

        console.log(`      ✅ Authenticated. User: ${userId.slice(0, 8)}..., Org: ${orgId}`);

        // Set session for subsequent requests (RLS)
        await supabase.auth.setSession({
            access_token: session.access_token,
            refresh_token: session.refresh_token
        });

        // -------------------------------------------------------------
        // Step 2: Upload File
        // -------------------------------------------------------------
        console.log(`[2/8] 📤 Uploading document...`);
        const fileContent = fs.readFileSync(filePath);
        const fileName = path.basename(filePath);
        const timestamp = Date.now();
        const storagePath = `${orgId}/${timestamp}_${fileName}`;

        // Detect Mime Type
        const ext = path.extname(filePath).toLowerCase();
        let contentType = 'application/octet-stream';
        if (ext === '.jpg' || ext === '.jpeg') contentType = 'image/jpeg';
        else if (ext === '.png') contentType = 'image/png';
        else if (ext === '.pdf') contentType = 'application/pdf';

        const { error: uploadError } = await supabase.storage
            .from('documents')
            .upload(storagePath, fileContent, { contentType, upsert: false });

        if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);
        console.log(`      ✅ Uploaded to ${storagePath}`);

        // -------------------------------------------------------------
        // Step 3: Create Document Record
        // -------------------------------------------------------------
        console.log(`[3/8] 📝 Creating document record...`);
        const { data: docData, error: docError } = await supabase
            .from('documents')
            .insert({
                organization_id: orgId,
                uploaded_by: userId,
                type: 'rate_con',
                image_url: storagePath,
                status: 'pending_review'
            })
            .select()
            .single();

        if (docError) throw new Error(`Document record creation failed: ${docError.message}`);
        console.log(`      ✅ Document ID: ${docData.id}`);

        // -------------------------------------------------------------
        // Step 4: Process Document (Extract Rate Con)
        // -------------------------------------------------------------
        console.log(`[4/8] 🤖 Processing document (AI Extraction)...`);
        const { data: processData, error: processError } = await supabase.functions.invoke('process-document', {
            body: {
                document_id: docData.id,
                document_type: 'rate_con',
                image_url: storagePath
            }
        });

        if (processError) throw new Error(`Process function failed: ${processError.message}`);
        if (processData.error) throw new Error(`Process function returned error: ${processData.error}`);

        const rateConId = processData.rate_con_id;
        if (!rateConId) throw new Error('Process function did not return a rate_con_id');

        console.log(`      ✅ Processed. Rate Con ID: ${rateConId}`);
        console.log(`         Confidence: ${processData.confidence}, Model: ${processData.llm_provider}`);

        // -------------------------------------------------------------
        // Step 5: Create Load
        // -------------------------------------------------------------
        console.log(`[5/8] 🚚 Creating Load...`);
        // We create a load linked to this rate confirmation
        const { data: loadData, error: loadError } = await supabase
            .from('loads')
            .insert({
                organization_id: orgId,
                rate_confirmation_id: rateConId,
                status: 'assigned',

                // Add some dummy data required for a valid load if strictly checked, 
                // though schema says most fields are nullable except org_id
                broker_name: 'Test Broker From Script',
                primary_rate: 1500.00
            })
            .select()
            .single();

        if (loadError) throw new Error(`Load creation failed: ${loadError.message}`);
        console.log(`      ✅ Load created. ID: ${loadData.id}`);

        // -------------------------------------------------------------
        // Step 6: Create Trip
        // -------------------------------------------------------------
        console.log(`[6/8] 🛣️  Creating Trip...`);
        const { data: tripData, error: tripError } = await supabase
            .from('trips')
            .insert({
                organization_id: orgId,
                status: 'active',
                driver_id: userId, // Assigning to current user/driver

                // Dummy/Default data
                origin_address: 'Test Origin, CA',
                destination_address: 'Test Destination, NV',
                notes: 'Generated via test script'
            })
            .select()
            .single();

        if (tripError) throw new Error(`Trip creation failed: ${tripError.message}`);
        console.log(`      ✅ Trip created. ID: ${tripData.id}`);

        // -------------------------------------------------------------
        // Step 7: Link Trip & Load
        // -------------------------------------------------------------
        console.log(`[7/8] 🔗 Linking Trip & Load...`);
        const { error: linkError } = await supabase
            .from('trip_loads')
            .insert({
                trip_id: tripData.id,
                load_id: loadData.id
            });

        if (linkError) throw new Error(`Linking trip & load failed: ${linkError.message}`);
        console.log(`      ✅ Linked successfully.`);

        // -------------------------------------------------------------
        // Step 8: Generate Dispatcher Sheet
        // -------------------------------------------------------------
        console.log(`[8/8] 📄 Generating Dispatcher Sheet...`);
        const { data: sheetData, error: sheetError } = await supabase.functions.invoke('generate-dispatch-sheet', {
            body: {
                trip_id: tripData.id
                // load_id is optional if trip_id is provided, function handles it
            }
        });

        if (sheetError) {
            console.error('Sheet Generation Error Details:', JSON.stringify(sheetError, null, 2));
            if (sheetError.context && typeof sheetError.context.text === 'function') {
                try {
                    const text = await sheetError.context.text();
                    console.error('Sheet Generation Error Body:', text);
                } catch (e) {
                    console.error('Could not read error body:', e);
                }
            }
            throw new Error(`Docs generation failed: ${sheetError.message}`);
        }
        if (sheetData && sheetData.error) throw new Error(`Docs generation API error: ${sheetData.error}`);

        console.log(`      ✅ Dispatch Sheet Generated!`);
        console.log(`\n🎉 Success!`);
        console.log(`   URL:  ${sheetData.url}`);
        console.log(`   Path: ${sheetData.path}`);
        console.log(`   DocID:${sheetData.document_id}`);

        if (sheetData.html_debug) {
            console.log(`\n--- DEBUG: GENERATED HTML START ---`);
            // console.log(sheetData.html_debug); // Too verbose, writing to file instead
            const debugHtmlPath = path.join(__dirname, '..', 'dispatcher_sheet_debug.html');
            fs.writeFileSync(debugHtmlPath, sheetData.html_debug);
            console.log(`--- DEBUG: SAVED HTML TO ${debugHtmlPath} ---`);
        }
        console.log(`\n-------------------------------------------------------------\n`);

    } catch (error) {
        console.error(`\n❌ Error: ${error.message}`);
        if (error.cause) console.error(error.cause);
        process.exit(1);
    }
}

main();
