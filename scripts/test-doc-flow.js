#!/usr/bin/env node

/**
 * Script to test document upload flow
 * 
 * Usage: node test-doc-flow.js <phone_number> <file_path>
 * 
 * Flow:
 * 1. Login user via auth-otp (send + verify)
 * 2. Upload file to 'documents' bucket
 * 3. Create record in 'documents' table
 * 4. Call process-document edge function
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
        console.error('Usage: node test-doc-flow.js <phone_number> <file_path>');
        process.exit(1);
    }

    const phoneNumber = args[0];
    const filePath = args[1];

    if (!fs.existsSync(filePath)) {
        console.error(`File not found: ${filePath}`);
        process.exit(1);
    }

    const config = loadConfig();
    const supabaseUrl = config.supabase.project_url;
    const supabaseAnonKey = config.supabase.anon_key;

    console.log(`Using Supabase URL: ${supabaseUrl}`);

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    try {
        // 1. Login (Send OTP)
        console.log(`\nStep 1: Sending OTP to ${phoneNumber}...`);
        const { data: sendData, error: sendError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'send', phone_number: phoneNumber }
        });

        if (sendError) throw new Error(`Send OTP failed: ${sendError.message}`);
        if (sendData && sendData.error) throw new Error(`Send OTP API error: ${sendData.error}`);
        console.log('OTP sent successfully.');

        // 2. Verify OTP
        console.log(`\nStep 2: Verifying OTP (123456)...`);
        const { data: verifyData, error: verifyError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'verify', phone_number: phoneNumber, otp: '123456' }
        });

        if (verifyError) throw new Error(`Verify OTP failed: ${verifyError.message}`);
        if (verifyData && verifyData.error) throw new Error(`Verify OTP API error: ${verifyData.error}`);

        const session = verifyData.session;
        const organization = verifyData.organization;

        if (!session || !organization) {
            throw new Error('Login successful but no session or organization returned.');
        }

        console.log(`Login successful. User: ${session.user.id}, Org: ${organization.id}`);

        // Set session for subsequent requests
        await supabase.auth.setSession({
            access_token: session.access_token,
            refresh_token: session.refresh_token
        });

        // 3. Upload File
        console.log(`\nStep 3: Uploading file: ${filePath}...`);
        const fileContent = fs.readFileSync(filePath);
        const fileName = path.basename(filePath);
        const timestamp = Date.now();
        const storagePath = `${organization.id}/${timestamp}_${fileName}`;

        // Detect Mime Type
        const ext = path.extname(filePath).toLowerCase();
        let contentType = 'application/octet-stream';
        if (ext === '.jpg' || ext === '.jpeg') contentType = 'image/jpeg';
        else if (ext === '.png') contentType = 'image/png';
        else if (ext === '.pdf') contentType = 'application/pdf';

        console.log(`Using content type: ${contentType}`);

        const { data: uploadData, error: uploadError } = await supabase
            .storage
            .from('documents')
            .upload(storagePath, fileContent, {
                contentType: contentType,
                upsert: false
            });

        if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);
        console.log(`File uploaded to: ${storagePath}`);

        // 4. Insert into documents table
        console.log(`\nStep 4: Creating database record...`);
        const { data: docData, error: docError } = await supabase
            .from('documents')
            .insert({
                organization_id: organization.id,
                uploaded_by: session.user.id,
                type: 'rate_con', // Defaulting to rate_con for test
                image_url: storagePath,
                status: 'pending_review',
                updated_at: new Date().toISOString()
            })
            .select()
            .single();

        if (docError) throw new Error(`Database insert failed: ${docError.message}`);
        console.log(`Document record created. ID: ${docData.id}`);

        // 5. Call process-document API
        console.log(`\nStep 5: Invoking process-document...`);
        const { data: processData, error: processError } = await supabase.functions.invoke('process-document', {
            body: {
                document_id: docData.id,
                document_type: 'rate_con',
                image_url: storagePath
            }
        });

        if (processError) {
            console.error('Process Error Details:', JSON.stringify(processError, null, 2));
            if (processError && processError.context && processError.context.text) {
                const text = await processError.context.text();
                console.error('Error Body:', text);
            }
            throw new Error(`Process document failed: ${processError.message}`);
        }
        if (processData && processData.error) throw new Error(`Process document API error: ${processData.error}`);

        console.log('\n✅ Document processing initiated/completed!');
        console.log('Response:', JSON.stringify(processData, null, 2));

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        process.exit(1);
    }
}

main();
