/**
 * Comprehensive Seed Script for TruckMate
 * 
 * Creates 10 trucking organizations using the admin-organizations edge function,
 * then uses each organization's auto-created orgadmin to add 50 users.
 * 
 * Usage:
 *   # Start Supabase and serve functions first
 *   supabase start
 *   supabase functions serve
 *   
 *   # Run the seed script
 *   deno run --allow-net --allow-env --allow-read seed-organizations-users.ts
 * 
 * Requirements:
 * - Supabase running locally
 * - Edge functions served (supabase functions serve)
 * - A systemadmin user with valid JWT token (from seed.sql)
 */

// Configuration
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "http://127.0.0.1:54321";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ||
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";

const ORG_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-organizations`;
const USER_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-users`;

// Default password for development (matches config)
const DEV_PASSWORD = "123456Password!";

// ============================================
// REALISTIC TRUCKING COMPANY DATA
// ============================================

const ORGANIZATIONS = [
    {
        name: "Summit Logistics Group",
        legal_entity_name: "Summit Logistics Group Inc.",
        mc_dot_number: "MC-100001",
        tax_id: "10-0001234",
        approval_email_address: "invoices@summitlogistics.com",
    },
    {
        name: "Heartland Express Carriers",
        legal_entity_name: "Heartland Express Carriers LLC",
        mc_dot_number: "MC-100002",
        tax_id: "10-0002345",
        approval_email_address: "billing@heartlandexpress.com",
    },
    {
        name: "Coastal Freight Solutions",
        legal_entity_name: "Coastal Freight Solutions Corp",
        mc_dot_number: "MC-100003",
        tax_id: "10-0003456",
        approval_email_address: "accounts@coastalfreight.com",
    },
    {
        name: "Mountain Ridge Transport",
        legal_entity_name: "Mountain Ridge Transport Inc.",
        mc_dot_number: "MC-100004",
        tax_id: "10-0004567",
        approval_email_address: "invoices@mountainridge.com",
    },
    {
        name: "Prairie Wind Trucking",
        legal_entity_name: "Prairie Wind Trucking LLC",
        mc_dot_number: "MC-100005",
        tax_id: "10-0005678",
        approval_email_address: "billing@prairiewind.com",
    },
    {
        name: "Northern Star Freight",
        legal_entity_name: "Northern Star Freight Inc.",
        mc_dot_number: "MC-100006",
        tax_id: "10-0006789",
        approval_email_address: "invoices@northernstar.com",
    },
    {
        name: "Desert Highway Carriers",
        legal_entity_name: "Desert Highway Carriers LLC",
        mc_dot_number: "MC-100007",
        tax_id: "10-0007890",
        approval_email_address: "accounts@deserthighway.com",
    },
    {
        name: "Lakeside Hauling Co",
        legal_entity_name: "Lakeside Hauling Company",
        mc_dot_number: "MC-100008",
        tax_id: "10-0008901",
        approval_email_address: "billing@lakesidehauling.com",
    },
    {
        name: "Valley View Logistics",
        legal_entity_name: "Valley View Logistics Inc.",
        mc_dot_number: "MC-100009",
        tax_id: "10-0009012",
        approval_email_address: "invoices@valleyview.com",
    },
    {
        name: "Ironwood Transport Services",
        legal_entity_name: "Ironwood Transport Services LLC",
        mc_dot_number: "MC-100010",
        tax_id: "10-0010123",
        approval_email_address: "accounts@ironwoodtransport.com",
    },
];

