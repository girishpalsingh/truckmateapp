const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const configPath = path.join(__dirname, '..', 'config', 'app_config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const supabase = createClient(config.supabase.project_url, config.supabase.service_role_key);

async function listAssets() {
    console.log("Listing files in 'assets' bucket...");
    const { data, error } = await supabase.storage.from('assets').list();

    if (error) {
        console.error("Error listing assets:", error);
    } else {
        console.log("Files found:", data);
    }
}

listAssets();
