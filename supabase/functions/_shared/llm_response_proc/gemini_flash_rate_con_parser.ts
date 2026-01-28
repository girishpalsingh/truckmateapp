import { parseNumeric, parseDate } from '../utils.ts';

/**
 * Maps raw Gemini Flash LLM response to Rate Confirmation database object.
 */
export function mapRateConData(documentId: string, extractedData: any, organizationId: string) {
    return {
        // ID is auto-generated SERIAL in DB or UUID default if we used that. 
        // We will let DB handle ID generation on insert if using SERIAL, 
        // OR if using UUID, we can generate here if needed. 
        // The migration script uses SERIAL for rc_id and gen_random_uuid() for id.
        // So we don't pass IDs here unless we want to force them.

        load_id: extractedData.rate_con_id || `LOAD-${Date.now()}`, // Using rate_con_id as load_id per schema intent? Or strictly mapped?
        // Schema says: load_id VARCHAR(50) UNIQUE.
        // extractedData.rate_con_id is likely the Broker's Load ID.

        organization_id: organizationId,
        document_id: documentId,

        // Broker Details
        broker_name: extractedData.broker_details?.broker_name || null,
        broker_mc: extractedData.broker_details?.broker_mc_number || null, // Renamed from broker_mc_number
        broker_address: extractedData.broker_details?.address || null,
        broker_phone: extractedData.broker_details?.phone || null,
        broker_email: extractedData.broker_details?.email || null,

        // Carrier Details
        carrier_name: extractedData.carrier_details?.carrier_name || null,
        carrier_dot: extractedData.carrier_details?.carrier_dot_number || null, // Renamed
        // carrier_equipment_type: extractedData.carrier_details?.equipment_type || null, // Not in new schema explicitly? Check migration.
        // Yes, schema has carrier_equipment_type VARCHAR(100)
        carrier_equipment_type: extractedData.carrier_details?.equipment_type || null,
        carrier_equipment_number: extractedData.carrier_details?.equipment_number || null,

        // Financials
        total_rate: parseNumeric(extractedData.total_rate_amount), // Renamed from total_rate_amount
        currency: 'USD', // Default
        // payment_terms: Not explicitly in Extraction Schema but in DB Schema. 
        // logic: extractedData.financials?.payment_terms || null (if present in LLM response, but prompt might not strict require it)

        // Risk
        risk_score: extractedData.risk_analysis?.overall_traffic_light || 'UNKNOWN', // Renamed from overall_traffic_light

        status: 'under_review',
        // created_by: userId passed safely elsewhere or RLS handles
    };
}

/**
 * Maps reference numbers.
 */
/**
 * Maps reference numbers.
 */
export function mapRcReferences(rateConfirmationUUID: string | null, extractedData: any) {
    if (!extractedData.reference_numbers || !Array.isArray(extractedData.reference_numbers)) {
        return [];
    }

    return extractedData.reference_numbers.map((ref: any) => ({
        rate_confirmation_id: rateConfirmationUUID,
        ref_type: ref.type || null,
        ref_value: ref.value || null,
    }));
}

/**
 * Maps charges.
 */
export function mapRcCharges(rateConfirmationUUID: string | null, extractedData: any) {
    if (!extractedData.charges || !Array.isArray(extractedData.charges)) {
        return [];
    }

    return extractedData.charges.map((charge: any) => ({
        rate_confirmation_id: rateConfirmationUUID,
        description: charge.description || null,
        amount: parseNumeric(charge.amount),
    }));
}

/**
 * Maps stops and their commodities.
 * Returns array of objects, each containing stop data and an array of commodities.
 */
