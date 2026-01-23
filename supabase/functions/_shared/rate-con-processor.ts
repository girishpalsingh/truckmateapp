import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { NotificationService } from './notification-service.ts';
import {
    mapRateConData,
    mapReferenceNumbers,
    mapStops,
    mapCharges,
    mapRiskClauses,
    mapDispatchInstructions
} from './llm_response_proc/gemini_flash_rate_con_parser.ts';

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
    // console.log('Extracted Data:', JSON.stringify(extractedData, null, 2));

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into rate_confirmations (main table)
    const rateConData = mapRateConData(documentId, extractedData, organizationId);
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
    const refNumbersData = mapReferenceNumbers(rateConfirmationId, extractedData);
    if (refNumbersData.length > 0) {
        console.log(`Inserting ${refNumbersData.length} reference numbers...`);
        const { error: refError } = await supabase
            .from('reference_numbers')
            .insert(refNumbersData);

        if (refError) console.error("Error inserting reference_numbers:", refError);
    }

    // 3. Insert Stops
    const stopsData = mapStops(rateConfirmationId, extractedData);
    if (stopsData.length > 0) {
        console.log(`Inserting ${stopsData.length} stops...`);
        const { error: stopsError } = await supabase
            .from('stops')
            .insert(stopsData);

        if (stopsError) console.error("Error inserting stops:", stopsError);
    }

    // 4. Insert Charges
    const chargesData = mapCharges(rateConfirmationId, extractedData);
    if (chargesData.length > 0) {
        console.log(`Inserting ${chargesData.length} charges...`);
        const { error: chargesError } = await supabase
            .from('charges')
            .insert(chargesData);

        if (chargesError) console.error("Error inserting charges:", chargesError);
    }

    // 5. Insert Risk Clauses and their Notifications
    const clausesToInsert = mapRiskClauses(rateConfirmationId, extractedData);
    if (clausesToInsert.length > 0) {
        console.log(`Inserting ${clausesToInsert.length} risk clauses...`);

        for (const { clauseData, notificationData } of clausesToInsert) {
            // Insert risk clause
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
            if (notificationData) {
                const notifInsertData = {
                    ...notificationData,
                    risk_clause_id: riskClause.id
                };

                const { error: notifError } = await supabase
                    .from('clause_notifications')
                    .insert(notifInsertData);

                if (notifError) {
                    console.error("Error inserting clause notification:", notifError);
                }
            }
        }
        console.log("Risk clauses and notifications inserted successfully");
    }

    // 7. Insert Dispatch Instructions
    const dispatchInstructions = mapDispatchInstructions(rateConfirmationId, extractedData, organizationId);
    if (dispatchInstructions.length > 0) {
        console.log(`Inserting ${dispatchInstructions.length} dispatch instructions...`);
        const { error: instructionsError } = await supabase
            .from('rate_con_dispatcher_instructions')
            .insert(dispatchInstructions);

        if (instructionsError) {
            console.error("Error inserting dispatch instructions:", instructionsError);
        } else {
            console.log("Dispatch instructions inserted successfully");
        }
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
