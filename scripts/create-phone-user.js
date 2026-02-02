const { exec } = require('child_process');
const { createClient } = require('@supabase/supabase-js');

// 1. Get Phone Number from Command Line
const phoneNumber = process.argv[2];

if (!phoneNumber) {
    console.error('❌ Error: Please provide a phone number.');
    console.error('Usage: node create-phone-user.js <PHONE_NUMBER> [ROLE] [FULL_NAME]');
    process.exit(1);
}

const role = process.argv[3] || 'driver';
const fullName = process.argv[4] || 'Test Phone User';

console.log('🔄 Fetching credentials from "supabase status"...');

// 2. Execute 'supabase status' to get credentials
exec('supabase status', async (error, stdout, stderr) => {
    if (error) {
        console.error(`❌ Error running supabase status: ${error.message}`);
        console.error('Make sure Supabase is running (supabase start).');
        return;
    }

    try {
        // 3. Parse the output
        const apiUrlMatch = stdout.match(/Project URL\s+│\s+(http:\/\/[0-9.]+:[0-9]+)/);
        const secretKeyMatch = stdout.match(/Secret\s+│\s+([^\s│]+)/);

        if (!apiUrlMatch || !secretKeyMatch) {
            throw new Error('Could not parse "Project URL" or "Secret" from supabase status output.');
        }

        const supabaseUrl = apiUrlMatch[1].trim();
        const serviceRoleKey = secretKeyMatch[1].trim();

        console.log(`✅ Credentials found.`);
        console.log(`   URL: ${supabaseUrl}`);

        // 4. Initialize Supabase Admin Client
        const supabase = createClient(supabaseUrl, serviceRoleKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false
            }
        });

        // 5. Get a random existing organization
        const { data: orgs, error: orgError } = await supabase
            .from('organizations')
            .select('id')
            .limit(100);

        if (orgError) throw new Error(`Failed to fetch organizations: ${orgError.message}`);
        if (!orgs || orgs.length === 0) throw new Error('No organizations found. Please run seed_orgs_users.js first.');

        const randomOrg = orgs[Math.floor(Math.random() * orgs.length)];
        console.log(`🏢 Selected Organization: ${randomOrg.id}`);

        console.log(`\nCreating user: ${phoneNumber}...`);

        // 6. Create the User via Admin API
        let userId;
        const { data, error: createError } = await supabase.auth.admin.createUser({
            phone: phoneNumber,
            phone_confirmed_at: new Date().toISOString(),
            user_metadata: {
                full_name: fullName,
                phone_number: phoneNumber
            }
        });

        if (createError) {
            // If user already exists, we try to fetch them to update profile
            if (createError.message.includes('already registered') || createError.status === 422) {
                console.log('⚠️ User already exists. Attempting to find user...');
                const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
                if (listError) throw listError;

                const existingUser = users.find(u => u.phone === phoneNumber);
                if (!existingUser) {
                    throw new Error('User reported existing but not found in list.');
                }
                userId = existingUser.id;
                console.log(`✅ Found existing user ID: ${userId}`);
            } else {
                throw createError;
            }
        } else {
            userId = data.user.id;
            console.log('✅ User created successfully!');
            console.log('   User ID:', userId);
        }

        // 7. Insert/Upsert into Profiles
        // We use upsert to ensure we update existing profiles too
        const { error: profileError } = await supabase
            .from('profiles')
            .upsert({
                id: userId,
                organization_id: randomOrg.id,
                role: role,
                full_name: fullName,
                phone_number: phoneNumber,
                is_active: true,
                updated_at: new Date().toISOString()
            });

        if (profileError) {
            throw new Error(`Failed to create/update profile: ${profileError.message}`);
        }

        console.log('✅ Profile created/updated successfully!');
        console.log(`   Role: ${role}`);
        console.log(`   Organization: ${randomOrg.id}`);
        console.log(`   Full Name: ${fullName}`);

    } catch (err) {
        console.error('❌ Script failed:', err.message);
        process.exit(1);
    }
});
