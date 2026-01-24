import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz';

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

const TEST_PHONE = '1234567880';
const TEST_OTP = '123456'; // Default dev OTP

async function main() {
    console.log("Creating fresh test user...");

    // 1. Delete if exists (cleanup)
    const { data: { users } } = await supabase.auth.admin.listUsers();
    if (users) {
        const existing = users.find(u => u.phone === TEST_PHONE);
        if (existing) {
            console.log("Deleting existing user...");
            await supabase.auth.admin.deleteUser(existing.id);
            // Also cleanup profile
            await supabase.from('profiles').delete().eq('id', existing.id);
        }
    }

    // 2. Create User
    console.log("Creating Auth User...");
    const { data: { user }, error: createError } = await supabase.auth.admin.createUser({
        phone: TEST_PHONE,
        phone_confirm: true,
        user_metadata: { full_name: 'Fresh Test User', role: 'driver' }
    });

    let userId;

    if (createError) {
        if (createError.code === 'phone_exists' || createError.message?.includes('Phone already exists')) {
            console.log("User already exists. Fetching ID from profile...");
            const { data: existingProfile } = await supabase
                .from('profiles')
                .select('id')
                .eq('phone_number', TEST_PHONE)
                .single();

            if (existingProfile) {
                userId = existingProfile.id;
            } else {
                console.error("User exists involved but no profile found!");
                return;
            }
        } else {
            console.error("Error creating user:", createError);
            return;
        }
    } else {
        userId = user?.id;
    }

    if (!userId) {
        console.error("No user ID found!");
        return;
    }
    console.log(`User ID: ${userId}`);

    // 3. Create/Update Profile
    console.log("Creating/Updating Profile...");
    const { error: profileError } = await supabase
        .from('profiles')
        .upsert({
            id: userId,
            organization_id: '11111111-1111-1111-1111-111111111111',
            full_name: 'Fresh Test User',
            phone_number: TEST_PHONE,
            role: 'driver',
            is_active: true
        });

    if (profileError) {
        console.error("Error creating profile:", profileError);
    } else {
        console.log("Profile created successfully!");
    }
}

main();
