#!/usr/bin/env node

/**
 * Script to create a new Supabase user with phone number authentication
 * 
 * Usage: node create-phone-user.js <phone_number> [password]
 * 
 * Examples:
 *   node create-phone-user.js +15551234567
 *   node create-phone-user.js +15551234567 mySecurePassword123
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

function generateRandomPassword(length = 16) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < length; i++) {
        password += charset.charAt(Math.floor(Math.random() * charset.length));
    }
    return password;
}

function getServerInfo(url) {
    try {
        const urlObj = new URL(url);
        const hostname = urlObj.hostname;

        // Detect server type
        if (hostname === 'localhost' || hostname === '127.0.0.1') {
            return { type: 'LOCAL', display: `🏠 Local Development (${url})` };
        } else if (hostname.includes('supabase.co')) {
            const projectRef = hostname.split('.')[0];
            return { type: 'PRODUCTION', display: `☁️  Supabase Cloud (Project: ${projectRef})` };
        } else if (hostname.includes('supabase.in') || hostname.includes('supabase.net')) {
            return { type: 'SELF_HOSTED', display: `🖥️  Self-Hosted Supabase (${hostname})` };
        } else {
            return { type: 'UNKNOWN', display: `🌐 Custom Server (${hostname})` };
        }
    } catch (error) {
        return { type: 'ERROR', display: `❓ Unknown (${url})` };
    }
}

async function createPhoneUser(phoneNumber, password) {
    // Load configuration
    const config = loadConfig();

    const supabaseUrl = config.supabase.project_url;
    const supabaseServiceKey = config.supabase.service_role_key;

    // Display server connection info
    const serverInfo = getServerInfo(supabaseUrl);
    console.log('\n' + '═'.repeat(60));
    console.log('🔌 CONNECTING TO SUPABASE');
    console.log('═'.repeat(60));
    console.log(`   Server: ${serverInfo.display}`);
    console.log(`   URL:    ${supabaseUrl}`);
    console.log('═'.repeat(60));

    if (!supabaseUrl || !supabaseServiceKey) {
        console.error('Error: Supabase URL or service role key not found in config');
        process.exit(1);
    }

    // Create Supabase client with service role key for admin operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
        auth: {
            autoRefreshToken: false,
            persistSession: false
        }
    });

    console.log(`\n📱 Creating user with phone number: ${phoneNumber}`);
    console.log(`🔑 Using password: ${password}\n`);

    try {
        // Use admin API to create user (bypasses email/phone confirmation)
        const { data, error } = await supabase.auth.admin.createUser({
            phone: phoneNumber,
            password: password,
            phone_confirm: true, // Auto-confirm the phone number
            user_metadata: {
                created_via: 'create-phone-user-script',
                created_at: new Date().toISOString()
            }
        });

        if (error) {
            console.error('❌ Error creating user:', error.message);

            // Check if user already exists
            if (error.message.includes('already registered') || error.message.includes('already exists')) {
                console.log('\n💡 Tip: User may already exist. Try a different phone number.');
            }

            process.exit(1);
        }

        console.log('✅ User created successfully!\n');
        console.log('User Details:');
        console.log('─'.repeat(50));
        console.log(`  ID:          ${data.user.id}`);
        console.log(`  Phone:       ${data.user.phone}`);
        console.log(`  Password:    ${password}`);
        console.log(`  Created At:  ${data.user.created_at}`);
        console.log(`  Confirmed:   ${data.user.phone_confirmed_at ? 'Yes' : 'No'}`);
        console.log('─'.repeat(50));

        // Verify user by retrieving from database
        console.log('\n🔍 Verifying user in database...');
        const { data: verifyData, error: verifyError } = await supabase.auth.admin.getUserById(data.user.id);

        if (verifyError) {
            console.error('⚠️  Warning: Could not verify user:', verifyError.message);
        } else if (verifyData && verifyData.user) {
            console.log('✅ User verified! Found in auth.users:');
            console.log('─'.repeat(50));
            console.log(`  ID:              ${verifyData.user.id}`);
            console.log(`  Phone:           ${verifyData.user.phone}`);
            console.log(`  Role:            ${verifyData.user.role || 'N/A'}`);
            console.log(`  Email Confirmed: ${verifyData.user.email_confirmed_at ? 'Yes' : 'No'}`);
            console.log(`  Phone Confirmed: ${verifyData.user.phone_confirmed_at ? 'Yes' : 'No'}`);
            console.log(`  Last Sign In:    ${verifyData.user.last_sign_in_at || 'Never'}`);
            console.log('─'.repeat(50));

            // Also check the public profile
            console.log('\n🔍 Verifying profile in public.profiles...');
            const { data: profileData, error: profileError } = await supabase
                .from('profiles')
                .select('*')
                .eq('id', data.user.id)
                .single();

            if (profileError) {
                console.error('❌ Error: Profile not found in public.profiles! Trigger may have failed.');
                console.error('   Details:', profileError.message);
            } else {
                console.log('✅ Profile verified! Found in public.profiles:');
                console.log('─'.repeat(50));
                console.log(`  ID:           ${profileData.id}`);
                console.log(`  Full Name:    ${profileData.full_name}`);
                console.log(`  Phone:        ${profileData.phone_number}`);
                console.log(`  Role:         ${profileData.role}`);
                console.log(`  Is Active:    ${profileData.is_active}`);
                console.log('─'.repeat(50));
            }

        } else {
            console.error('⚠️  Warning: User not found in database after creation');
        }

        console.log('\n📝 Note: Save the password securely. It cannot be retrieved later.');

        return data.user;
    } catch (error) {
        console.error('❌ Unexpected error:', error.message);
        process.exit(1);
    }
}

// Main execution
async function main() {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        console.log(`
Usage: node create-phone-user.js <phone_number> [password]

Arguments:
  phone_number  Phone number in E.164 format (e.g., +15551234567)
  password      Optional password (auto-generated if not provided)

Examples:
  node create-phone-user.js +15551234567
  node create-phone-user.js +15551234567 mySecurePassword123
  node create-phone-user.js "+1 555 123 4567"
    `);
        process.exit(0);
    }

    // Parse phone number (remove spaces and ensure it starts with +)
    let phoneNumber = args[0].replace(/\s/g, '');
    if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+' + phoneNumber;
    }

    // Validate phone number format (basic validation)
    const phoneRegex = /^\+[1-9]\d{6,14}$/;
    if (!phoneRegex.test(phoneNumber)) {
        console.error(`
❌ Invalid phone number format: ${phoneNumber}

Phone numbers should be in E.164 format:
  - Start with + followed by country code
  - Contain only digits after the +
  - Be between 7 and 15 digits long

Examples: +15551234567, +919876543210
    `);
        process.exit(1);
    }

    // Use provided password or generate one
    const password = args[1] || generateRandomPassword();

    await createPhoneUser(phoneNumber, password);
}

main();
