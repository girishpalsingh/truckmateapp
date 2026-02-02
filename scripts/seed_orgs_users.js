const { createClient } = require('@supabase/supabase-js');
const path = require('path');
const fs = require('fs');

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

const config = loadConfig();
const supabaseUrl = config.supabase.project_url;
const supabaseServiceKey = config.supabase.service_role_key;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Error: Supabase URL or service role key not found in config');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

// --- Data Generators ---

const FIRST_NAMES = ['James', 'Robert', 'John', 'Michael', 'David', 'William', 'Richard', 'Joseph', 'Thomas', 'Charles', 'Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen'];
const LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson'];

// Realistic Logistics Companies (5 distinct ones)
const FEATURED_COMPANIES = [
    { name: 'Apex Logistics Solutions', city: 'Atlanta', state: 'GA', zip: '30301' },
    { name: 'Blue Horizon Transport', city: 'Dallas', state: 'TX', zip: '75201' },
    { name: 'Iron Horse Freight', city: 'Chicago', state: 'IL', zip: '60601' },
    { name: 'Velocity Carriers Inc.', city: 'Los Angeles', state: 'CA', zip: '90001' },
    { name: 'North Star Shipping', city: 'Seattle', state: 'WA', zip: '98101' }
];

const STREETS = ['Main St', 'Commerce Blvd', 'Industrial Way', 'Transport Dr', 'Logistics Ln', 'Enterprise Rd'];

