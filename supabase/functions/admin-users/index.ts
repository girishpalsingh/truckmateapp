/**
 * Admin Users Edge Function
 * 
 * Provides CRUD operations for managing users (profiles).
 * 
 * @module admin-users
 * 
 * ## Authorization
 * - `create`: systemadmin, or orgadmin for their own organization
 * - `update`: systemadmin, or orgadmin for users in their own organization
 * - `delete`: systemadmin, or orgadmin for users in their own org (cannot delete self)
 * - `get`: systemadmin, or orgadmin for users in their own organization
 * - `list`: systemadmin (all users), or orgadmin (users in their organization)
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
 * Creates a new user in an organization.
 * ```json
 * {
 *   "action": "create",
 *   "data": {
 *     "organization_id": "uuid",
 *     "full_name": "John Doe",
 *     "phone_number": "+15551234567",
 *     "email_address": "john@example.com",
 *     "role": "driver"
 *   }
 * }
 * ```
 * 
 * ### update
 * Updates an existing user.
 * ```json
 * {
 *   "action": "update",
 *   "data": {
 *     "id": "uuid",
 *     "full_name": "Updated Name",
 *     "role": "dispatcher"
 *   }
 * }
 * ```
 * 
 * ### delete
 * Soft-deletes a user (sets is_active = false).
 * ```json
 * {
 *   "action": "delete",
 *   "data": { "id": "uuid" }
 * }
 * ```
 * 
 * ### get
 * Retrieves a single user by ID.
 * ```json
 * {
 *   "action": "get",
 *   "data": { "id": "uuid" }
 * }
 * ```
 * 
 * ### list
 * Lists users in organization.
 * ```json
 * {
 *   "action": "list",
 *   "data": { 
 *     "organization_id": "uuid",  // Required for orgadmin, optional for systemadmin
 *     "include_inactive": false 
 *   }
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

/** Valid user roles */
const VALID_ROLES = ["systemadmin", "orgadmin", "owner", "manager", "dispatcher", "driver"];

/**
 * User data structure for create/update operations
 */
interface UserData {
    id?: string;
    organization_id?: string;
    full_name?: string;
    phone_number?: string;
    email_address?: string;
    role?: string;
    is_active?: boolean;
    address?: Record<string, unknown>;
    preferred_language?: string;
    identity_document_id?: string;
}

/**
 * Admin profile structure
 */
