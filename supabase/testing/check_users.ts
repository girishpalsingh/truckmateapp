import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz'; // From app_config.json

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function main() {
    console.log("Checking users...");
    const { data: { users }, error } = await supabase.auth.admin.listUsers();

    if (error) {
        console.error("Error listing users:", error);
    } else {
        console.log(`Found ${users.length} users.`);
        users.forEach(u => console.log(`- ${u.id} (${u.phone || u.email})`));
    }

    console.log("\nChecking profile for +15551234567...");
    const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('phone_number', '+15551234567')
        .single();

    if (profileError) console.error("Error getting profile:", profileError);
    else console.log("Profile found:", profile);
}

main();
