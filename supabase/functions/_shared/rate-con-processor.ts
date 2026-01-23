import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { NotificationService } from './notification-service.ts';
import { parseNumeric, parseTime, parseDate } from './utils.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

/**
 * Process Rate Confirmation data from Gemini and insert into normalized tables
 */
export async function processRateCon(
    documentId: string,
    extractedData: any,
    organizationId: string,
    userId?: string | null
) {
    console.log(`Processing Rate Con for Doc ID: ${documentId}, Org: ${organizationId}`);
    console.log('Extracted Data:', JSON.stringify(extractedData, null, 2));

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into rate_confirmations (main table)
    const rateConData = {
        rate_con_id: extractedData.rate_con_id || `RC-${Date.now()}`,
        document_id: documentId,
        organization_id: organizationId,

        // Broker Details
        broker_name: extractedData.broker_details?.broker_name || null,
        broker_mc_number: extractedData.broker_details?.broker_mc_number || null,
        broker_address: extractedData.broker_details?.address || null,
        broker_phone: extractedData.broker_details?.phone || null,
        broker_email: extractedData.broker_details?.email || null,

        // Carrier Details
        carrier_name: extractedData.carrier_details?.carrier_name || null,
        carrier_dot_number: extractedData.carrier_details?.carrier_dot_number || null,
        carrier_address: extractedData.carrier_details?.address || null,
        carrier_phone: extractedData.carrier_details?.phone || null,
        carrier_email: extractedData.carrier_details?.email || null,
        carrier_equipment_type: extractedData.carrier_details?.equipment_type || null,
        carrier_equipment_number: extractedData.carrier_details?.equipment_number || null,

        // Financials
        total_rate_amount: parseNumeric(extractedData.financials?.total_rate_amount),
        currency: extractedData.financials?.currency || 'USD',
        payment_terms: extractedData.financials?.payment_terms || null,

        // Commodity
        commodity_name: extractedData.commodity_details?.commodity || null,
        commodity_weight: parseNumeric(extractedData.commodity_details?.weight),
        commodity_unit: extractedData.commodity_details?.unit || null,
        pallet_count: extractedData.commodity_details?.pallet_count ? parseInt(String(extractedData.commodity_details.pallet_count)) : null,

        // Risk
        overall_traffic_light: extractedData.risk_analysis?.overall_traffic_light || extractedData.overall_traffic_light || null,

        status: 'under_review',
    };

    console.log("Inserting Rate Confirmation Data:", JSON.stringify(rateConData));

    const { data: rateCon, error: rateConError } = await supabase
        .from('rate_confirmations')
        .insert(rateConData)
        .select()
        .single();

    if (rateConError) {
        console.error("Error inserting rate_confirmations:", rateConError);
        throw new Error(`Failed to insert rate confirmation: ${rateConError.message}`);
    }

    console.log("Rate Confirmation inserted:", rateCon.id);
    const rateConfirmationId = rateCon.id;

    // 2. Insert Reference Numbers
    if (extractedData.reference_numbers && Array.isArray(extractedData.reference_numbers)) {
        console.log(`Inserting ${extractedData.reference_numbers.length} reference numbers...`);

        const refNumbersData = extractedData.reference_numbers.map((ref: any) => ({
            rate_confirmation_id: rateConfirmationId,
            ref_type: ref.type || null,
            ref_value: ref.value || null,
        }));

        const { error: refError } = await supabase
            .from('reference_numbers')
            .insert(refNumbersData);

        if (refError) {
            console.error("Error inserting reference_numbers:", refError);
        } else {
            console.log("Reference numbers inserted successfully");
        }
    }

    // 3. Insert Stops
    if (extractedData.stops && Array.isArray(extractedData.stops)) {
        console.log(`Inserting ${extractedData.stops.length} stops...`);

        const stopsData = extractedData.stops.map((stop: any, index: number) => ({
            rate_confirmation_id: rateConfirmationId,
            sequence_number: index + 1,
            stop_type: stop.stop_type === 'Pickup' ? 'Pickup' : 'Delivery',
            address: stop.address || null,
            contact_person: stop.contact_person || null,
            phone: stop.phone || null,
            email: stop.email || null,
            scheduled_arrival: parseDate(stop.scheduled_arrival),
            scheduled_departure: parseDate(stop.scheduled_departure),
            date_raw: stop.date || null,
            time_raw: stop.time || null,
            special_instructions: stop.special_instructions || null,
        }));

        const { error: stopsError } = await supabase
            .from('stops')
            .insert(stopsData);

        if (stopsError) {
            console.error("Error inserting stops:", stopsError);
        } else {
            console.log("Stops inserted successfully");
        }
    }

    // 4. Insert Charges
    if (extractedData.financials?.charges && Array.isArray(extractedData.financials.charges)) {
        console.log(`Inserting ${extractedData.financials.charges.length} charges...`);

        const chargesData = extractedData.financials.charges.map((charge: any) => ({
            rate_confirmation_id: rateConfirmationId,
            description: charge.description || null,
            amount: parseNumeric(charge.amount),
        }));

        const { error: chargesError } = await supabase
            .from('charges')
            .insert(chargesData);

        if (chargesError) {
            console.error("Error inserting charges:", chargesError);
        } else {
            console.log("Charges inserted successfully");
        }
    }

    // 5. Insert Risk Clauses and their Notifications
    const clausesFound = extractedData.risk_analysis?.clauses_found || extractedData.clauses_found || extractedData.bad_clauses_found;

    if (clausesFound && Array.isArray(clausesFound) && clausesFound.length > 0) {
        console.log(`Inserting ${clausesFound.length} risk clauses...`);

        for (const clause of clausesFound) {
            // Insert risk clause
            const clauseData = {
                rate_confirmation_id: rateConfirmationId,
                clause_type: clause.clause_type || null,
                traffic_light: clause.traffic_light || 'YELLOW',
                clause_title: clause.clause_title || null,
                clause_title_punjabi: clause.clause_title_punjabi || null,
                danger_simple_language: clause.danger_simple_language || null,
                danger_simple_punjabi: clause.danger_simple_punjabi || null,
                original_text: clause.original_text || null,
            };

            const { data: riskClause, error: clauseError } = await supabase
                .from('risk_clauses')
                .insert(clauseData)
                .select()
                .single();

            if (clauseError) {
                console.error("Error inserting risk clause:", clauseError);
                continue;
            }

            // Insert notification if present
            if (clause.notification) {
                const notificationData = {
                    risk_clause_id: riskClause.id,
                    title: clause.notification.title || null,
                    description: clause.notification.description || null,
                    trigger_type: clause.notification.trigger_type || null,
                    start_event: clause.notification.notification_start_event || null,
                    deadline_iso: parseDate(clause.notification.deadline_iso),
                    relative_minutes_offset: clause.notification.relative_minutes_offset
                        ? parseInt(String(clause.notification.relative_minutes_offset))
                        : null,
                    original_clause_excerpt: clause.notification.original_clause || null,
                };

                const { error: notifError } = await supabase
                    .from('clause_notifications')
                    .insert(notificationData);

                if (notifError) {
                    console.error("Error inserting clause notification:", notifError);
                }
            }
        }
        console.log("Risk clauses and notifications inserted successfully");
    }

    // 6. Create user notification about new rate con
    const notificationService = new NotificationService(supabase);

    await notificationService.sendNotification({
        userId: userId || undefined,
        organizationId: organizationId,
        title: "New Rate Confirmation",
        body: `Rate Con ${rateConData.rate_con_id} from ${rateConData.broker_name || 'Unknown Broker'} is ready for review.`,
        data: {
            rate_confirmation_id: rateConfirmationId,
            document_id: documentId,
            traffic_light: rateConData.overall_traffic_light || 'UNKNOWN',
        },
        type: 'rate_con_review'
    });

    console.log("Notification request sent.");

    return rateCon;
}
