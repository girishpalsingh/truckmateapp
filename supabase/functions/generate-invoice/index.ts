// supabase/functions/generate-invoice/index.ts
// Invoice Generation Edge Function using pdf-lib

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { PDFDocument, rgb, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1";
import { authorizeUser } from "../_shared/auth.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface InvoiceRequest {
    trip_id: string;
    send_for_approval?: boolean;
}

import { withLogging } from "../_shared/logger.ts";

serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        // Verify User
        await authorizeUser(req);

        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const supabase = createClient(supabaseUrl, supabaseServiceKey);

        const body: InvoiceRequest = await req.json();
        const { trip_id, send_for_approval = true } = body;

        // Get trip details with load and organization
        const { data: trip, error: tripError } = await supabase
            .from("trips")
            .select(`
        *,
        load:loads(*),
        truck:trucks(*),
        driver:profiles(*),
        organization:organizations(*)
      `)
            .eq("id", trip_id)
            .single();

        if (tripError || !trip) {
            return new Response(
                JSON.stringify({ error: "Trip not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Get expenses for this trip
        const { data: expenses } = await supabase
            .from("expenses")
            .select("*")
            .eq("trip_id", trip_id);

        // Calculate totals
        const load = trip.load;
        const lineHaul = Number(load?.primary_rate || 0);
        const fuelSurcharge = Number(load?.fuel_surcharge || 0);
        const detentionHours = Number(trip.detention_hours || 0);
        const detentionRate = Number(load?.detention_rate_per_hour || 0);
        const detentionCharges = detentionHours * detentionRate;

        // Reimbursable expenses
        const reimbursableExpenses = (expenses || [])
            .filter((e: any) => e.is_reimbursable)
            .reduce((sum: number, e: any) => sum + Number(e.amount), 0);

        const subtotal = lineHaul + fuelSurcharge;
        const totalAmount = subtotal + detentionCharges + reimbursableExpenses;

        // Generate invoice number
        const invoiceNumber = `INV-${Date.now().toString(36).toUpperCase()}`;

        // Create PDF
        const pdfDoc = await PDFDocument.create();
        const page = pdfDoc.addPage([612, 792]); // Letter size
        const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
        const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

        const org = trip.organization;
        let y = 750;
        const leftMargin = 50;
        const rightMargin = 562;

        // Header - Company Info
        page.drawText(org?.name || "TruckMate Carrier", {
            x: leftMargin,
            y,
            size: 24,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });
        y -= 20;

        page.drawText(org?.legal_entity_name || "", {
            x: leftMargin,
            y,
            size: 10,
            font,
            color: rgb(0.3, 0.3, 0.3),
        });
        y -= 15;

        page.drawText(`MC: ${org?.mc_dot_number || "N/A"}`, {
            x: leftMargin,
            y,
            size: 10,
            font,
            color: rgb(0.3, 0.3, 0.3),
        });
        y -= 30;

        // Invoice Title
        page.drawText("INVOICE", {
            x: rightMargin - 100,
            y: 750,
            size: 28,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });

        page.drawText(`#${invoiceNumber}`, {
            x: rightMargin - 100,
            y: 725,
            size: 12,
            font,
            color: rgb(0.3, 0.3, 0.3),
        });

        // Bill To
        y = 650;
        page.drawText("BILL TO:", {
            x: leftMargin,
            y,
            size: 12,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });
        y -= 18;

        page.drawText(load?.broker_name || "N/A", {
            x: leftMargin,
            y,
            size: 11,
            font,
        });
        y -= 15;

        page.drawText(`MC: ${load?.broker_mc_number || "N/A"}`, {
            x: leftMargin,
            y,
            size: 10,
            font,
            color: rgb(0.4, 0.4, 0.4),
        });

        // Invoice Details
        y = 650;
        const detailsX = 350;

        const details = [
            ["Invoice Date:", new Date().toLocaleDateString()],
            ["Due Date:", new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toLocaleDateString()],
            ["Load #:", load?.broker_load_id || "N/A"],
            ["Trip ID:", trip_id.substring(0, 8)],
        ];

        for (const [label, value] of details) {
            page.drawText(label, { x: detailsX, y, size: 10, font: boldFont });
            page.drawText(value as string, { x: detailsX + 80, y, size: 10, font });
            y -= 15;
        }

        // Shipment Info
        y = 550;
        page.drawLine({
            start: { x: leftMargin, y },
            end: { x: rightMargin, y },
            thickness: 1,
            color: rgb(0.8, 0.8, 0.8),
        });
        y -= 20;

        page.drawText("SHIPMENT DETAILS", {
            x: leftMargin,
            y,
            size: 12,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });
        y -= 20;

        const shipmentDetails = [
            ["Origin:", trip.origin_address || "N/A"],
            ["Destination:", trip.destination_address || "N/A"],
            ["Miles:", `${trip.total_miles || 0} miles`],
            ["Commodity:", load?.commodity_type || "N/A"],
            ["Weight:", `${load?.weight_lbs || 0} lbs`],
        ];

        for (const [label, value] of shipmentDetails) {
            page.drawText(label, { x: leftMargin, y, size: 10, font: boldFont });
            page.drawText(value as string, { x: leftMargin + 80, y, size: 10, font });
            y -= 15;
        }

        // Charges Table
        y = 400;
        page.drawLine({
            start: { x: leftMargin, y },
            end: { x: rightMargin, y },
            thickness: 1,
            color: rgb(0.8, 0.8, 0.8),
        });
        y -= 20;

        page.drawText("CHARGES", {
            x: leftMargin,
            y,
            size: 12,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });

        page.drawText("AMOUNT", {
            x: rightMargin - 80,
            y,
            size: 12,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });
        y -= 25;

        const charges = [
            ["Line Haul", lineHaul],
            ["Fuel Surcharge", fuelSurcharge],
        ];

        if (detentionCharges > 0) {
            charges.push([`Detention (${detentionHours} hrs @ $${detentionRate}/hr)`, detentionCharges]);
        }

        if (reimbursableExpenses > 0) {
            charges.push(["Reimbursable Expenses", reimbursableExpenses]);
        }

        for (const [desc, amount] of charges) {
            page.drawText(desc as string, { x: leftMargin, y, size: 11, font });
            page.drawText(`$${(amount as number).toFixed(2)}`, {
                x: rightMargin - 70,
                y,
                size: 11,
                font,
            });
            y -= 18;
        }

        // Total
        y -= 10;
        page.drawLine({
            start: { x: 350, y },
            end: { x: rightMargin, y },
            thickness: 2,
            color: rgb(0.1, 0.2, 0.4),
        });
        y -= 20;

        page.drawText("TOTAL DUE:", {
            x: 350,
            y,
            size: 14,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });

        page.drawText(`$${totalAmount.toFixed(2)}`, {
            x: rightMargin - 80,
            y,
            size: 14,
            font: boldFont,
            color: rgb(0.1, 0.2, 0.4),
        });

        // Payment Terms
        y = 150;
        page.drawText("PAYMENT TERMS", {
            x: leftMargin,
            y,
            size: 10,
            font: boldFont,
        });
        y -= 15;

        page.drawText(`Payment due within ${load?.payment_terms || "Net 30"} days.`, {
            x: leftMargin,
            y,
            size: 9,
            font,
            color: rgb(0.4, 0.4, 0.4),
        });

        // Footer
        page.drawText("Thank you for your business!", {
            x: 250,
            y: 50,
            size: 10,
            font,
            color: rgb(0.4, 0.4, 0.4),
        });

        // Save PDF
        const pdfBytes = await pdfDoc.save();
        const pdfBase64 = btoa(String.fromCharCode(...pdfBytes));

        // Upload to Supabase Storage
        const pdfPath = `invoices/${trip.organization_id}/${invoiceNumber}.pdf`;
        const { error: uploadError } = await supabase.storage
            .from("documents")
            .upload(pdfPath, pdfBytes, {
                contentType: "application/pdf",
                upsert: true,
            });

        if (uploadError) {
            console.error("PDF upload error:", uploadError);
        }

        // Create invoice record
        const { data: invoice, error: invoiceError } = await supabase
            .from("invoices")
            .insert({
                organization_id: trip.organization_id,
                trip_id,
                load_id: load?.id,
                invoice_number: invoiceNumber,
                subtotal,
                detention_charges: detentionCharges,
                reimbursable_expenses: reimbursableExpenses,
                total_amount: totalAmount,
                recipient_name: load?.broker_name,
                pdf_path: pdfPath,
                status: send_for_approval ? "draft" : "sent",
                due_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            })
            .select()
            .single();

        return new Response(
            JSON.stringify({
                success: true,
                invoice_id: invoice?.id,
                invoice_number: invoiceNumber,
                total_amount: totalAmount,
                pdf_path: pdfPath,
                pdf_base64: pdfBase64,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Invoice generation error:", error);
        return new Response(
            JSON.stringify({ error: error.message || "Invoice generation failed" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));
