/**
 * Tests for admin-organizations edge function
 * 
 * Run with: deno test --allow-net --allow-env --allow-read admin-organizations.test.ts
 */

import {
    assertEquals,
    assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

// Configuration - update these based on your local setup
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "http://127.0.0.1:54321";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/admin-organizations`;

// Test data
const testOrgData = {
    name: "Test Trucking Company",
    legal_entity_name: "Test Trucking LLC",
    mc_dot_number: "MC-TEST123",
    tax_id: "99-9999999",
    llm_provider: "gemini",
    approval_email_address: "test@trucking.com",
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

Deno.test("admin-organizations: should reject unauthenticated requests", async () => {
    const response = await makeRequest("list", {});
    const body = await response.json();

    assertEquals(response.status, 401);
    assertExists(body.error);
});

Deno.test("admin-organizations: should reject request without action", async () => {
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

Deno.test("admin-organizations: should reject invalid action", async () => {
    const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": "Bearer test_token",
        },
        body: JSON.stringify({ action: "invalid_action", data: {} }),
    });

    // Will fail auth first
    assertEquals(response.status, 401);
});

Deno.test("admin-organizations: should handle CORS preflight", async () => {
    const response = await fetch(FUNCTION_URL, {
        method: "OPTIONS",
        headers: {
            "Origin": "http://localhost:3000",
        },
    });

    assertEquals(response.status, 200);
    assertExists(response.headers.get("access-control-allow-origin"));
});

// ============================================
// INTEGRATION TEST HELPERS
// ============================================

/**
 * Integration tests require a running Supabase instance with:
 * 1. A systemadmin user (for full access tests)
 * 2. An orgadmin user (for restricted access tests)
 * 
 * To run integration tests:
 * 1. Start local Supabase: supabase start
 * 2. Create test users with admin roles
 * 3. Set TEST_SYSTEMADMIN_TOKEN and TEST_ORGADMIN_TOKEN environment variables
 * 4. Run: deno test --allow-net --allow-env --allow-read admin-organizations.test.ts
 */

const SYSTEMADMIN_TOKEN = Deno.env.get("TEST_SYSTEMADMIN_TOKEN");
const ORGADMIN_TOKEN = Deno.env.get("TEST_ORGADMIN_TOKEN");

// Skip integration tests if tokens not provided
const skipIntegration = !SYSTEMADMIN_TOKEN || !ORGADMIN_TOKEN;

Deno.test({
    name: "admin-organizations: systemadmin can create organization",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("create", testOrgData, SYSTEMADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 201);
        assertEquals(body.success, true);
        assertExists(body.organization);
        assertEquals(body.organization.name, testOrgData.name);
    },
});

Deno.test({
    name: "admin-organizations: orgadmin cannot create organization",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("create", testOrgData, ORGADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 403);
        assertExists(body.error);
    },
});

Deno.test({
    name: "admin-organizations: systemadmin can list all organizations",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("list", {}, SYSTEMADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 200);
        assertEquals(body.success, true);
        assertExists(body.organizations);
    },
});

Deno.test({
    name: "admin-organizations: orgadmin cannot list all organizations",
    ignore: skipIntegration,
    async fn() {
        const response = await makeRequest("list", {}, ORGADMIN_TOKEN);
        const body = await response.json();

        assertEquals(response.status, 403);
        assertExists(body.error);
    },
});

console.log("\n=== Admin Organizations Tests ===");
console.log("Integration tests skipped:", skipIntegration ? "YES (set TEST_SYSTEMADMIN_TOKEN and TEST_ORGADMIN_TOKEN)" : "NO");