interface AdminProfile {
    id: string;
    role: string;
    organization_id: string | null;
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
): Promise<AdminProfile> {
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
 * Checks if orgadmin is authorized to manage users in a specific organization.
 * 
 * @param adminProfile - The admin's profile
 * @param targetOrgId - The organization ID being accessed
 * @returns true if authorized
 */
function canAccessOrganization(adminProfile: AdminProfile, targetOrgId: string): boolean {
    if (adminProfile.role === "systemadmin") return true;
    return adminProfile.organization_id === targetOrgId;
}

/**
 * Creates a new user in an organization.
 * Creates both auth.users entry and profiles entry.
 * 
 * @param supabase - Supabase client
 * @param data - User data
 * @param adminProfile - Admin user's profile
 * @returns Created user profile
 */
async function createUser(
    supabase: SupabaseClient,
    data: UserData,
    adminProfile: AdminProfile
): Promise<Response> {
    // Validate required fields
    if (!data.organization_id) {
        return new Response(
            JSON.stringify({ error: "Organization ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    if (!data.full_name) {
        return new Response(
            JSON.stringify({ error: "Full name is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    if (!data.phone_number && !data.email_address) {
        return new Response(
            JSON.stringify({ error: "Phone number or email address is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Check organization access
    if (!canAccessOrganization(adminProfile, data.organization_id)) {
        return new Response(
            JSON.stringify({ error: "You can only create users in your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    // Validate role
    const role = data.role || "driver";
    if (!VALID_ROLES.includes(role)) {
        return new Response(
            JSON.stringify({ error: `Invalid role. Valid roles: ${VALID_ROLES.join(", ")}` }),
            { status: 400, headers: corsHeaders }
        );
    }

    // orgadmin cannot create systemadmin users
    if (adminProfile.role === "orgadmin" && role === "systemadmin") {
        return new Response(
            JSON.stringify({ error: "You cannot create system admin users" }),
            { status: 403, headers: corsHeaders }
        );
    }

    // Verify organization exists
    const { data: org, error: orgError } = await supabase
        .from("organizations")
        .select("id, is_active")
        .eq("id", data.organization_id)
        .single();

    if (orgError || !org) {
        return new Response(
            JSON.stringify({ error: "Organization not found" }),
            { status: 404, headers: corsHeaders }
        );
    }

    if (!org.is_active) {
        return new Response(
            JSON.stringify({ error: "Cannot create users in inactive organization" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Create auth user
    const authUserData: {
        phone?: string;
        email?: string;
        email_confirm?: boolean;
        phone_confirm?: boolean;
        user_metadata: { full_name: string; role: string };
    } = {
        user_metadata: { full_name: data.full_name, role },
    };

    if (data.phone_number) {
        authUserData.phone = data.phone_number;
        authUserData.phone_confirm = true;
    }

    if (data.email_address) {
        authUserData.email = data.email_address;
        authUserData.email_confirm = true;
    }

    const { data: authUser, error: authError } = await supabase.auth.admin.createUser(authUserData);

    if (authError) {
        console.error("Create auth user error:", authError);
        return new Response(
            JSON.stringify({ error: authError.message }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Create profile
    const { data: profile, error: profileError } = await supabase
        .from("profiles")
        .insert({
            id: authUser.user.id,
            organization_id: data.organization_id,
            full_name: data.full_name,
            phone_number: data.phone_number,
            email_address: data.email_address,
            role,
            is_active: true,
            address: data.address,
            preferred_language: data.preferred_language || "en",
        })
        .select()
        .single();

    if (profileError) {
        console.error("Create profile error:", profileError);
        // Rollback: delete auth user
        await supabase.auth.admin.deleteUser(authUser.user.id);
        return new Response(
            JSON.stringify({ error: profileError.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, user: profile }),
        { status: 201, headers: corsHeaders }
    );
}

/**
 * Updates an existing user.
 * 
 * @param supabase - Supabase client
 * @param data - User update data (must include id)
 * @param adminProfile - Admin user's profile
 * @returns Updated user profile
 */
async function updateUser(
    supabase: SupabaseClient,
    data: UserData,
    adminProfile: AdminProfile
): Promise<Response> {
    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "User ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Get target user's organization
    const { data: targetUser, error: targetError } = await supabase
        .from("profiles")
        .select("organization_id, role")
        .eq("id", data.id)
        .single();

    if (targetError || !targetUser) {
        return new Response(
            JSON.stringify({ error: "User not found" }),
            { status: 404, headers: corsHeaders }
        );
    }

    // Check organization access
    if (!canAccessOrganization(adminProfile, targetUser.organization_id)) {
        return new Response(
            JSON.stringify({ error: "You can only update users in your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    // Validate role if being updated
    if (data.role) {
        if (!VALID_ROLES.includes(data.role)) {
            return new Response(
                JSON.stringify({ error: `Invalid role. Valid roles: ${VALID_ROLES.join(", ")}` }),
                { status: 400, headers: corsHeaders }
            );
        }

        // orgadmin cannot promote to systemadmin
        if (adminProfile.role === "orgadmin" && data.role === "systemadmin") {
            return new Response(
                JSON.stringify({ error: "You cannot set system admin role" }),
                { status: 403, headers: corsHeaders }
            );
        }
    }

    // Build update object
    const updateData: Partial<UserData> = {};
    const allowedFields: (keyof UserData)[] = [
        "full_name", "phone_number", "email_address", "role",
        "is_active", "address", "preferred_language"
    ];

    for (const field of allowedFields) {
        if (data[field] !== undefined) {
            updateData[field] = data[field];
        }
    }

    const { data: profile, error } = await supabase
        .from("profiles")
        .update(updateData)
        .eq("id", data.id)
        .select()
        .single();

    if (error) {
        console.error("Update user error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    // Update auth user if phone/email changed
    if (data.phone_number || data.email_address) {
        const authUpdate: { phone?: string; email?: string } = {};
        if (data.phone_number) authUpdate.phone = data.phone_number;
        if (data.email_address) authUpdate.email = data.email_address;

        await supabase.auth.admin.updateUserById(data.id, authUpdate);
    }

    return new Response(
        JSON.stringify({ success: true, user: profile }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Soft-deletes a user by setting is_active = false.
 * Admin cannot delete themselves.
 * 
 * @param supabase - Supabase client
 * @param data - Must contain user id
 * @param adminProfile - Admin user's profile
 * @returns Success message
 */
async function deleteUser(
    supabase: SupabaseClient,
    data: UserData,
    adminProfile: AdminProfile
): Promise<Response> {
    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "User ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Cannot delete yourself
    if (data.id === adminProfile.id) {
        return new Response(
            JSON.stringify({ error: "You cannot delete yourself" }),
            { status: 400, headers: corsHeaders }
        );
    }

    // Get target user's organization
    const { data: targetUser, error: targetError } = await supabase
        .from("profiles")
        .select("organization_id")
        .eq("id", data.id)
        .single();

    if (targetError || !targetUser) {
        return new Response(
            JSON.stringify({ error: "User not found" }),
            { status: 404, headers: corsHeaders }
        );
    }

    // Check organization access
    if (!canAccessOrganization(adminProfile, targetUser.organization_id)) {
        return new Response(
            JSON.stringify({ error: "You can only delete users in your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    const { error } = await supabase
        .from("profiles")
        .update({ is_active: false })
        .eq("id", data.id);

    if (error) {
        console.error("Delete user error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, message: "User deactivated" }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Retrieves a user by ID.
 * 
 * @param supabase - Supabase client
 * @param data - Must contain user id
 * @param adminProfile - Admin user's profile
 * @returns User profile data
 */
async function getUser(
    supabase: SupabaseClient,
    data: UserData,
    adminProfile: AdminProfile
): Promise<Response> {
    if (!data.id) {
        return new Response(
            JSON.stringify({ error: "User ID is required" }),
            { status: 400, headers: corsHeaders }
        );
    }

    const { data: user, error } = await supabase
        .from("profiles")
        .select("*, organizations(name)")
        .eq("id", data.id)
        .single();

    if (error) {
        console.error("Get user error:", error);
        return new Response(
            JSON.stringify({ error: "User not found" }),
            { status: 404, headers: corsHeaders }
        );
    }

    // Check organization access
    if (!canAccessOrganization(adminProfile, user.organization_id)) {
        return new Response(
            JSON.stringify({ error: "You can only view users in your own organization" }),
            { status: 403, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, user }),
        { status: 200, headers: corsHeaders }
    );
}

/**
 * Lists users in an organization.
 * systemadmin can list all users or filter by org.
 * orgadmin can only list users in their organization.
 * 
 * @param supabase - Supabase client
 * @param data - Optional filters: organization_id, include_inactive
 * @param adminProfile - Admin user's profile
 * @returns Array of user profiles
 */
async function listUsers(
    supabase: SupabaseClient,
    data: { organization_id?: string; include_inactive?: boolean },
    adminProfile: AdminProfile
): Promise<Response> {
    let query = supabase.from("profiles").select("*, organizations(name)");

    // Determine which organization to list
    let targetOrgId = data.organization_id;

    if (adminProfile.role === "orgadmin") {
        // orgadmin can only list their own organization
        targetOrgId = adminProfile.organization_id!;
    }

    if (targetOrgId) {
        query = query.eq("organization_id", targetOrgId);
    }

    if (!data.include_inactive) {
        query = query.eq("is_active", true);
    }

    const { data: users, error } = await query.order("full_name");

    if (error) {
        console.error("List users error:", error);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: corsHeaders }
        );
    }

    return new Response(
        JSON.stringify({ success: true, users, count: users.length }),
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
                return await createUser(supabaseAdmin, data || {}, adminProfile);

            case "update":
                return await updateUser(supabaseAdmin, data || {}, adminProfile);

            case "delete":
                return await deleteUser(supabaseAdmin, data || {}, adminProfile);

            case "get":
                return await getUser(supabaseAdmin, data || {}, adminProfile);

            case "list":
                return await listUsers(supabaseAdmin, data || {}, adminProfile);

            default:
                return new Response(
                    JSON.stringify({ error: "Invalid action. Valid actions: create, update, delete, get, list" }),
                    { status: 400, headers: corsHeaders }
                );
        }

    } catch (error) {
        console.error("Admin Users Error:", error.message);

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
