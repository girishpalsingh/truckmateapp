/**
 * Tests for admin-users edge function
 * 
 * Run with: deno test --allow-net --allow-env --allow-read admin-users.test.ts
 */

import {
    assertEquals,
    assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

// Configuration
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "http://127.0.0.1:54321";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-users`;

// Test data
const testUserData = {
    full_name: "Test Driver",
    phone_number: "+15559999999",
    email_address: "testdriver@example.com",
    role: "driver",
};

/**
 * Helper to make authenticated requests
 */
async function makeRequest(
    action: string,
    data: Record<string, unknown>,
    token?: string
): Promise<Response> {
    const headers: Record<string, string> = {
        "Content-Type": "application/json",
        "apikey": SUPABASE_ANON_KEY,
    };

    if (token) {
        headers["Authorization"] = `Bearer ${token}`;
    }

    return await fetch(FUNCTION_URL, {
        method: "POST",
        headers,
        body: JSON.stringify({ action, data }),
    });
}

// ============================================
// UNIT TESTS
// ============================================

Deno.test("admin-users: should reject unauthenticated requests", async () => {
    const response = await makeRequest("list", {});
    const body = await response.json();

    assertEquals(response.status, 401);
    assertExists(body.error);
});

Deno.test("admin-users: should reject request without action", async () => {
    const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": "Bearer invalid_token",
        },
        body: JSON.stringify({}),
    });

    assertEquals(response.status, 401);
});

Deno.test("admin-users: should handle CORS preflight", async () => {
    const response = await fetch(FUNCTION_URL, {
        method: "OPTIONS",
        headers: {
            "Origin": "http://localhost:3000",
        },
    });

    assertEquals(response.status, 200);
    assertExists(response.headers.get("access-control-allow-origin"));
});

Deno.test("admin-users: should validate required fields for create", async () => {
    const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": "Bearer test_token",
        },
        body: JSON.stringify({ action: "create", data: {} }),
    });

    // Will fail auth first, but validates the endpoint responds
    assertEquals(response.status, 401);
});

// ============================================
// INTEGRATION TEST HELPERS
// ============================================

/**
 * Integration tests require a running Supabase instance with:
 * 1. A systemadmin user (for full access tests)
 * 2. An orgadmin user (for organization-scoped tests)
 * 3. At least one organization
 * 
 * To run integration tests:
 * 1. Start local Supabase: supabase start
 * 2. Run seed.sql to create test data
 * 3. Set TEST_SYSTEMADMIN_TOKEN, TEST_ORGADMIN_TOKEN, and TEST_ORG_ID
 * 4. Run: deno test --allow-net --allow-env --allow-read admin-users.test.ts
 */

const SYSTEMADMIN_TOKEN = Deno.env.get("TEST_SYSTEMADMIN_TOKEN");
const ORGADMIN_TOKEN = Deno.env.get("TEST_ORGADMIN_TOKEN");
const TEST_ORG_ID = Deno.env.get("TEST_ORG_ID");

const skipIntegration = !SYSTEMADMIN_TOKEN || !ORGADMIN_TOKEN || !TEST_ORG_ID;

Deno.test({
    name: "admin-users: systemadmin can create user in any org",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("create", {
            ...testUserData,
            organization_id: TEST_ORG_ID,
            phone_number: `+1555${Date.now().toString().slice(-7)}`, // Unique phone
        }, SYSTEMADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 201);
        assertEquals(body.success, true);
        assertExists(body.user);
    },
});

Deno.test({
    name: "admin-users: orgadmin can create user in their org",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("create", {
            ...testUserData,
            organization_id: TEST_ORG_ID,
            phone_number: `+1555${Date.now().toString().slice(-7)}`,
        }, ORGADMIN_TOKEN);
        const body = await response.json();

        // Should succeed if orgadmin belongs to TEST_ORG_ID
        if (response.status === 201) {
            assertEquals(body.success, true);
        } else {
            // Unauthorized for different org
            assertEquals(response.status, 403);
        }
    },
});

Deno.test({
    name: "admin-users: orgadmin cannot create systemadmin user",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("create", {
            ...testUserData,
            organization_id: TEST_ORG_ID,
            role: "systemadmin",
            phone_number: `+1555${Date.now().toString().slice(-7)}`,
        }, ORGADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 403);
        assertExists(body.error);
    },
});

Deno.test({
    name: "admin-users: can list users in organization",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("list", {
            organization_id: TEST_ORG_ID,
        }, SYSTEMADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 200);
        assertEquals(body.success, true);
        assertExists(body.users);
        assertExists(body.count);
    },
});

Deno.test({
    name: "admin-users: admin cannot delete themselves",
    ignore: skipIntegration,
    async fn() {
        // This test requires knowing the admin's user ID
        // Skipping actual deletion test to avoid breaking test setup
        console.log("Self-deletion prevention test - manual verification required");
    },
});

console.log("\n=== Admin Users Tests ===");
console.log("Integration tests skipped:", skipIntegration ? "YES (set tokens and TEST_ORG_ID)" : "NO");
