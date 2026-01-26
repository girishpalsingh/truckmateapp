
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { faker } from "https://esm.sh/@faker-js/faker@8.4.1";

// --- CONFIGURATION ---
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SERVICE_ROLE_KEY) {
    console.error("Error: SUPABASE_SERVICE_ROLE_KEY is required.");
    Deno.exit(1);
}

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const ROLES = ['orgadmin', 'dispatcher', 'driver', 'driver', 'driver', 'manager'];
const TRUCK_MAKES = ['Freightliner', 'Kenworth', 'Peterbilt', 'Volvo', 'International', 'Mack'];
const TRAILER_TYPES = ['Dry Van', 'Reefer', 'Flatbed', 'Step Deck'];

async function seedOrganization(org: any) {
    console.log(`\n🌱 Seeding Organization: ${org.name} (${org.id})`);

    // 1. Seed Users
    console.log(`   Generating Users...`);
    const userProms = ROLES.map(async (role) => {
        const firstName = faker.person.firstName();
        const lastName = faker.person.lastName();
        const email = faker.internet.email({ firstName, lastName }).toLowerCase();

        // Create Auth User
        const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email: email,
            password: "password123",
            email_confirm: true,
            user_metadata: { full_name: `${firstName} ${lastName}` }
        });

        if (authError) {
            console.error(`      Failed to create user ${email}: ${authError.message}`);
            return null;
        }

        const userId = authUser.user.id;

        // Upsert Profile
        const { error: profileError } = await supabaseAdmin.from('profiles').upsert({
            id: userId,
            organization_id: org.id,
            role: role,
            full_name: `${firstName} ${lastName}`,
            email_address: email,
            phone_number: faker.phone.number()
        });

        if (profileError) {
            console.error(`      Failed to create profile for ${userId}: ${profileError.message}`);
        } else {
            // console.log(`      Created ${role}: ${email}`);
        }
        return userId;
    });

    await Promise.all(userProms);
    console.log(`   ✅ Created ~${ROLES.length} users.`);


    // 2. Seed Trucks
    console.log(`   Generating Trucks...`);
    const trucks = Array.from({ length: 5 }).map(() => ({
        organization_id: org.id,
        truck_number: `T-${faker.number.int({ min: 100, max: 999 })}`,
        vin: faker.vehicle.vin(),
        make: faker.helpers.arrayElement(TRUCK_MAKES),
        model: 'Generic Model',
        year: faker.number.int({ min: 2015, max: 2024 }),
        license_plate: faker.vehicle.vrm().substring(0, 8),
        status: 'ACTIVE'
    }));

    const { error: truckError } = await supabaseAdmin.from('trucks').insert(trucks);
    if (truckError) console.error(`   ❌ Truck Error: ${truckError.message}`);
    else console.log(`   ✅ Created ${trucks.length} trucks.`);


    // 3. Seed Trailers
    console.log(`   Generating Trailers...`);
    const trailers = Array.from({ length: 8 }).map(() => ({
        organization_id: org.id,
        trailer_number: `TR-${faker.number.int({ min: 1000, max: 9999 })}`,
        trailer_type: faker.helpers.arrayElement(['DRY_VAN', 'REEFER', 'FLATBED']),
        length_feet: faker.helpers.arrayElement([48, 53]),
        license_plate: faker.vehicle.vrm().substring(0, 8),
        status: 'ACTIVE'
    }));

    const { error: trailerError } = await supabaseAdmin.from('trailers').insert(trailers);
    if (trailerError) console.error(`   ❌ Trailer Error: ${trailerError.message}`);
    else console.log(`   ✅ Created ${trailers.length} trailers.`);

}

async function main() {
    console.log("🚀 Starting Database Seeding...");

    // Fetch all organizations
    const { data: orgs, error } = await supabaseAdmin.from('organizations').select('*');
    if (error) {
        console.error("Failed to fetch organizations:", error);
        Deno.exit(1);
    }

    if (!orgs || orgs.length === 0) {
        console.log("No organizations found to seed.");
        Deno.exit(0);
    }

    console.log(`Found ${orgs.length} organizations.`);

    for (const org of orgs) {
        await seedOrganization(org);
    }

    console.log("\n✅ Database Seeding Complete!");
}

main();