// Realistic user names representing diverse trucking workforce
const USER_NAMES = [
    // Managers & Dispatchers
    { first: "James", last: "Morrison" },
    { first: "Patricia", last: "Williams" },
    { first: "Michael", last: "Chen" },
    { first: "Sarah", last: "Johnson" },
    { first: "Robert", last: "Garcia" },
    { first: "Emily", last: "Davis" },
    { first: "David", last: "Martinez" },
    { first: "Jennifer", last: "Anderson" },
    { first: "William", last: "Taylor" },
    { first: "Linda", last: "Thomas" },
    // Drivers - Diverse workforce
    { first: "Harpreet", last: "Singh" },
    { first: "Carlos", last: "Rodriguez" },
    { first: "Jaswinder", last: "Kaur" },
    { first: "Mohammad", last: "Ali" },
    { first: "Gurpreet", last: "Dhillon" },
    { first: "Jose", last: "Hernandez" },
    { first: "Balwinder", last: "Sandhu" },
    { first: "Manjit", last: "Gill" },
    { first: "Antonio", last: "Lopez" },
    { first: "Kulwinder", last: "Brar" },
    { first: "John", last: "Smith" },
    { first: "Amarjit", last: "Sidhu" },
    { first: "Francisco", last: "Gonzalez" },
    { first: "Rajinder", last: "Pal" },
    { first: "Miguel", last: "Ramirez" },
    { first: "Paramjit", last: "Johal" },
    { first: "Christopher", last: "Brown" },
    { first: "Sukhwinder", last: "Cheema" },
    { first: "Daniel", last: "Wilson" },
    { first: "Davinder", last: "Dhaliwal" },
    { first: "Kevin", last: "Thompson" },
    { first: "Jagdeep", last: "Mann" },
    { first: "Richard", last: "White" },
    { first: "Tejinder", last: "Atwal" },
    { first: "Brian", last: "Harris" },
    { first: "Narinder", last: "Grewal" },
    { first: "Steven", last: "Martin" },
    { first: "Lakhvir", last: "Bajwa" },
    { first: "Mark", last: "Jackson" },
    { first: "Jatinder", last: "Hundal" },
    // More drivers
    { first: "Paul", last: "Lee" },
    { first: "Satnam", last: "Khangura" },
    { first: "Jason", last: "Walker" },
    { first: "Harminder", last: "Sahota" },
    { first: "Edward", last: "Hall" },
    { first: "Baljit", last: "Randhawa" },
    { first: "Thomas", last: "Allen" },
    { first: "Mohinder", last: "Tatla" },
    { first: "Charles", last: "Young" },
    { first: "Sukhpal", last: "Virk" },
];

// Role distribution for 50 users per org
const ROLE_DISTRIBUTION = [
    // 1 orgadmin (created automatically with org)
    { role: "owner", count: 1 },
    { role: "manager", count: 3 },
    { role: "dispatcher", count: 5 },
    { role: "driver", count: 40 }, // 50 - 1(orgadmin) - 1(owner) - 3(managers) - 5(dispatchers) = 40
];

// ============================================
// API HELPERS
// ============================================

interface OrgResponse {
    success?: boolean;
    error?: string;
    organization?: { id: string; name: string };
    orgadmin?: { id: string; email: string; password?: string };
}

interface UserResponse {
    success?: boolean;
    error?: string;
    user?: { id: string; full_name: string };
}

interface LoginResponse {
    access_token?: string;
    error?: string;
}

/**
 * Logs in as systemadmin to get auth token
 */
async function loginAsSystemAdmin(): Promise<string> {
    console.log("🔐 Logging in as systemadmin...");

    const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({
            email: "systemadmin@truckmate.app",
            password: "SystemAdmin123!",
        }),
    });

    const data: LoginResponse = await response.json();

    if (!data.access_token) {
        throw new Error(`Failed to login as systemadmin: ${data.error || "No token returned"}`);
    }

    console.log("   ✅ Logged in successfully\n");
    return data.access_token;
}

/**
 * Logs in with email/password
 */
async function loginWithPassword(email: string, password: string): Promise<string> {
    const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
        },
        body: JSON.stringify({ email, password }),
    });

    const data: LoginResponse = await response.json();

    if (!data.access_token) {
        throw new Error(`Login failed for ${email}: ${data.error || "No token"}`);
    }

    return data.access_token;
}

/**
 * Creates organization via edge function
 */
async function createOrganization(
    token: string,
    orgData: typeof ORGANIZATIONS[0]
): Promise<OrgResponse> {
    const response = await fetch(ORG_FUNCTION_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
            action: "create",
            data: { ...orgData, llm_provider: "gemini" },
        }),
    });

    return await response.json();
}

/**
 * Creates user via edge function
 */
async function createUser(
    token: string,
    userData: {
        organization_id: string;
        full_name: string;
        email_address: string;
        phone_number: string;
        role: string;
    }
): Promise<UserResponse> {
    const response = await fetch(USER_FUNCTION_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
            action: "create",
            data: userData,
        }),
    });

    return await response.json();
}

/**
 * Generates email from name and org
 */
function generateEmail(first: string, last: string, orgSlug: string): string {
    return `${first.toLowerCase()}.${last.toLowerCase()}@${orgSlug}.truckmate.app`;
}

/**
 * Generates phone number
 */
function generatePhone(orgIndex: number, userIndex: number): string {
    const area = 555;
    const prefix = 200 + orgIndex;
    const suffix = 1000 + userIndex;
    return `+1${area}${prefix}${suffix}`;
}

/**
 * Creates org slug from name
 */
function slugify(name: string): string {
    return name.toLowerCase().replace(/[^a-z0-9]+/g, "").slice(0, 15);
}

// ============================================
// MAIN SEEDING LOGIC
// ============================================