function getRandomElement(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function generateName() {
    return `${getRandomElement(FIRST_NAMES)} ${getRandomElement(LAST_NAMES)}`;
}

function generatePhone() {
    // Generate a random 10-digit number
    const number = Math.floor(1000000000 + Math.random() * 9000000000);
    return `+1${number}`;
}

function generateEIN() {
    // XX-YYYYYYY
    const prefix = Math.floor(10 + Math.random() * 90);
    const suffix = Math.floor(1000000 + Math.random() * 9000000);
    return `${prefix}-${suffix}`;
}

function generateAddress(city, state, zip) {
    const num = Math.floor(100 + Math.random() * 899);
    const street = getRandomElement(STREETS);
    return {
        line1: `${num} ${street}`,
        city: city,
        state: state,
        zip_code: zip,
        country: 'USA'
    };
}

// --- Main Seeding Logic ---

async function seedEnhancedDatabase() {
    console.log('🚀 Starting Enhanced Database Seeding...');
    console.log(`Target: 5 Premium Organizations with 20 users each.`);

    for (const company of FEATURED_COMPANIES) {
        console.log(`\n🏢 Processing Company: ${company.name}`);

        const dotNumber = Math.floor(1000000 + Math.random() * 9000000).toString();
        const address = generateAddress(company.city, company.state, company.zip);
        const dasherizedName = company.name.toLowerCase().replace(/[^a-z0-9]/g, '-');
        const website = `https://www.${dasherizedName}.com`;
        const approvalEmail = `approvals@${dasherizedName}.com`;

        // 1. Create Organization with Full Details
        // Check if exists first because mc_dot_number might not have a unique constraint
        const { data: existingOrg } = await supabase
            .from('organizations')
            .select('id')
            .eq('name', company.name)
            .single();

        let org;
        const orgData = {
            name: company.name,
            legal_entity_name: company.name,
            mc_dot_number: dotNumber,
            tax_id: generateEIN(),
            website: website,
            approval_email_address: approvalEmail,
            registered_address: address,
            mailing_address: address,
            is_active: true,
            llm_provider: 'gemini'
        };

        if (existingOrg) {
            const { data: updatedOrg, error: updateError } = await supabase
                .from('organizations')
                .update(orgData)
                .eq('id', existingOrg.id)
                .select()
                .single();

            if (updateError) {
                console.error(`❌ Error updating org ${company.name}:`, updateError.message);
                continue;
            }
            org = updatedOrg;
            console.log(`   ✅ Organization Updated: ${org.id}`);
        } else {
            const { data: newOrg, error: insertError } = await supabase
                .from('organizations')
                .insert(orgData)
                .select()
                .single();

            if (insertError) {
                console.error(`❌ Error creating org ${company.name}:`, insertError.message);
                continue;
            }
            org = newOrg;
            console.log(`   ✅ Organization Created: ${org.id}`);
        }

        // 2. Create Users
        let ownerId = null;
        let ownerCreated = false;
        let managerCount = 0;
        let dispatcherCount = 0;

        const USERS_PER_ORG = 20;

        for (let j = 0; j < USERS_PER_ORG; j++) {
            const fullName = generateName();
            // Use a clean email format: {role}_{org_prefix}_{index}@example.com
            // org prefix from ID first 8 chars
            const orgPrefix = org.id.split('-')[0];

            // Determine Role
            let role = 'driver';
            if (!ownerCreated) {
                role = 'owner';
            } else if (managerCount < 2) {
                role = 'manager';
            } else if (dispatcherCount < 5) {
                role = 'dispatcher';
            }

            // Update counts *after* assignment to keep logic clean or create specific email
            const email = `${role}_${orgPrefix}_${j}@example.com`;
            const phone = generatePhone();
            const password = 'password123';

            // Create Auth User
            const { data: authData, error: authError } = await supabase.auth.admin.createUser({
                email: email,
                phone: phone,
                password: password,
                email_confirm: true,
                phone_confirm: true,
                user_metadata: { full_name: fullName }
            });

            let userId;
            if (authError) {
                // If user exists, try to get existing ID via admin.listUsers? Overkill.
                // We'll assumes duplicate email means user exists, we might not have ID easily without query.
                // For now, if "already registered", we skip *unless* we want to fix their profile.
                // To fix profile of existing user, we need their ID. 
                // Since we don't have easy lookup by email in admin API without listing all, we might skip.
                // BUT: for OWNER, we really need the ID to update the Org.
                if (authError.message.includes('already registered')) {
                    // Since we can't easily get the ID, we log a warning. 
                    // In a real prod fix script, we'd list users filtering by email.
                    // console.log(`   ⚠️ User ${email} already exists.`);
                } else {
                    console.error(`   ❌ Auth Error for ${email}:`, authError.message);
                }
                // If we failed to get ID (because we didn't create it), we can't upsert profile easily.
                // So we continue. 
                continue;
            } else {
                userId = authData.user.id;
            }

            if (!userId) continue;

            // 3. Upsert Profile
            const { error: profileError } = await supabase
                .from('profiles')
                .upsert({
                    id: userId,
                    organization_id: org.id,
                    role: role,
                    full_name: fullName,
                    phone_number: phone,
                    email_address: email,
                    address: {
                        line1: '123 Driver Ln',
                        city: company.city,
                        state: company.state,
                        zip: company.zip
                    },
                    is_active: true
                });

            if (profileError) {
                console.error(`   ❌ Profile Error for ${email}:`, profileError.message);
            }

            // 4. If Owner, Update Organization admin_id and set flag
            if (role === 'owner') {
                ownerId = userId;
                ownerCreated = true;

                const { error: updateOrgError } = await supabase
                    .from('organizations')
                    .update({ admin_id: ownerId })
                    .eq('id', org.id);

                if (updateOrgError) {
                    console.error(`   ❌ Failed to set admin_id for org:`, updateOrgError.message);
                } else {
                    console.log(`   � Org Admin Linked: ${email}`);
                }
            } else if (role === 'manager') {
                managerCount++;
            } else if (role === 'dispatcher') {
                dispatcherCount++;
            }

            // Progress log
            if (j === 0 || j === USERS_PER_ORG - 1) {
                console.log(`   👤 Processed ${role}: ${email}`);
            }
        }
        console.log(`   ✨ Completed ${company.name}`);
    }

    console.log('\n🔍 Verifying Totals...');
    const { count: orgCount } = await supabase.from('organizations').select('*', { count: 'exact', head: true });
    const { count: profileCount } = await supabase.from('profiles').select('*', { count: 'exact', head: true });
    console.log(`Total Orgs in DB: ${orgCount}`);
    console.log(`Total Profiles in DB: ${profileCount}`);
}

seedEnhancedDatabase();
