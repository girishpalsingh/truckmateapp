import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { NotificationService } from './notification-service.ts';
import {
    mapRateConData,
    mapRcReferences,
    mapRcStops,
    mapRcCharges,
    mapRcRiskClauses,
    mapRcDispatchInstructions
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
    userId: string | null
) {
    console.log(`Processing Rate Con for Doc ID: ${documentId}, Org: ${organizationId}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into rate_confirmations (main table)
    const rateConData = mapRateConData(documentId, extractedData, organizationId);
    if (userId) {
        (rateConData as any).created_by = userId;
    }

    // DEVELOPMENT ONLY: Duplicate Load ID fix
    // Append timestamp to load_id to allow re-uploading same document for testing
    if ((rateConData as any).load_id) {
        (rateConData as any).load_id = `${(rateConData as any).load_id}-${Date.now()}`;
    }

    console.log("Inserting Rate Confirmation Data...");

    // Using .select() to get 'id' (UUID) and other fields
    const { data: rateCon, error: rateConError } = await supabase
        .from('rate_confirmations')
        .insert(rateConData)
        .select('id, load_id, broker_name, risk_score')
        .single();

    if (rateConError) {
        console.error("Error inserting rate_confirmations:", rateConError);
        throw new Error(`Failed to insert rate confirmation: ${rateConError.message}`);
    }

    console.log(`Rate Confirmation inserted. ID: ${rateCon.id}`);

    const rateConfirmationUUID = rateCon.id; // UUID Key

    // 2. Insert RC References
    const refNumbersData = mapRcReferences(rateConfirmationUUID, extractedData);
    if (refNumbersData.length > 0) {
        console.log(`Inserting ${refNumbersData.length} reference numbers...`);
        const { error: refError } = await supabase
            .from('rc_references') // New Table
            .insert(refNumbersData);

        if (refError) console.error("Error inserting rc_references:", refError);
    }

    // 3. Insert RC Stops & Commodities
    const stopsWithCommodities = mapRcStops(rateConfirmationUUID, extractedData);
    if (stopsWithCommodities.length > 0) {
        console.log(`Inserting ${stopsWithCommodities.length} stops...`);

        // We must insert stops one by one to get their IDs for commodities
        // Or we can try bulk insert if we don't need immediate commodity link, but we do.

        for (const { stopData, commodities } of stopsWithCommodities) {
            const { data: insertedStop, error: stopError } = await supabase
                .from('rc_stops') // New Table
                .insert(stopData)
                .select('stop_id')
                .single();

            if (stopError) {
                console.error("Error inserting rc_stops:", stopError);
                continue;
            }

            if (commodities.length > 0 && insertedStop) {
                const commoditiesData = commodities.map((c: any) => ({
                    ...c,
                    stop_id: insertedStop.stop_id
                }));

                const { error: commError } = await supabase
                    .from('rc_commodities') // New Table
                    .insert(commoditiesData);

                if (commError) console.error("Error inserting rc_commodities:", commError);
            }
        }
    }

    // 4. Insert RC Charges
    const chargesData = mapRcCharges(rateConfirmationUUID, extractedData);
    if (chargesData.length > 0) {
        console.log(`Inserting ${chargesData.length} charges...`);
        const { error: chargesError } = await supabase
            .from('rc_charges') // New Table
            .insert(chargesData);

        if (chargesError) console.error("Error inserting rc_charges:", chargesError);
    }

    // 5. Insert RC Risk Clauses and their Notifications
    const clausesToInsert = mapRcRiskClauses(rateConfirmationUUID, extractedData);
    if (clausesToInsert.length > 0) {
        console.log(`Inserting ${clausesToInsert.length} risk clauses...`);

        for (const { clauseData, notificationData } of clausesToInsert) {
            // Insert risk clause
            const { data: riskClause, error: clauseError } = await supabase
                .from('rc_risk_clauses') // New Table
                .insert(clauseData)
                .select('clause_id')
                .single();

            if (clauseError) {
                console.error("Error inserting rc_risk_clauses:", clauseError);
                continue;
            }

            // Insert notification if present
            if (notificationData && riskClause) {
                const notifInsertData = {
                    ...notificationData,
                    clause_id: riskClause.clause_id
                };

                const { error: notifError } = await supabase
                    .from('rc_notifications') // New Table
                    .insert(notifInsertData);

                if (notifError) {
                    console.error("Error inserting rc_notifications:", notifError);
                }
            }
        }
    }

    // 6. Insert RC Dispatch Instructions (Single Row usually)
    const dispatchInstructions = mapRcDispatchInstructions(rateConfirmationUUID, extractedData);
    // Check if it has any data to insert (at least one field non-empty)
    const hasData = Object.values(dispatchInstructions).some(val =>
        val !== rateConfirmationUUID && val !== null && (Array.isArray(val) ? val.length > 0 : true)
    );

    if (hasData) {
        console.log(`Inserting dispatch instructions...`);
        const { error: instructionsError } = await supabase
            .from('rc_dispatch_instructions') // New Table
            .insert(dispatchInstructions);

        if (instructionsError) {
            console.error("Error inserting rc_dispatch_instructions:", instructionsError);
        }
    }

    // 7. Create user notification about new rate con
    const notificationService = new NotificationService(supabase);

    let targetUserId = userId;
    if (!targetUserId) {
        // Fallback: Fetch Organization Owner/Admin if no specific user is associated
        const { data: orgData, error: orgError } = await supabase
            .from('organizations')
            .select('admin_id')
            .eq('id', organizationId)
            .single();

        if (!orgError && orgData?.admin_id) {
            targetUserId = orgData.admin_id;
        } else {
            console.warn(`No userId provided and failed to fetch Org Admin for ${organizationId}. Notification might fail.`);
        }
    }

    if (targetUserId) {
        await notificationService.sendNotification({
            userId: targetUserId,
            organizationId: organizationId,
            title: "New Rate Confirmation",
            body: `Rate Con ${rateCon.load_id} from ${rateCon.broker_name || 'Unknown Broker'} is ready for review.`,
            data: {
                rate_confirmation_id: rateConfirmationUUID,
                document_id: documentId,
                traffic_light: rateCon.risk_score || 'UNKNOWN',
            },
            type: 'rate_con_review'
        });
        console.log("Notification request sent.");
    } else {
        console.error("Skipping notification: No valid userId found.");
    }

    return rateCon;
}
