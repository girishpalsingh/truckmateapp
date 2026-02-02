
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
            stop_id,              // Optional: specific stop this detention occurred at
            invoice_details,      // Optional overrides: { rate_per_hour, po_number, bol_number, broker_email }
            send_email            // Optional: if true, send invoice immediately
        } = body;

        if (!detention_record_id) {
            throw new Error("Missing detention_record_id");
        }

        // 1. Fetch Detention Record with related data including load's detention rate
        // Fetch detention record with all related data including reference numbers
        const { data: record, error: recError } = await supabase
            .from('detention_records')
            .select(`
                *, 
                loads(*, rate_confirmations(*, rc_risk_clauses(*), rc_references(*))),
                organizations(*)
            `)
            .eq('id', detention_record_id)
            .single();

        if (recError || !record) throw new Error(`Detention record not found: ${recError?.message}`);

        const org = record.organizations;
        const load = record.loads;
        const organizationId = record.organization_id;

        // Update stop_id on detention record if provided
        if (stop_id && !record.stop_id) {
            await supabase
                .from('detention_records')
                .update({ stop_id })
                .eq('id', detention_record_id);
            record.stop_id = stop_id;
        }

        // ===============================================================
        // AUTO-CALCULATE: Rate and Hours from Database
        // ===============================================================

        // Calculate total hours from detention record times
        if (!record.start_time || !record.end_time) {
            throw new Error("Detention record must have both start_time and end_time");
        }
        
        const startTime = new Date(record.start_time);
        const endTime = new Date(record.end_time);
        const totalHours = (endTime.getTime() - startTime.getTime()) / (1000 * 60 * 60);
        
        // Free time allowance (typically 2 hours) - could be configured per rate con
        const freeTimeHours = 2.0;
        const payableHours = Math.max(0, totalHours - freeTimeHours);

        // Get detention rate from: 1) invoice_details override, 2) load.detention_rate_per_hour, 3) default
        const ratePerHour = invoice_details?.rate_per_hour || load?.detention_rate_per_hour || 75.00;
        
        // Calculate total due
        const totalDue = payableHours * ratePerHour;
        const currency = invoice_details?.currency || 'USD';

        // Try to extract broker email from rate con if not provided
        let brokerEmail = invoice_details?.broker_email;
        if (!brokerEmail && load?.rate_confirmations?.broker_email) {
            brokerEmail = load.rate_confirmations.broker_email;
        }

        // Try to get facility name/address from stop data
        // Priority: 1) stop_id lookup, 2) load's rate con stops
        let facilityAddress = invoice_details?.facility_address;
        let facilityName = invoice_details?.facility_name;

        // First, try direct stop_id lookup if available
        const effectiveStopId = stop_id || record.stop_id;
        if ((!facilityAddress || !facilityName) && effectiveStopId) {
            const { data: stopData } = await supabase
                .from('rc_stops')
                .select('facility_address, contact_name, stop_type')
                .eq('stop_id', effectiveStopId)
                .maybeSingle();

            if (stopData) {
                facilityAddress = facilityAddress || stopData.facility_address;
                facilityName = facilityName || stopData.contact_name || `${stopData.stop_type || 'Stop'} Facility`;
            }
        }

        // Fallback: Get facility info from load's rate confirmation stops
        const rateConUuid = load?.rate_confirmations?.id;
        if (!facilityAddress && rateConUuid) {
            const { data: stopsData } = await supabase
                .from('rc_stops')
                .select('facility_address, contact_name, stop_type, stop_sequence')
                .eq('rate_confirmation_id', rateConUuid)
                .order('stop_sequence', { ascending: true });

            if (stopsData && stopsData.length > 0) {
                const firstStop = stopsData[0];
                facilityAddress = facilityAddress || firstStop.facility_address;
                facilityName = facilityName || firstStop.contact_name || `${firstStop.stop_type || 'Stop'} Location`;
            }
        }

        // Final fallbacks
        facilityAddress = facilityAddress || 'Address not available';
        facilityName = facilityName || 'Facility';

        // 2. Prepare Data for Template
        const formatDate = (d: string) => {
            if (!d) return '-';
            return new Date(d).toLocaleString('en-US', {
                timeZone: 'America/Los_Angeles',
                year: 'numeric', month: 'short', day: 'numeric',
                hour: '2-digit', minute: '2-digit'
            });
        };

        // Generate unique invoice number
        const invoiceNumber = `DET-${Date.now().toString().slice(-8)}`;

        // Extract reference numbers from rate confirmation
        const rateConRefs = load?.rate_confirmations?.rc_references || [];
        const referenceNumbers = rateConRefs.map((ref: any) => ({
            refType: ref.ref_type || 'REF',
            refValue: ref.ref_value || 'N/A'
        }));

        // Check if we have any reference numbers to display
        const hasReferenceNumbers = referenceNumbers.length > 0;

        const templateData = {
            orgName: org?.name || 'TruckMate',
            orgAddress: typeof org?.registered_address === 'string'
                ? org.registered_address
                : org?.registered_address?.address_line1 || '',
            orgLogoUrl: org?.logo_image_link || '',
            invoiceNumber,
            generatedDate: new Date().toLocaleDateString(),
            brokerName: load?.broker_name || 'N/A',
            brokerMcNumber: load?.rate_confirmations?.broker_mc || null,
            loadNumber: load?.broker_load_id || 'N/A',
            rateConId: load?.rate_confirmations?.rc_id || null,
            poNumber: invoice_details?.po_number || load?.rate_confirmations?.po_number || null,
            bolNumber: invoice_details?.bol_number || load?.rate_confirmations?.bol_number || null,
            referenceNumbers,
            hasReferenceNumbers,
            facilityName: facilityName || 'N/A',
            facilityAddress: facilityAddress || 'N/A',
            startTime: formatDate(record.start_time),
            endTime: formatDate(record.end_time),
            startCoordinates: `${record.start_location_lat?.toFixed(5) || 'N/A'}, ${record.start_location_lng?.toFixed(5) || 'N/A'}`,
            endCoordinates: `${record.end_location_lat?.toFixed(5) || 'N/A'}, ${record.end_location_lng?.toFixed(5) || 'N/A'}`,
            totalDuration: `${totalHours.toFixed(2)} hrs`,
            freeTime: `${freeTimeHours.toFixed(2)} hrs`,
            ratePerHour: ratePerHour.toFixed(2),
            payableHours: payableHours.toFixed(2),
            totalDue: totalDue.toFixed(2),
            currency,
            photoUrl: record.evidence_photo_url,
            photoTime: formatDate(record.evidence_photo_time),
        };

        // Get signed URL for logo if it's a storage path
        if (templateData.orgLogoUrl && !templateData.orgLogoUrl.startsWith('http')) {
            const { data: signed } = await supabase.storage.from('assets').createSignedUrl(templateData.orgLogoUrl, 3600);
            if (signed) {
                templateData.orgLogoUrl = signed.signedUrl;
                // Fix for local development
                if (templateData.orgLogoUrl.includes('kong')) {
                    templateData.orgLogoUrl = templateData.orgLogoUrl.replace(/https?:\/\/[^\/]+/, 'http://host.docker.internal:54321');
                }
            }
        }

        // Get signed URL for photo if it's a storage path
        if (templateData.photoUrl && !templateData.photoUrl.startsWith('http')) {
            const { data: signed } = await supabase.storage.from('documents').createSignedUrl(templateData.photoUrl, 3600);
            if (signed) {
                templateData.photoUrl = signed.signedUrl;
                if (templateData.photoUrl.includes('kong')) {
                    templateData.photoUrl = templateData.photoUrl.replace(/https?:\/\/[^\/]+/, 'http://host.docker.internal:54321');
                }
            }
        }

        // 3. Render HTML
        const compiledTemplate = Handlebars.compile(invoiceTemplate);
        const htmlContent = compiledTemplate(templateData);

        // 4. Generate PDF
        const fileName = `${organizationId}/${load?.id || 'unknown'}/detention_invoices/${invoiceNumber}.pdf`;
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

        if (!pdfResponse.ok) {
            const errText = await pdfResponse.text();
            throw new Error(`PDF generation failed: ${errText}`);
        }

        // 5. Create Database Invoice Record
        const { data: invoiceRecord, error: invError } = await supabase
            .from('detention_invoices')
            .insert({
                organization_id: organizationId,
                detention_record_id: detention_record_id,
                load_id: record.load_id,
                invoice_number: invoiceNumber,
                detention_invoice_display_number: invoiceNumber,
                po_number: invoice_details?.po_number || load?.rate_confirmations?.po_number,
                bol_number: invoice_details?.bol_number || load?.rate_confirmations?.bol_number,
                facility_name: facilityName,
                facility_address: facilityAddress,
                start_time: record.start_time,
                end_time: record.end_time,
                start_location_lat: record.start_location_lat,
                start_location_lng: record.start_location_lng,
                end_location_lat: record.end_location_lat,
                end_location_lng: record.end_location_lng,
                detention_photo_link: record.evidence_photo_url,
                detention_photo_time: record.evidence_photo_time,
                amount: totalDue,
                total_due: totalDue,
                rate_per_hour: ratePerHour,
                total_hours: totalHours,
                payable_hours: payableHours,
                currency: currency,
                pdf_url: fileName,
                broker_email: brokerEmail,
                status: 'APPROVED'
            })
            .select()
            .single();

        if (invError) throw invError;

        // 6. Get Signed URL for Response
        const { data: signedUrlData } = await supabase.storage.from('documents').createSignedUrl(fileName, 30 * 24 * 3600);
        let finalUrl = signedUrlData?.signedUrl || fileName;

        // Fix for local development
        if (finalUrl.includes('http://kong:8000')) {
            finalUrl = finalUrl.replace('http://kong:8000', 'http://127.0.0.1:54321');
        }

        // 7. Send email if requested
        let emailSent = false;
        if (send_email && brokerEmail) {
            try {
                const emailResponse = await fetch(`${supabaseUrl}/functions/v1/send-email`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${supabaseServiceKey}`
                    },
                    body: JSON.stringify({
                        to: brokerEmail,
                        subject: `Detention Invoice ${invoiceNumber} - Load #${load?.broker_load_id || 'N/A'}`,
                        html: `
                            <h2>Detention Invoice</h2>
                            <p>Please find attached the detention invoice for Load #${load?.broker_load_id || 'N/A'}.</p>
                            <p><strong>Invoice Number:</strong> ${invoiceNumber}</p>
                            <p><strong>Total Due:</strong> $${totalDue.toFixed(2)}</p>
                            <p><a href="${finalUrl}">View/Download Invoice PDF</a></p>
                            <br/>
                            <p>Thank you for your business.</p>
                        `
                    })
                });

                if (emailResponse.ok) {
                    emailSent = true;
                    // Update invoice status to SENT
                    await supabase
                        .from('detention_invoices')
                        .update({ status: 'SENT', sent_at: new Date().toISOString() })
                        .eq('id', invoiceRecord.id);
                }
            } catch (emailError) {
                console.error('Email sending failed:', emailError);
                // Don't fail the whole request if email fails
            }
        }

        // 8. Send notification to user
        const notificationService = new NotificationService(supabase);
        await notificationService.sendNotification({
            userId: profile.id,
            organizationId: organizationId,
            title: "Detention Invoice Created",
            body: `Invoice ${invoiceNumber} for $${totalDue.toFixed(2)} has been generated.`,
            data: {
                invoice_id: invoiceRecord.id,
                action: 'open_detention_invoice',
                url: finalUrl,
                email_sent: emailSent
            },
            type: 'detention_invoice'
        });

        return new Response(
            JSON.stringify({
                success: true,
                invoice_id: invoiceRecord.id,
                invoice_number: invoiceNumber,
                url: finalUrl,
                amount: totalDue,
                email_sent: emailSent,
                broker_email: emailSent ? brokerEmail : null
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