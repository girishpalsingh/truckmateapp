/**
 * Admin Organizations Edge Function
 * 
 * Provides CRUD operations for managing organizations.
 * 
 * @module admin-organizations
 * 
 * ## Authorization
 * - `create`: systemadmin only
 * - `update`: systemadmin, or orgadmin for their own organization
 * - `delete`: systemadmin only (soft delete via is_active)
 * - `get`: systemadmin, or orgadmin for their own organization
 * - `list`: systemadmin only
 * 
 * ## Request Format
 * ```json
 * {
 *   "action": "create" | "update" | "delete" | "get" | "list",
 *   "data": { ... action-specific payload ... }
 * }
 * ```
 * 
 * ## Actions
 * 
 * ### create
 * Creates a new organization.
 * ```json
 * {
 *   "action": "create",
 *   "data": {
 *     "name": "Company Name",
 *     "legal_entity_name": "Company LLC",
 *     "mc_dot_number": "MC-123456",
 *     "tax_id": "12-3456789",
 *     "llm_provider": "gemini",
 *     "approval_email_address": "invoices@company.com"
 *   }
 * }
 * ```
 * 
 * ### update
 * Updates an existing organization.
 * ```json
 * {
 *   "action": "update",
 *   "data": {
 *     "id": "uuid",
 *     "name": "Updated Name",
 *     ... other fields to update ...
 *   }
 * }
 * ```
 * 
 * ### delete
 * Soft-deletes an organization (sets is_active = false).
 * ```json
 * {
 *   "action": "delete",
 *   "data": { "id": "uuid" }
 * }
 * ```
 * 
 * ### get
 * Retrieves a single organization by ID.
 * ```json
 * {
 *   "action": "get",
 *   "data": { "id": "uuid" }
 * }
 * ```
 * 
 * ### list
 * Lists all organizations (systemadmin only).
 * ```json
 * {
 *   "action": "list",
 *   "data": { "include_inactive": false }
 * }
 * ```
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { config } from "../_shared/config.ts";
import { withLogging } from "../_shared/logger.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Service role client for admin operations
const supabaseAdmin = createClient(
    config.supabase.url!,
    config.supabase.serviceRoleKey!
);

/**
 * Organization data structure for create/update operations
 */
interface OrganizationData {
    id?: string;
    name?: string;
    legal_entity_name?: string;
    mc_dot_number?: string;
    tax_id?: string;
    llm_provider?: string;
    approval_email_address?: string;
    is_active?: boolean;
    registered_address?: Record<string, unknown>;
    mailing_address?: Record<string, unknown>;
    logo_image_link?: string;
    website?: string;
    // Optional orgadmin details for auto-creation
    admin_full_name?: string;
    admin_email?: string;
    admin_phone?: string;
}

/**
 * Verifies that the user has admin privileges.
 * Returns the user's profile with role and organization_id.
 * 
 * @param supabase - Supabase client with service role
 * @param authHeader - Authorization header from request
 * @returns User profile with role information
 * @throws Error if unauthorized
 */
async function verifyAdminAccess(
    supabase: SupabaseClient,
    authHeader: string | null
): Promise<{ id: string; role: string; organization_id: string | null }> {
    if (!authHeader) {
        throw new Error("Authorization header required");
    }

    const token = authHeader.replace("Bearer ", "");

    // Get user from token
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);

    if (userError || !user) {
        throw new Error("Invalid or expired token");
    }

    // Get user's profile with role
    const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .select("id, role, organization_id")
        .eq("id", user.id)
        .single();

    if (profileError || !profile) {
        throw new Error("User profile not found");
    }

    // Check if user has admin role
    if (!["systemadmin", "orgadmin"].includes(profile.role)) {
        throw new Error("Insufficient permissions: admin role required");
    }

    return profile;
}

/**
 * Generates a slug from organization name for email domain
 */
function generateOrgSlug(name: string): string {
    return name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "")
        .slice(0, 20);
}

/**
 * Creates a new organization with an automatic orgadmin user.
 * Only systemadmin can create organizations.
 * 
 * The orgadmin user is created automatically with:
 * - Email: admin@{org-slug}.truckmate.app
 * - Password: from app_config.json development.default_password or fallback
 * - Role: orgadmin
 * 
 * @param supabase - Supabase client
 * @param data - Organization data (optionally with admin_full_name, admin_email, admin_phone)
 * @param adminProfile - Admin user's profile
 * @returns Created organization with orgadmin user details
 */
