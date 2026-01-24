const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const configPath = path.join(__dirname, '..', 'config', 'app_config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Use Service Role Key to bypass RLS for this admin task
const supabase = createClient(config.supabase.project_url, config.supabase.service_role_key);

async function updateLogo() {
    const orgId = '11111111-1111-1111-1111-111111111111';
    const logoPath = 'Gemini_Generated_Image_oqnanioqnanioqna.png';
    const address = {
        "address_line1": "123 Trucker Lane",
        "city": "Fresno",
        "state": "CA",
        "zip": "93706",
        "country": "USA"
    };

    console.log(`Updating Organization ${orgId} with logo: ${logoPath}`);

    const { data, error } = await supabase
        .from('organizations')
        .update({
            logo_image_link: logoPath,
            registered_address: address,
            mailing_address: address
        })
        .eq('id', orgId)
        .select();

    if (error) {
        console.error("Error updating organization:", error);
    } else {
        console.log("Success! Updated data:", data);
    }
}

updateLogo();
