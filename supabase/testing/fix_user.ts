import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz';

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function main() {
    console.log("Fixing user profile...");
    const { error } = await supabase
        .from('profiles')
        .update({ organization_id: '11111111-1111-1111-1111-111111111111' }) // Highway Heroes
        .eq('phone_number', '+15551234567');

    if (error) {
        console.error("Error updating profile:", error);
    } else {
        console.log("Profile updated successfully!");
    }
}

main();
