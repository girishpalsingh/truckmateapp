#!/usr/bin/env node

/**
 * Script to test dispatch sheet generation
 * 
 * Usage: node test-dispatch-sheet-gen.js <phone_number> [load_id]
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
    if (args.length < 1) {
        console.error('Usage: node test-dispatch-sheet-gen.js <phone_number> [load_id]');
        process.exit(1);
    }

    const phoneNumber = args[0];
    let loadId = args[1];

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
        console.log('OTP sent successfully.');

        // 2. Verify OTP
        console.log(`\nStep 2: Verifying OTP (123456)...`);
        const { data: verifyData, error: verifyError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'verify', phone_number: phoneNumber, otp: '123456' }
        });

        if (verifyError) throw new Error(`Verify OTP failed: ${verifyError.message}`);

        const session = verifyData.session;
        if (!session) throw new Error('Login successful but no session returned.');

        console.log(`Login successful. User: ${session.user.id}`);

        // Set session for subsequent requests
        await supabase.auth.setSession({
            access_token: session.access_token,
            refresh_token: session.refresh_token
        });

        // 3. Find a Load if not provided
        if (!loadId) {
            console.log(`\nStep 3: Finding a valid load...`);
            const { data: loadData, error: loadError } = await supabase
                .from('loads')
                .select('id')
                .limit(1)
                .maybeSingle();

            if (loadError) throw loadError;
            if (!loadData) throw new Error('No loads found in database.');

            loadId = loadData.id;
            console.log(`Found Load ID: ${loadId}`);
        }

        // 4. Generate Dispatch Sheet
        console.log(`\nStep 4: Invoking generate-dispatch-sheet for Load ${loadId}...`);
        const { data: genData, error: genError } = await supabase.functions.invoke('generate-dispatch-sheet', {
            body: { load_id: loadId }
        });

        if (genError) {
            console.error('API Error Details:', JSON.stringify(genError, null, 2));
            // Try to read text response if possible
            if (genError.context && genError.context.text) {
                console.error('Error Body:', await genError.context.text());
            }
            throw new Error(`Generate dispatch sheet failed: ${genError.message}`);
        }

        console.log('\n✅ Dispatch Sheet Generated Successfully!');
        console.log('Response:', JSON.stringify(genData, null, 2));
        console.log(`PDF URL: ${genData.url}`);

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        process.exit(1);
    }
}

main();