async function createOrganization(
    supabase: SupabaseClient,
    data: OrganizationData,
    adminProfile: { role: string }
): Promise<Response> {
    // Only systemadmin can create organizations
    if (adminProfile.role !== "systemadmin") {
        return new Response(
            JSON.stringify({ error: "Only system administrators can create organizations" }),
            { status: 403, headers: corsHeaders }
        );
    }

    // Validate required fields
    if (!data.name) {
        return new Response(
            JSON.stringify({ error: "Organization name is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Create the organization first
    const { data: org, error: orgError } = await supabase
        .from("organizations")
        .insert({
            name: data.name,
            legal_entity_name: data.legal_entity_name,
            mc_dot_number: data.mc_dot_number,
            tax_id: data.tax_id,
            llm_provider: data.llm_provider || "gemini",
            approval_email_address: data.approval_email_address,
            registered_address: data.registered_address,
            mailing_address: data.mailing_address,
            logo_image_link: data.logo_image_link,
            website: data.website,
            is_active: true,
        })
        .select()
        .single();

    if (orgError) {
        console.error("Create organization error:", orgError);
        return new Response(
            JSON.stringify({ error: orgError.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    // Generate orgadmin credentials
    const orgSlug = generateOrgSlug(data.name);
    const adminEmail = data.admin_email || `admin@${orgSlug}.truckmate.app`;
    const adminFullName = data.admin_full_name || `${data.name} Admin`;
    const adminPhone = data.admin_phone || null;

    // Use default password from config (for development) or generate a secure one
    const defaultPassword = config.development.enabled
        ? (config.development.default_otp + "Password!") // e.g., "123456Password!"
        : crypto.randomUUID().slice(0, 16) + "!Aa1";

    console.log(`Creating orgadmin for ${data.name}: ${adminEmail}`);

    // Create auth user for orgadmin
    const authUserData: {
        email: string;
        password: string;
        phone?: string;
        email_confirm: boolean;
        phone_confirm?: boolean;
        user_metadata: { full_name: string; role: string };
    } = {
        email: adminEmail,
        password: defaultPassword,
        email_confirm: true,
        user_metadata: { full_name: adminFullName, role: "orgadmin" },
    };

    if (adminPhone) {
        authUserData.phone = adminPhone;
        authUserData.phone_confirm = true;
    }

    const { data: authData, error: authError } = await supabase.auth.admin.createUser(authUserData);

    if (authError) {
        console.error("Create orgadmin auth user error:", authError);
        // Rollback: delete organization
        await supabase.from("organizations").delete().eq("id", org.id);
        return new Response(
            JSON.stringify({ error: `Failed to create admin user: ${authError.message}` }),
            { status: 500, headers: corsHeaders }
        );
    }

    // Create profile for orgadmin
    const { data: adminProfile2, error: profileError } = await supabase
        .from("profiles")
        .insert({
            id: authData.user.id,
            organization_id: org.id,
            full_name: adminFullName,
            phone_number: adminPhone,
            email_address: adminEmail,
            role: "orgadmin",
            is_active: true,
        })
        .select()
        .single();

    if (profileError) {
        console.error("Create orgadmin profile error:", profileError);
        // Rollback: delete auth user and organization
        await supabase.auth.admin.deleteUser(authData.user.id);
        await supabase.from("organizations").delete().eq("id", org.id);
        return new Response(
            JSON.stringify({ error: `Failed to create admin profile: ${profileError.message}` }),
            { status: 500, headers: corsHeaders }
        );
    }

    // Update organization with admin_id reference
    await supabase
        .from("organizations")
        .update({ admin_id: authData.user.id })
        .eq("id", org.id);

    // Prepare response with admin credentials (for development/testing)
    const response: {
        success: boolean;
        organization: typeof org;
        orgadmin: {
            id: string;
            email: string;
            full_name: string;
            password?: string;
        };
    } = {
        success: true,
        organization: org,
        orgadmin: {
            id: authData.user.id,
            email: adminEmail,
            full_name: adminFullName,
        },
    };

    // Include password only in development mode
    if (config.development.enabled) {
        response.orgadmin.password = defaultPassword;
    }

    console.log(`Organization ${data.name} created with orgadmin ${adminEmail}`);

    return new Response(
        JSON.stringify(response),
        { status: 201, headers: corsHeaders }
    );
}

/**
 * Updates an existing organization.
 * systemadmin can update any org, orgadmin can only update their own.
 * 
 * @param supabase - Supabase client
 * @param data - Organization update data (must include id)
 * @param adminProfile - Admin user's profile
 * @returns Updated organization
 */
async function updateOrganization(
    supabase: SupabaseClient,
    data: OrganizationData,
    adminProfile: { role: string; organization_id: string | null }
): Promise<Response> {
    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "Organization ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // orgadmin can only update their own organization
    if (adminProfile.role === "orgadmin" && adminProfile.organization_id !== data.id) {
        return new Response(
            JSON.stringify({ error: "You can only update your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    // Build update object (exclude id and undefined values)
    const updateData: Partial<OrganizationData> = {};
    const allowedFields: (keyof OrganizationData)[] = [
        "name", "legal_entity_name", "mc_dot_number", "tax_id",
        "llm_provider", "approval_email_address", "registered_address",
        "mailing_address", "logo_image_link", "website", "is_active"
    ];

    for (const field of allowedFields) {
        if (data[field] !== undefined) {
            updateData[field] = data[field];
        }
    }

    const { data: org, error } = await supabase
        .from("organizations")
        .update(updateData)
        .eq("id", data.id)
        .select()
        .single();

    if (error) {
        console.error("Update organization error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, organization: org }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Soft-deletes an organization by setting is_active = false.
 * Only systemadmin can delete organizations.
 * 
 * @param supabase - Supabase client
 * @param data - Must contain organization id
 * @param adminProfile - Admin user's profile
 * @returns Success message
 */
async function deleteOrganization(
    supabase: SupabaseClient,
    data: OrganizationData,
    adminProfile: { role: string }
): Promise<Response> {
    // Only systemadmin can delete organizations
    if (adminProfile.role !== "systemadmin") {
        return new Response(
            JSON.stringify({ error: "Only system administrators can delete organizations" }),
            { status: 403, headers: corsHeaders }
        );
    }

    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "Organization ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    const { error } = await supabase
        .from("organizations")
        .update({ is_active: false })
        .eq("id", data.id);

    if (error) {
        console.error("Delete organization error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, message: "Organization deactivated" }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Retrieves an organization by ID.
 * systemadmin can get any org, orgadmin can only get their own.
 * 
 * @param supabase - Supabase client
 * @param data - Must contain organization id
 * @param adminProfile - Admin user's profile
 * @returns Organization data
 */
async function getOrganization(
    supabase: SupabaseClient,
    data: OrganizationData,
    adminProfile: { role: string; organization_id: string | null }
): Promise<Response> {
    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "Organization ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // orgadmin can only get their own organization
    if (adminProfile.role === "orgadmin" && adminProfile.organization_id !== data.id) {
        return new Response(
            JSON.stringify({ error: "You can only view your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    const { data: org, error } = await supabase
        .from("organizations")
        .select("*")
        .eq("id", data.id)
        .single();

    if (error) {
        console.error("Get organization error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 404, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, organization: org }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Lists all organizations.
 * Only systemadmin can list all organizations.
 * 
 * @param supabase - Supabase client
 * @param data - Optional filter: include_inactive
 * @param adminProfile - Admin user's profile
 * @returns Array of organizations
 */
async function listOrganizations(
    supabase: SupabaseClient,
    data: { include_inactive?: boolean },
    adminProfile: { role: string }
): Promise<Response> {
    // Only systemadmin can list all organizations
    if (adminProfile.role !== "systemadmin") {
        return new Response(
            JSON.stringify({ error: "Only system administrators can list all organizations" }),
            { status: 403, headers: corsHeaders }
        );
    }

    let query = supabase.from("organizations").select("*");

    if (!data.include_inactive) {
        query = query.eq("is_active", true);
    }

    const { data: orgs, error } = await query.order("name");

    if (error) {
        console.error("List organizations error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, organizations: orgs }),
        { status: 200, headers: corsHeaders }
    );
}

// ============================================
// MAIN HANDLER
// ============================================
serve(async (req) => withLogging(req, async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        // Verify admin access
        const adminProfile = await verifyAdminAccess(supabaseAdmin, req.headers.get("Authorization"));

        const { action, data } = await req.json();

        switch (action) {
            case "create":
                return await createOrganization(supabaseAdmin, data || {}, adminProfile);

            case "update":
                return await updateOrganization(supabaseAdmin, data || {}, adminProfile);

            case "delete":
                return await deleteOrganization(supabaseAdmin, data || {}, adminProfile);

            case "get":
                return await getOrganization(supabaseAdmin, data || {}, adminProfile);

            case "list":
                return await listOrganizations(supabaseAdmin, data || {}, adminProfile);

            default:
                return new Response(
                    JSON.stringify({ error: "Invalid action. Valid actions: create, update, delete, get, list" }),
                    { status: 400, headers: corsHeaders }
                );
        }

    } catch (error) {
        console.error("Admin Organizations Error:", error.message);

        // Determine appropriate status code
        const status = error.message.includes("Insufficient permissions") ? 403 :
            error.message.includes("Authorization") || error.message.includes("token") ? 401 :
                500;

        return new Response(
            JSON.stringify({ error: error.message }),
            { status, headers: corsHeaders }
        );
    }
}));