export function mapRcStops(rateConfirmationUUID: string | null, extractedData: any) {
    if (!extractedData.stops || !Array.isArray(extractedData.stops)) {
        return [];
    }

    return extractedData.stops.map((stop: any, index: number) => {
        const stopData = {
            rate_confirmation_id: rateConfirmationUUID,
            stop_sequence: index + 1,
            stop_type: stop.stop_type === 'Pickup' ? 'Pickup' : 'Delivery',

            facility_address: stop.address || null, // Renamed
            contact_name: stop.contact_person || null, // Renamed
            contact_phone: stop.phone || null,
            contact_email: stop.email || null, // Added to DB schema? Check migration. 
            // Migration: contact_email VARCHAR(255)

            raw_date_text: stop.date ? `${stop.date} ${stop.time || ''}`.trim() : null,
            scheduled_arrival: parseDate(stop.scheduled_arrival),
            scheduled_departure: parseDate(stop.scheduled_departure),

            special_instructions: stop.special_instructions || null,
        };

        const commodities = (stop.commodities || []).map((comm: any) => ({
            // stop_id: will be assigned after stop insert
            description: comm.description || null,
            weight_lbs: parseNumeric(comm.weight_lbs),
            quantity: comm.quantity ? parseInt(String(comm.quantity)) : null,
            unit_type: comm.unit_type || null,
            is_hazmat: !!comm.is_hazmat,
            temp_req: comm.temperature_req || null,
        }));

        return { stopData, commodities };
    });
}

/**
 * Maps risk clauses.
 */
export function mapRcRiskClauses(rateConfirmationUUID: string | null, extractedData: any) {
    const clausesFound = extractedData.risk_analysis?.clauses_found || [];

    if (!Array.isArray(clausesFound)) {
        return [];
    }

    return clausesFound.map((clause: any) => {
        const clauseData = {
            rate_confirmation_id: rateConfirmationUUID,
            traffic_light: clause.traffic_light || 'YELLOW',
            clause_type: clause.clause_type || 'Other',

            clause_title: clause.clause_title || null,
            clause_title_punjabi: clause.clause_title_punjabi || null,

            danger_simple_language_english: clause.danger_simple_language_english || null,
            danger_simple_language_punjabi: clause.danger_simple_language_punjabi || null,

            original_text: clause.original_text || null,
        };

        let notificationData = null;
        if (clause.notification) {
            notificationData = {
                // clause_id: assigned after insert
                title: clause.notification.title || null,
                description: clause.notification.description || null,
                trigger_type: clause.notification.trigger_type || null,
                start_event: clause.notification.notification_start_event || null,
                deadline_date: parseDate(clause.notification.deadline_iso), // DB DATE type
                relative_offset_minutes: clause.notification.relative_minutes_offset
                    ? parseInt(String(clause.notification.relative_minutes_offset))
                    : null,
            };
        }

        return { clauseData, notificationData };
    });
}

/**
 * Maps Dispatch Instructions.
 */
export function mapRcDispatchInstructions(rateConfirmationUUID: string | null, extractedData: any) {
    const dd = extractedData.driver_dispatch_view || {};

    // DB Schema has 1 row per RC for this table, with JSONB arrays.

    const transit_reqs_en = dd.transit_requirements_en || [];
    const transit_reqs_punjabi = dd.transit_requirements_punjabi || [];
    // special_equipment_needed is not in Extraction Schema 'driver_dispatch_view' sample in prompt?
    // Wait, prompt has explicit lists: "transit_requirements_en", etc.
    // Check prompt again: "special_equipment_needed_english", "special_equipment_needed_punjabi".
    const special_equip_en = dd.special_equipment_needed_english || [];
    const special_equip_punjabi = dd.special_equipment_needed_punjabi || [];

    const action_items = dd.driver_dispatch_instructions || [];

    return {
        rate_confirmation_id: rateConfirmationUUID,
        pickup_summary: dd.pickup_instructions || null,
        delivery_summary: dd.delivery_instructions || null,
        transit_reqs_en,
        transit_reqs_punjabi,
        special_equip_en,
        special_equip_punjabi,
        action_items
    };
}
