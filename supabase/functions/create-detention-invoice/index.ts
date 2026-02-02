
import { createClient } from "@supabase/supabase-js";
import Handlebars from "https://esm.sh/handlebars@4.7.7";
import { withLogging } from "../_shared/logger.ts";
import { NotificationService } from "../_shared/notification-service.ts";
import { authorizeRole } from "../_shared/utils.ts";
import { invoiceTemplate } from "./templates/invoice-template.ts";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => withLogging(req, async (req) => {
    if (req.method === "OPTIONS") {
        return new Response(null, { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
        const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
        const PDF_SERVICE_URL = Deno.env.get("PDF_SERVICE_URL") || `${supabaseUrl}/functions/v1/generate-pdf`;

        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        const { profile } = await authorizeRole(req, supabase, ['dispatcher', 'admin', 'owner', 'driver']);

        const body = await req.json();
        const {
            detention_record_id,
            invoice_details // { rate_per_hour, total_hours, payable_hours, total_due, currency, bol_number, etc. }
        } = body;

        if (!detention_record_id || !invoice_details) {
            throw new Error("Missing detention_record_id or invoice_details");
        }

        // 1. Fetch Request Data
        const { data: record, error: recError } = await supabase
            .from('detention_records')
            .select('*, loads(*), organizations(*)')
            .eq('id', detention_record_id)
            .single();

        if (recError || !record) throw new Error("Detention record not found");

        const org = record.organizations;
        const load = record.loads;
        const organizationId = record.organization_id;

        // 2. Prepare Data for Template
        const formatDate = (d: string) => {
            if (!d) return '-';
            return new Date(d).toLocaleString('en-US', {
                timeZone: 'America/Los_Angeles',
                year: 'numeric', month: 'short', day: 'numeric',
                hour: '2-digit', minute: '2-digit'
            });
        };

        const templateData = {
            orgName: org.name,
            orgAddress: org.registered_address, // You might want to format this
            orgLogoUrl: org.logo_image_link, // You might need signed URL logic here similar to dispatch sheet
            invoiceNumber: `DET-${Date.now().toString().slice(-6)}`,
            generatedDate: new Date().toLocaleDateString(),
            brokerName: load.broker_name || 'N/A',
            loadNumber: load.broker_load_id || 'N/A',
            bolNumber: invoice_details.bol_number || 'N/A',
            facilityAddress: invoice_details.facility_address || 'N/A',
            startTime: formatDate(record.start_time),
            endTime: formatDate(record.end_time),
            totalDuration: `${Number(invoice_details.total_hours).toFixed(2)} hrs`,
            ratePerHour: invoice_details.rate_per_hour,
            payableHours: invoice_details.payable_hours,
            totalDue: Number(invoice_details.total_due).toFixed(2),
            photoUrl: record.evidence_photo_url, // You might need signed URL for this too
            photoTime: formatDate(record.evidence_photo_time),
        };

        // Logo Logic (Simplified from dispatch sheet)
        if (templateData.orgLogoUrl && !templateData.orgLogoUrl.startsWith('http')) {
            const { data: signed } = await supabase.storage.from('assets').createSignedUrl(templateData.orgLogoUrl, 3600);
            if (signed) templateData.orgLogoUrl = signed.signedUrl;
        }

        // Photo Logic
        if (templateData.photoUrl && !templateData.photoUrl.startsWith('http')) {
            // Assuming bucket 'detention_evidence' or 'documents'
            const { data: signed } = await supabase.storage.from('documents').createSignedUrl(templateData.photoUrl, 3600);
            if (signed) templateData.photoUrl = signed.signedUrl;
        }

        // 3. Render HTML
        const compiledTemplate = Handlebars.compile(invoiceTemplate);
        const htmlContent = compiledTemplate(templateData);

        // 4. Generate PDF
        const fileName = `${organizationId}/${detention_record_id}/detention_invoice.pdf`;
        const pdfResponse = await fetch(PDF_SERVICE_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${supabaseServiceKey}`
            },
            body: JSON.stringify({
                bucketName: "documents",
                uploadPath: fileName,
                html: htmlContent,
            })
        });

        if (!pdfResponse.ok) throw new Error("PDF generation failed");

        // 5. Create Database Record
        const { data: invoiceRecord, error: invError } = await supabase
            .from('detention_invoices')
            .insert({
                organization_id: organizationId,
                detention_record_id: detention_record_id,
                load_id: record.load_id,
                invoice_number: templateData.invoiceNumber,
                detention_invoice_display_number: templateData.invoiceNumber,
                amount: invoice_details.total_due,
                total_due: invoice_details.total_due,
                rate_per_hour: invoice_details.rate_per_hour,
                total_hours: invoice_details.total_hours,
                payable_hours: invoice_details.payable_hours,
                bol_number: invoice_details.bol_number,
                facility_address: invoice_details.facility_address,
                detention_photo_link: record.evidence_photo_url,
                pdf_url: fileName,
                status: 'APPROVED'
            })
            .select()
            .single();

        if (invError) throw invError;

        // 6. Get Signed URL for Response
        const { data: signedUrlData } = await supabase.storage.from('documents').createSignedUrl(fileName, 3600);

        return new Response(
            JSON.stringify({
                success: true,
                invoice_id: invoiceRecord.id,
                url: signedUrlData?.signedUrl,
                amount: invoice_details.total_due
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );

    } catch (error) {
        console.error("Error creating detention invoice:", error);
        return new Response(
            JSON.stringify({ error: (error as any).message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
}));