async function main(): Promise<void> {
    console.log("╔════════════════════════════════════════════════════════════╗");
    console.log("║         TruckMate Comprehensive Seed Script                ║");
    console.log("║   Creates 10 Organizations + 50 Users Each = 500 Users     ║");
    console.log("╚════════════════════════════════════════════════════════════╝\n");

    console.log(`🔧 Configuration:`);
    console.log(`   Supabase URL: ${SUPABASE_URL}`);
    console.log(`   Org Function: ${ORG_FUNCTION_URL}`);
    console.log(`   User Function: ${USER_FUNCTION_URL}\n`);

    try {
        // Step 1: Login as systemadmin
        const systemAdminToken = await loginAsSystemAdmin();

        let totalOrgsCreated = 0;
        let totalUsersCreated = 0;

        // Step 2: Create organizations
        console.log("📦 Creating Organizations (with auto-orgadmin)...\n");

        const createdOrgs: Array<{
            id: string;
            name: string;
            slug: string;
            adminEmail: string;
            adminPassword: string;
        }> = [];

        for (const org of ORGANIZATIONS) {
            console.log(`  Creating: ${org.name}`);

            const result = await createOrganization(systemAdminToken, org);

            if (result.success && result.organization && result.orgadmin) {
                console.log(`    ✅ Created with orgadmin: ${result.orgadmin.email}`);
                createdOrgs.push({
                    id: result.organization.id,
                    name: org.name,
                    slug: slugify(org.name),
                    adminEmail: result.orgadmin.email,
                    adminPassword: result.orgadmin.password || DEV_PASSWORD,
                });
                totalOrgsCreated++;
            } else {
                console.log(`    ❌ Error: ${result.error}`);
            }
        }

        console.log(`\n✅ Created ${totalOrgsCreated} organizations\n`);

        // Step 3: For each org, login as orgadmin and create 50 users
        console.log("👥 Creating Users for Each Organization...\n");

        for (const org of createdOrgs) {
            console.log(`\n  Organization: ${org.name}`);
            console.log(`  Logging in as orgadmin: ${org.adminEmail}`);

            let orgAdminToken: string;
            try {
                orgAdminToken = await loginWithPassword(org.adminEmail, org.adminPassword);
                console.log(`    ✅ Logged in as orgadmin`);
            } catch (e) {
                console.log(`    ❌ Login failed: ${e instanceof Error ? e.message : e}`);
                continue;
            }

            let orgUserCount = 0;
            let userNameIndex = 0;

            // Create users based on role distribution (excluding orgadmin which is auto-created)
            for (const roleDist of ROLE_DISTRIBUTION) {
                for (let i = 0; i < roleDist.count; i++) {
                    if (userNameIndex >= USER_NAMES.length) {
                        userNameIndex = 0; // Cycle through names if we run out
                    }

                    const name = USER_NAMES[userNameIndex++];
                    const fullName = `${name.first} ${name.last}`;
                    const email = generateEmail(name.first, name.last, org.slug);
                    const phone = generatePhone(createdOrgs.indexOf(org), orgUserCount);

                    const result = await createUser(orgAdminToken, {
                        organization_id: org.id,
                        full_name: fullName,
                        email_address: email,
                        phone_number: phone,
                        role: roleDist.role,
                    });

                    if (result.success) {
                        orgUserCount++;
                        totalUsersCreated++;

                        // Progress indicator every 10 users
                        if (orgUserCount % 10 === 0) {
                            console.log(`    → Created ${orgUserCount} users...`);
                        }
                    } else {
                        console.log(`    ❌ Failed to create ${fullName}: ${result.error}`);
                    }
                }
            }

            console.log(`    ✅ Created ${orgUserCount} users for ${org.name}`);
        }

        // Summary
        console.log("\n╔════════════════════════════════════════════════════════════╗");
        console.log("║                    SEED COMPLETE                           ║");
        console.log("╠════════════════════════════════════════════════════════════╣");
        console.log(`║  Organizations Created:  ${String(totalOrgsCreated).padStart(3)}                            ║`);
        console.log(`║  Users Created:          ${String(totalUsersCreated).padStart(3)}                            ║`);
        console.log(`║  Total Users per Org:     50 (1 orgadmin + 49 others)      ║`);
        console.log("╚════════════════════════════════════════════════════════════╝");

        // Print summary of created organizations
        console.log("\n📋 Created Organizations Summary:");
        for (const org of createdOrgs) {
            console.log(`   - ${org.name}`);
            console.log(`     Admin: ${org.adminEmail} / ${org.adminPassword}`);
        }

    } catch (error: unknown) {
        console.error("\n❌ Seed failed:", error instanceof Error ? error.message : String(error));
        Deno.exit(1);
    }
}

// Run the script
main();
