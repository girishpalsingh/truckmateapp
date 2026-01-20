// supabase/functions/send-email/index.ts
// Email Sending Edge Function using Resend

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EmailRequest {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  template?: "invoice" | "approval_request" | "ifta_report" | "otp";
  template_data?: Record<string, any>;
  attachments?: Array<{
    filename: string;
    content: string; // base64
    content_type: string;
  }>;
}

const emailTemplates = {
  invoice: (data: any) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #1a365d;">Invoice #${data.invoice_number}</h1>
      <p>Dear ${data.recipient_name},</p>
      <p>Please find attached the invoice for load #${data.load_id}.</p>
      
      <div style="background: #f7fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h3 style="margin-top: 0;">Invoice Summary</h3>
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td>Line Haul:</td>
            <td style="text-align: right;">$${data.line_haul?.toFixed(2)}</td>
          </tr>
          <tr>
            <td>Fuel Surcharge:</td>
            <td style="text-align: right;">$${data.fuel_surcharge?.toFixed(2)}</td>
          </tr>
          ${data.detention_charges > 0 ? `
          <tr>
            <td>Detention:</td>
            <td style="text-align: right;">$${data.detention_charges?.toFixed(2)}</td>
          </tr>
          ` : ''}
          <tr style="font-weight: bold; border-top: 2px solid #1a365d;">
            <td>Total Due:</td>
            <td style="text-align: right;">$${data.total_amount?.toFixed(2)}</td>
          </tr>
        </table>
      </div>
      
      <p>Payment is due within ${data.payment_terms || '30 days'}.</p>
      <p>Thank you for your business!</p>
      
      <hr style="margin: 30px 0; border: none; border-top: 1px solid #e2e8f0;">
      <p style="color: #718096; font-size: 12px;">
        ${data.company_name}<br>
        MC: ${data.mc_number}
      </p>
    </div>
  `,

  approval_request: (data: any) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #1a365d;">Invoice Ready for Approval</h1>
      <p>A new invoice is ready for your review and approval.</p>
      
      <div style="background: #f7fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h3 style="margin-top: 0;">Invoice Details</h3>
        <p><strong>Invoice #:</strong> ${data.invoice_number}</p>
        <p><strong>Load #:</strong> ${data.load_id}</p>
        <p><strong>Amount:</strong> $${data.total_amount?.toFixed(2)}</p>
        <p><strong>Bill To:</strong> ${data.broker_name}</p>
      </div>
      
      <p>
        <a href="${data.approval_url}" style="display: inline-block; background: #2b6cb0; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
          Review Invoice
        </a>
      </p>
    </div>
  `,

  ifta_report: (data: any) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h1 style="color: #1a365d;">IFTA Report - ${data.quarter}</h1>
      <p>Your quarterly IFTA report is ready for review.</p>
      
      <div style="background: #f7fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h3 style="margin-top: 0;">Summary</h3>
        <p><strong>Total Miles:</strong> ${data.total_miles?.toLocaleString()}</p>
        <p><strong>Total Gallons:</strong> ${data.total_gallons?.toFixed(2)}</p>
        <p><strong>Estimated Tax Due:</strong> $${data.total_tax?.toFixed(2)}</p>
      </div>
      
      <p>Please review the attached report and submit to your state before the deadline.</p>
      
      <p>
        <a href="${data.review_url}" style="display: inline-block; background: #2b6cb0; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px;">
          Review Report
        </a>
      </p>
    </div>
  `,

  otp: (data: any) => `
    <div style="font-family: Arial, sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #1a365d;">TruckMate Verification</h2>
      <p>Your verification code is:</p>
      <div style="background: #f0f4f8; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 20px 0;">
        ${data.otp}
      </div>
      <p style="color: #666; font-size: 14px;">This code expires in 10 minutes.</p>
      <p style="color: #666; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
    </div>
  `,
};

import { withLogging } from "../_shared/logger.ts";

serve(async (req) => withLogging(req, async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
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
