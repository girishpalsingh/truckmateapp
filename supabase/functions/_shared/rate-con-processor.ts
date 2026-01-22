import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { NotificationService } from './notification-service.ts';
import { parseNumeric, parseTime, parseDate } from './utils.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

export async function processRateCon(
    documentId: string,
    extractedData: any, // JSON object from LLM
    organizationId: string,
    userId?: string | null
) {
    console.log(`Processing Rate Con for Doc ID: ${documentId}, Org: ${organizationId}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into rate_cons
    // Map extractedData fields to table columns
    // Note: LLM output keys might not match exactly, we should try to match flexibly or assume prompt exact match.
    // The prompt `rate_con.ts` defines specific fields. We'll map them.

    const rateConData = {
        organization_id: organizationId,

        broker_name: extractedData.broker_name || null,
        broker_mc_number: extractedData.broker_mc_number || null,
        load_id: extractedData.load_id || null,

        carrier_name: extractedData.carrier_name || null,
        carrier_mc_number: extractedData.carrier_mc_number || null,

        pickup_address: extractedData.pickup_address || null,
        pickup_date: parseDate(extractedData.pickup_date),
        pickup_time: parseTime(extractedData.pickup_time),

        delivery_address: extractedData.delivery_address || null,
        delivery_date: parseDate(extractedData.delivery_date),
        delivery_time: parseTime(extractedData.delivery_time),

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
        overall_traffic_light: extractedData.overall_traffic_light || 'UNKNOWN',
    };

    console.log("Inserting Rate Con Data:", JSON.stringify(rateConData));

    const { data: rateCon, error: rateConError } = await supabase
        .from('rate_cons')
        .insert(rateConData)
        .select()
        .single();

    if (rateConError) {
        console.error("Error inserting rate_cons:", rateConError);
        throw new Error(`Failed to insert rate con data: ${rateConError.message}`);
    }

    console.log("Rate Con inserted:", rateCon.id);

    // 1.1 Insert Bad Clauses
    if (extractedData.bad_clauses_found && Array.isArray(extractedData.bad_clauses_found) && extractedData.bad_clauses_found.length > 0) {
        console.log(`Inserting ${extractedData.bad_clauses_found.length} clauses...`);

        const clausesData = extractedData.bad_clauses_found.map((clause: any) => ({
            rate_con_id: rateCon.id,
            clause_type: clause.clause_type,
            traffic_light: clause.traffic_light,
            clause_title: clause.clause_title,
            clause_title_punjabi: clause.clause_title_punjabi,
            danger_simple_language: clause.danger_simple_language,
            danger_simple_punjabi: clause.danger_simple_punjabi,
            original_text: clause.original_text,
            notification_data: clause.notification,

            // Map explicit notification fields
            notification_title: clause.notification?.title || null,
            notification_description: clause.notification?.description || null,
            notification_trigger_type: clause.notification?.trigger_type || null,
            notification_deadline: parseDate(clause.notification?.deadline_iso), // Ensure valid date
            notification_relative_offset: clause.notification?.relative_minutes_offset ? parseInt(String(clause.notification.relative_minutes_offset)) : null,
            notification_start_event: clause.notification?.notification_start_event || null
        }));

        const { error: clausesError } = await supabase
            .from('rate_con_clauses')
            .insert(clausesData);

        if (clausesError) {
            console.error("Error inserting clauses:", clausesError);
            // Non-fatal, but good to know
        } else {
            console.log("Clauses inserted successfully");
        }
    }

    // 2. Create Notification using shared service
    const notificationService = new NotificationService(supabase);

    await notificationService.sendNotification({
        userId: userId || undefined, // undefined falls back to org (or we might want explicit null handling in service)
        // Actually based on my service logic: user_id: params.userId (can be null)
        // If I pass null here, it goes as null to DB -> Global Org Notification
        // If I want to restrict to JUST this user, I should ensure userId is passed.
        // If userId is null (legacy/system upload?), maybe it SHOULD be org wide?
        // Plan said: "Target notifications to the specific user".
        // Implementation: RLS restricts org-wide view if user_id is null?
        // My RLS: user_id IS NULL (Global) OR user_id = auth.uid()
        // So if userId is null, everyone sees it.
        // If userId is provided, ONLY that user sees it.
        // Perfect.
        organizationId: organizationId,
        title: "New Rate Confirmation",
        body: `Rate Con from ${rateConData.broker_name || 'Unknown Broker'} is ready for review.`,
        data: {
            rate_con_id: rateCon.id,
            document_id: documentId,
            traffic_light: extractedData.overall_traffic_light || 'UNKNOWN',
        },
        type: 'rate_con_review'
    });

    console.log("Notification request sent.");

    return rateCon;
}
