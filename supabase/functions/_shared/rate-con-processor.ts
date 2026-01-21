import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

export async function processRateCon(
    documentId: string,
    extractedData: any, // JSON object from LLM
    organizationId: string
) {
    console.log(`Processing Rate Con for Doc ID: ${documentId}, Org: ${organizationId}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into rate_cons
    // Map extractedData fields to table columns
    // Note: LLM output keys might not match exactly, we should try to match flexibly or assume prompt exact match.
    // The prompt `rate_con.ts` defines specific fields. We'll map them.

    // Helper to parser numeric values robustly
    const parseNumeric = (val: any): number | null => {
        if (val === null || val === undefined) return null;
        if (typeof val === 'number') return val;
        if (typeof val === 'string') {
            // Remove all non-numeric characters except dot and minus
            const clean = val.replace(/[^0-9.-]/g, '');
            const parsed = parseFloat(clean);
            return isNaN(parsed) ? null : parsed;
        }
        return null;
    };

    const rateConData = {
        organization_id: organizationId,

        broker_name: extractedData.broker_name || null,
        broker_mc_number: extractedData.broker_mc_number || null,
        load_id: extractedData.load_id || null,

        carrier_name: extractedData.carrier_name || null,
        carrier_mc_number: extractedData.carrier_mc_number || null,

        pickup_address: extractedData.pickup_address || null,
        pickup_date: extractedData.pickup_date || null,
        pickup_time: extractedData.pickup_time || null,

        delivery_address: extractedData.delivery_address || null,
        delivery_date: extractedData.delivery_date || null,
        delivery_time: extractedData.delivery_time || null,

        rate_amount: parseNumeric(extractedData.rate_amount),
        rate_amount_raw: extractedData.rate_amount ? String(extractedData.rate_amount) : null,
        commodity: extractedData.commodity || null,
        weight: parseNumeric(extractedData.weight),
        weight_raw: extractedData.weight ? String(extractedData.weight) : null,

        detention_limit: parseNumeric(extractedData.detention_limit),
        detention_limit_raw: extractedData.detention_limit ? String(extractedData.detention_limit) : null,
        detention_amount_per_hour: parseNumeric(extractedData.detention_amount_per_hour),
        detention_amount_per_hour_raw: extractedData.detention_amount_per_hour ? String(extractedData.detention_amount_per_hour) : null,

        fine_amount: parseNumeric(extractedData.fine_amount),
        fine_amount_raw: extractedData.fine_amount ? String(extractedData.fine_amount) : null,
        fine_description: extractedData.fine_description || null,

        contacts: extractedData.contacts ? extractedData.contacts : null,
        notes: extractedData.notes || null,
        instructions: extractedData.instructions || null,
        parsed_text: JSON.stringify(extractedData),
    };

    console.log("Inserting Rate Con Data:", JSON.stringify(rateConData));

    const { data: rateCon, error: rateConError } = await supabase
        .from('rate_cons')
        .insert(rateConData)
        .select()
        .single();

    if (rateConError) {
        console.error("Error inserting rate_cons:", rateConError);
        // We don't throw here to avoid failing the whole document process, but we log it.
        // Or maybe we should throw to indicate failure? 
        // Let's log and let the notification be about failure? 
        // For now, let's throw so it bubbles up.
        throw new Error(`Failed to insert rate con data: ${rateConError.message}`);
    }

    console.log("Rate Con inserted:", rateCon.id);

    // 2. Create Notification
    // "If app is active then a screen comes in front of user... else we send a notification"
    // Since we are in backend, we just create a notification. The mobile app will listen to INSERT on notifications table (Realtime).
    // If the app is open, it gets the event and shows the screen.
    // If closed, this table entry acts as the "unread notification" history.
    // We can also trigger push notification here if we had FCM set up, but for now we rely on Supabase Realtime + Table.

    const notificationPayload = {
        organization_id: organizationId,
        title: "New Rate Confirmation",
        body: `Rate Con from ${rateConData.broker_name || 'Unknown Broker'} is ready for review.`,
        data: {
            type: 'rate_con_review',
            rate_con_id: rateCon.id,
            document_id: documentId,
            traffic_light: extractedData.overall_traffic_light || 'UNKNOWN',
        }
    };

    const { error: notifyError } = await supabase
        .from('notifications')
        .insert(notificationPayload);

    if (notifyError) {
        console.error("Error creating notification:", notifyError);
        // Non-critical, so we don't throw
    } else {
        console.log("Notification created.");
    }

    return rateCon;
}
