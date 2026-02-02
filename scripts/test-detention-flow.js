#!/usr/bin/env node

/**
 * Test script for detention invoice flow
 * 
 * Tests the complete detention workflow:
 * 1. Authenticate with phone+OTP
 * 2. Create a mock detention record
 * 3. Create a detention invoice
 * 
 * Usage: node test-detention-flow.js [phone_number]
 * Default phone: 15550000001 (test user)
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const configPath = path.join(__dirname, '..', 'config', 'app_config.json');
const DEFAULT_PHONE = '15550000001';
const DEFAULT_OTP = '123456';

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
    const phoneNumber = args[0] || DEFAULT_PHONE;

    const config = loadConfig();
    const supabaseUrl = config.supabase.project_url;
    const supabaseAnonKey = config.supabase.anon_key;

    console.log('='.repeat(60));
    console.log('DETENTION INVOICE FLOW TEST');
    console.log('='.repeat(60));
    console.log(`Supabase URL: ${supabaseUrl}`);
    console.log(`Phone: ${phoneNumber}`);
    console.log('');

    const supabase = createClient(supabaseUrl, supabaseAnonKey);

    try {
        // ============================================
        // Step 1: Authenticate
        // ============================================
        console.log('📱 Step 1: Authenticating...');
        
        // Send OTP
        const { error: sendError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'send', phone_number: phoneNumber }
        });
        if (sendError) throw new Error(`Send OTP failed: ${sendError.message}`);
        console.log('   OTP sent successfully');

        // Verify OTP
        const { data: verifyData, error: verifyError } = await supabase.functions.invoke('auth-otp', {
            body: { action: 'verify', phone_number: phoneNumber, otp: DEFAULT_OTP }
        });
        if (verifyError) throw new Error(`Verify OTP failed: ${verifyError.message}`);

        const session = verifyData.session;
        if (!session) throw new Error('Login successful but no session returned');

        console.log(`   ✅ Authenticated as: ${session.user.id}`);

        // Set session for subsequent requests
        await supabase.auth.setSession({
            access_token: session.access_token,
            refresh_token: session.refresh_token
        });

        // Get user profile for org_id
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', session.user.id)
            .single();
        
        if (profileError) throw profileError;
        console.log(`   Organization: ${profile.organization_id}`);
        console.log('');

        // ============================================
        // Step 2: Find or create test data
        // ============================================
        console.log('🔍 Step 2: Finding test data...');

        // Find a load to use
        const { data: loads, error: loadError } = await supabase
            .from('loads')
            .select('id, broker_load_id, broker_name')
            .eq('organization_id', profile.organization_id)
            .limit(1);
        
        if (loadError) throw loadError;
        
        let loadId;
        if (loads && loads.length > 0) {
            loadId = loads[0].id;
            console.log(`   Found Load: ${loads[0].broker_load_id || loadId}`);
        } else {
            console.log('   ⚠️  No loads found. Creating mock load...');
            // For testing, we'll skip this - you should have test data
            throw new Error('No loads found. Please seed test data first.');
        }
        console.log('');

        // ============================================
        // Step 3: Create detention record
        // ============================================
        console.log('⏱️  Step 3: Creating detention record...');

        // Check for existing active detention
        const { data: existingDetention } = await supabase
            .from('detention_records')
            .select('*')
            .eq('load_id', loadId)
            .is('end_time', null)
            .maybeSingle();

        let detentionRecordId;
        if (existingDetention) {
            console.log('   Found existing active detention, using it...');
            detentionRecordId = existingDetention.id;
            
            // If it doesn't have end_time, stop it
            if (!existingDetention.end_time) {
                const { error: stopError } = await supabase
                    .from('detention_records')
                    .update({
                        end_time: new Date().toISOString(),
                        end_location_lat: 37.7749,
                        end_location_lng: -122.4194
                    })
                    .eq('id', detentionRecordId);
                
                if (stopError) throw stopError;
                console.log('   Stopped the detention');
            }
        } else {
            // Create new detention record for testing
            const startTime = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(); // 3 hours ago
            const endTime = new Date().toISOString();

            const { data: newDetention, error: detError } = await supabase
                .from('detention_records')
                .insert({
                    organization_id: profile.organization_id,
                    load_id: loadId,
                    start_time: startTime,
                    start_location_lat: 37.7749,
                    start_location_lng: -122.4194,
                    end_time: endTime,
                    end_location_lat: 37.7750,
                    end_location_lng: -122.4195,
                    evidence_photo_url: null,
                    evidence_photo_time: startTime
                })
                .select()
                .single();

            if (detError) throw detError;
            detentionRecordId = newDetention.id;
            console.log(`   Created detention record: ${detentionRecordId}`);
        }
        console.log('');

        // ============================================
        // Step 4: Create detention invoice  
        // Now only requires detention_record_id - everything auto-calculated!
        // ============================================
        console.log('📄 Step 4: Creating detention invoice...');
        console.log('   (Rate, hours, facility all auto-calculated from database)');

        const { data: invoiceResult, error: invoiceError } = await supabase.functions.invoke('create-detention-invoice', {
            body: {
                detention_record_id: detentionRecordId,
                // Optional overrides (all these are auto-calculated if not provided):
                // stop_id: <stop_id>,                  // Optional: specific stop
                // invoice_details: { rate_per_hour },  // Optional: override rate
                send_email: false // Set to true to test email sending
            }
        });

        if (invoiceError) {
            console.error('Invoice Error:', JSON.stringify(invoiceError, null, 2));
            throw new Error(`Invoice creation failed: ${invoiceError.message}`);
        }

        console.log('   ✅ Invoice created successfully!');
        console.log('');
        console.log('='.repeat(60));
        console.log('RESULT:');
        console.log('='.repeat(60));
        console.log(JSON.stringify(invoiceResult, null, 2));
        console.log('');
        
        if (invoiceResult.url) {
            console.log(`📥 Download PDF: ${invoiceResult.url}`);
        }

        // ============================================
        // Step 5: Display Last Invoice Details
        // ============================================
        console.log('');
        console.log('='.repeat(60));
        console.log('📄 LAST DETENTION INVOICE');
        console.log('='.repeat(60));

        // Fetch last detention invoice for this org
        const { data: lastInvoice, error: invoicesError } = await supabase
            .from('detention_invoices')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .order('created_at', { ascending: false })
            .limit(1)
            .single();

        if (invoicesError) {
            console.log('   ⚠️  Error fetching invoice:', invoicesError.message);
        } else if (lastInvoice) {
            console.log('');
            console.log(`   Invoice #:     ${lastInvoice.invoice_number || lastInvoice.detention_invoice_display_number}`);
            console.log(`   Status:        ${lastInvoice.status}`);
            console.log(`   Total Due:     $${lastInvoice.total_due} ${lastInvoice.currency || 'USD'}`);
            console.log(`   Rate:          $${lastInvoice.rate_per_hour}/hr`);
            console.log(`   Hours:         ${lastInvoice.total_hours?.toFixed(2)} total, ${lastInvoice.payable_hours?.toFixed(2)} billable`);
            console.log(`   Facility:      ${lastInvoice.facility_name || 'N/A'}`);
            console.log(`   Address:       ${lastInvoice.facility_address || 'N/A'}`);
            console.log(`   Created:       ${new Date(lastInvoice.created_at).toLocaleString()}`);
            console.log('');
            
            // Generate signed URL for PDF
            if (lastInvoice.pdf_url) {
                const { data: signedUrl } = await supabase.storage
                    .from('documents')
                    .createSignedUrl(lastInvoice.pdf_url, 3600);
                
                if (signedUrl) {
                    console.log('📥 PDF Link:');
                    console.log(`   ${signedUrl.signedUrl}`);
                }
            }
        }

        console.log('');
        console.log('='.repeat(60));
        console.log('✅ TEST COMPLETED SUCCESSFULLY');
        console.log('='.repeat(60));

    } catch (error) {
        console.error('');
        console.error('❌ TEST FAILED:', error.message);
        console.error('');
        if (error.stack) {
            console.error('Stack:', error.stack);
        }
        process.exit(1);
    }
}

main();

