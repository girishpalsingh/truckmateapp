import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { config } from "../_shared/config.ts";
import { withLogging } from "../_shared/logger.ts";
import { getUserByPhone, getOrganization } from "../_shared/utils.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Use Service Role Key to allow admin actions (like generating sessions)
// Moved to local scope in serve handler


// ============================================
// ACTION: SEND OTP
// ============================================
async function handleSendOtp(
  supabase: SupabaseClient,
  phoneNumber: string
): Promise<Response> {
  // Check if user exists and is active
  const { user, profile, error: userError } = await getUserByPhone(supabase, phoneNumber);

  if (userError) {
    throw userError;
  }

  if (!user || !profile) {
    return new Response(
      JSON.stringify({ error: "User or profile does not exist" }),
      { status: 404, headers: corsHeaders }
    );
  }





  // Check if user is active
  if (!profile?.is_active) {
    return new Response(
      JSON.stringify({ error: "User is not active" }),
      { status: 403, headers: corsHeaders }
    );
  }

  // Check organization assignment
  const orgId = profile?.organization_id;
  if (!orgId) {
    return new Response(
      JSON.stringify({ error: "User has no organization assigned" }),
      { status: 403, headers: corsHeaders }
    );
  }

  // Validate organization exists and is active
  const { data: org, error: orgError } = await getOrganization(supabase, orgId);

  if (orgError || !org) {
    return new Response(
      JSON.stringify({ error: "Organization not found" }),
      { status: 404, headers: corsHeaders }
    );
  }

  if (!org.is_active) {
    return new Response(
      JSON.stringify({ error: "Organization is not active" }),
      { status: 403, headers: corsHeaders }
    );
  }

  // Send OTP
  const { error } = await supabase.auth.signInWithOtp({
    phone: phoneNumber,
    options: {
      shouldCreateUser: false,
    }
  });

  if (error) {
    console.log(error);
    throw error;
  }

  return new Response(
    JSON.stringify({ success: true, message: "OTP sent successfully" }),
    { headers: corsHeaders }
  );
}

// ============================================
// ACTION: VERIFY OTP
// ============================================
async function handleVerifyOtp(
  supabaseAdmin: SupabaseClient,
  phoneNumber: string,
  otp: string
): Promise<Response> {
  if (!otp) {
    return new Response(
      JSON.stringify({ error: "OTP is required" }),
      { status: 400, headers: corsHeaders }
    );
  }

  // Create a separate client for verification to avoid polluting the admin client with a user session
  // We use the same service role key, but a fresh instance.
  const verificationClient = createClient(
    config.supabase.url!,
    config.supabase.serviceRoleKey!,
    {
      auth: {
        persistSession: false,
      }
    }
  );

  // Verify OTP against Supabase Auth using the isolated client
  const { data, error } = await verificationClient.auth.verifyOtp({
    phone: phoneNumber,
    token: otp,
    type: 'sms',
  });

  if (error) throw error;

  console.log(`[handleVerifyOtp] verifying phone: '${phoneNumber}'`);

  // Use the clean supabaseAdmin client for subsequent DB queries
  const { user, profile, error: userError } = await getUserByPhone(supabaseAdmin, phoneNumber);

  if (userError) {
    throw userError;
  }

  if (!user || !profile) {
    return new Response(
      JSON.stringify({ error: "User does not exist" }),
      { status: 404, headers: corsHeaders }
    );
  }



  const session = data.session;
  const authUser = data.user;
  // Get profile to check is_active status


  // Get organization details
  const { data: organization } = profile?.organization_id
    ? await getOrganization(supabaseAdmin, profile.organization_id)
    : { data: null };
  //if organization is null, return error
  if (!organization) {
    return new Response(
      JSON.stringify({ error: "Organization not found" }),
      { status: 404, headers: corsHeaders }
    );
  }

  return new Response(
    JSON.stringify({
      success: true,
      session,
      user,
      profile,
      organization,
      message: "Authentication successful",
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

// ============================================
// ACTION: LOGOUT
// ============================================
async function handleLogout(
  supabase: SupabaseClient,
  req: Request
): Promise<Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Authorization header required" }),
      { status: 401, headers: corsHeaders }
    );
  }

  const token = authHeader.replace("Bearer ", "");

  // Validate the token
  const { data: { user }, error: getUserError } = await supabase.auth.getUser(token);

  if (getUserError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired token" }),
      { status: 401, headers: corsHeaders }
    );
  }

  // Sign out the user (invalidates the session)
  const { error: signOutError } = await supabase.auth.admin.signOut(token);

  if (signOutError) {
    throw signOutError;
  }

  return new Response(
    JSON.stringify({ success: true, message: "Logged out successfully" }),
    { status: 200, headers: corsHeaders }
  );
}

// ============================================
// MAIN HANDLER
// ============================================
serve(async (req) => withLogging(req, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { action, phone_number, otp } = await req.json();

    // Instantiate Supabase Admin Client for this request
    const supabaseAdmin = createClient(
      config.supabase.url!,
      config.supabase.serviceRoleKey!,
      {
        auth: {
          persistSession: false,
        },
      }
    );

    // Validate phone number for send/verify actions
    if ((action === "send" || action === "verify") && !phone_number) {
      return new Response(
        JSON.stringify({ error: "Phone number is required" }),
        { status: 400, headers: corsHeaders }
      );
    }

    switch (action) {
      case "send":
        return await handleSendOtp(supabaseAdmin, phone_number);

      case "verify":
        return await handleVerifyOtp(supabaseAdmin, phone_number, otp);

      case "logout":
        return await handleLogout(supabaseAdmin, req);

      default:
        return new Response(
          JSON.stringify({ error: "Invalid action" }),
          { status: 400, headers: corsHeaders }
        );
    }

  } catch (error) {
    console.error("Auth Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
}));