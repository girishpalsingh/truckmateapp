import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { config } from "../_shared/config.ts";
import { withLogging } from "../_shared/logger.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Use Service Role Key to allow admin actions (like generating sessions)
const supabaseAdmin = createClient(
  config.supabase.url!,
  config.supabase.serviceRoleKey!
);

serve(async (req) => withLogging(req, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { action, phone_number, otp } = await req.json();

    if (!phone_number) {
      return new Response(
        JSON.stringify({ error: "Phone number is required" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // --- ACTION: SEND ---
    if (action === "send") {
      // if (config.development.enabled) {
      //   console.log(`[DEV] Skipping SMS. Use code: ${config.development.default_otp}`);
      //   return new Response(
      //     JSON.stringify({ success: true, message: "Dev mode: SMS skipped", dev: true }),
      //     { headers: corsHeaders }
      //   );
      // }

      const { error } = await supabaseAdmin.auth.signInWithOtp({
        phone: phone_number,
        options: {
          should_create_user: false,
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

    // --- ACTION: VERIFY ---
    if (action === "verify") {
      if (!otp) {
        return new Response(
          JSON.stringify({ error: "OTP is required" }),
          { status: 400, headers: corsHeaders }
        );
      }

      let session;
      let user;

      // if (config.development.enabled && otp === config.development.default_otp) {
      //   // In Dev Mode, we use admin.generateLink to "force" a real session
      //   // This ensures the frontend gets a VALID JWT for RLS headers
      //   const { data, error } = await supabaseAdmin.auth.admin.generateLink({
      //     type: 'magiclink',
      //     email: email || `${phone_number.replace('+', '')}@phone.truckmate.app`,
      //     options: { data: { phone_number } }
      //   });

      //   if (error) throw error;
      //   session = data.session;
      //   user = data.user;
      // } else {
      // PRODUCTION: Real OTP verification against Supabase Auth
      const { data, error } = await supabaseAdmin.auth.verifyOtp({
        phone: phone_number,
        token: otp,
        type: 'sms',
      });

      if (error) throw error;
      session = data.session;
      user = data.user;
      // }

      // Sync/Check User Profile in your 'profiles' table
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("*")
        .eq("phone_number", phone_number)
        .single();

      return new Response(
        JSON.stringify({
          success: true,
          session, // This contains the access_token (JWT) for auth headers
          user,
          profile,
          message: "Authentication successful",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Invalid action" }),
      { status: 400, headers: corsHeaders }
    );

  } catch (error) {
    console.error("Auth Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
}));