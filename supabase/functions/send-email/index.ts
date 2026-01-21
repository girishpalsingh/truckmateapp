// supabase/functions/send-email/index.ts
// Email Sending Edge Function using Resend

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { authorizeUser } from "../_shared/auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
// ... (rest of imports)

import { withLogging } from "../_shared/logger.ts";

serve(async (req) => withLogging(req, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Verify User
    await authorizeUser(req);

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") || "noreply@truckmate.app";
    const devMode = Deno.env.get("DEV_MODE") === "true";

    if (!resendKey && !devMode) {
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body: EmailRequest = await req.json();
    const { to, subject, html, text, template, template_data, attachments } = body;

    if (!to || !subject) {
      return new Response(
        JSON.stringify({ error: "to and subject are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate HTML from template if specified
    let emailHtml = html;
    if (template && template_data && emailTemplates[template]) {
      emailHtml = emailTemplates[template](template_data);
    }

    if (devMode) {
      console.log(`[DEV MODE] Would send email to ${to}`);
      console.log(`Subject: ${subject}`);
      console.log(`HTML: ${emailHtml?.substring(0, 200)}...`);

      return new Response(
        JSON.stringify({ success: true, dev_mode: true, message: "Email logged (dev mode)" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prepare attachments for Resend
    const resendAttachments = attachments?.map(att => ({
      filename: att.filename,
      content: att.content,
      type: att.content_type,
    }));

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: Array.isArray(to) ? to : [to],
        subject,
        html: emailHtml,
        text,
        attachments: resendAttachments,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("Resend error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to send email" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result = await response.json();

    return new Response(
      JSON.stringify({ success: true, message_id: result.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Email send error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Email send failed" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}));
