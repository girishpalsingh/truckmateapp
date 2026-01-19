// supabase/functions/auth-otp/index.ts
// OTP Authentication Edge Function

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OTPRequest {
  action: "send" | "verify";
  phone_number: string;
  email?: string;
  otp?: string;
}

interface Config {
  development: {
    enabled: boolean;
    default_otp: string;
    skip_twilio: boolean;
    skip_email: boolean;
  };
  twilio: {
    account_sid: string;
    auth_token: string;
    phone_number: string;
  };
  resend: {
    api_key: string;
    from_email: string;
  };
}

// In-memory OTP store (in production, use Redis or database)
const otpStore = new Map<string, { otp: string; expires: number; email?: string }>();

async function sendTwilioSMS(config: Config, to: string, otp: string): Promise<boolean> {
  if (config.development.enabled && config.development.skip_twilio) {
    console.log(`[DEV MODE] Would send SMS to ${to}: Your TruckMate code is ${otp}`);
    return true;
  }

  try {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${config.twilio.account_sid}/Messages.json`;
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(`${config.twilio.account_sid}:${config.twilio.auth_token}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: to,
        From: config.twilio.phone_number,
        Body: `Your TruckMate verification code is: ${otp}. Valid for 10 minutes.`,
      }),
    });

    return response.ok;
  } catch (error) {
    console.error("Twilio SMS error:", error);
    return false;
  }
}

async function sendResendEmail(config: Config, to: string, otp: string): Promise<boolean> {
  if (config.development.enabled && config.development.skip_email) {
    console.log(`[DEV MODE] Would send email to ${to}: Your TruckMate code is ${otp}`);
    return true;
  }

  if (!to) return true; // Email is optional

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${config.resend.api_key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: config.resend.from_email,
        to: [to],
        subject: "Your TruckMate Verification Code",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #1a365d;">TruckMate Verification</h2>
            <p>Your verification code is:</p>
            <div style="background: #f0f4f8; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 20px 0;">
              ${otp}
            </div>
            <p style="color: #666; font-size: 14px;">This code expires in 10 minutes.</p>
            <p style="color: #666; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
          </div>
        `,
      }),
    });

    return response.ok;
  } catch (error) {
    console.error("Resend email error:", error);
    return false;
  }
}

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Load configuration
    const config: Config = {
      development: {
        enabled: Deno.env.get("DEV_MODE") === "true",
        default_otp: Deno.env.get("DEV_DEFAULT_OTP") || "123456",
        skip_twilio: Deno.env.get("DEV_MODE") === "true",
        skip_email: Deno.env.get("DEV_MODE") === "true",
      },
      twilio: {
        account_sid: Deno.env.get("TWILIO_ACCOUNT_SID") || "",
        auth_token: Deno.env.get("TWILIO_AUTH_TOKEN") || "",
        phone_number: Deno.env.get("TWILIO_PHONE_NUMBER") || "",
      },
      resend: {
        api_key: Deno.env.get("RESEND_API_KEY") || "",
        from_email: Deno.env.get("RESEND_FROM_EMAIL") || "noreply@truckmate.app",
      },
    };

    const body: OTPRequest = await req.json();
    const { action, phone_number, email, otp } = body;

    if (!phone_number) {
      return new Response(
        JSON.stringify({ error: "Phone number is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (action === "send") {
      // Generate OTP (or use default in dev mode)
      const generatedOTP = config.development.enabled 
        ? config.development.default_otp 
        : generateOTP();

      // Store OTP with 10 minute expiry
      otpStore.set(phone_number, {
        otp: generatedOTP,
        expires: Date.now() + 10 * 60 * 1000,
        email,
      });

      // Send OTP via SMS and Email
      const [smsResult, emailResult] = await Promise.all([
        sendTwilioSMS(config, phone_number, generatedOTP),
        sendResendEmail(config, email || "", generatedOTP),
      ]);

      if (!smsResult && !config.development.enabled) {
        return new Response(
          JSON.stringify({ error: "Failed to send SMS" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ 
          success: true, 
          message: "OTP sent successfully",
          dev_mode: config.development.enabled,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );

    } else if (action === "verify") {
      if (!otp) {
        return new Response(
          JSON.stringify({ error: "OTP is required" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const stored = otpStore.get(phone_number);

      // In dev mode, always accept the default OTP
      const isValidOTP = config.development.enabled
        ? otp === config.development.default_otp
        : stored && stored.otp === otp && stored.expires > Date.now();

      if (!isValidOTP) {
        return new Response(
          JSON.stringify({ error: "Invalid or expired OTP" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Clear used OTP
      otpStore.delete(phone_number);

      // Check if user exists
      const { data: existingProfile } = await supabase
        .from("profiles")
        .select("id, organization_id, role, full_name")
        .eq("phone_number", phone_number)
        .single();

      if (existingProfile) {
        // Create a session for existing user
        // Note: In production, use Supabase Auth with custom token
        return new Response(
          JSON.stringify({
            success: true,
            user_exists: true,
            profile: existingProfile,
            message: "Login successful",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        // New user - they need to complete registration
        return new Response(
          JSON.stringify({
            success: true,
            user_exists: false,
            message: "OTP verified. Please complete registration.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

    } else {
      return new Response(
        JSON.stringify({ error: "Invalid action. Use 'send' or 'verify'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

  } catch (error) {
    console.error("Auth OTP error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
