import { parseNumeric, parseDate } from '../utils.ts';

/**
 * Maps raw Gemini Flash LLM response to Rate Confirmation database object.
 */
export function mapRateConData(documentId: string, extractedData: any, organizationId: string) {
    return {
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
}

/**
 * Maps reference numbers from raw data.
 */
export function mapReferenceNumbers(rateConfirmationId: string, extractedData: any) {
    if (!extractedData.reference_numbers || !Array.isArray(extractedData.reference_numbers)) {
        return [];
    }

    return extractedData.reference_numbers.map((ref: any) => ({
        rate_confirmation_id: rateConfirmationId,
        ref_type: ref.type || null,
        ref_value: ref.value || null,
    }));
}

/**
 * Maps stops from raw data.
 */
export function mapStops(rateConfirmationId: string, extractedData: any) {
    if (!extractedData.stops || !Array.isArray(extractedData.stops)) {
        return [];
    }

    return extractedData.stops.map((stop: any, index: number) => ({
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
}

/**
 * Maps charges from raw data.
 */
export function mapCharges(rateConfirmationId: string, extractedData: any) {
    if (!extractedData.financials?.charges || !Array.isArray(extractedData.financials.charges)) {
        return [];
    }

    return extractedData.financials.charges.map((charge: any) => ({
        rate_confirmation_id: rateConfirmationId,
        description: charge.description || null,
        amount: parseNumeric(charge.amount),
    }));
}

/**
 * Maps risk clauses from raw data.
 * Returns an array of objects containing the clause data and its optional notification data.
 */
export function mapRiskClauses(rateConfirmationId: string, extractedData: any) {
    const clausesFound = extractedData.risk_analysis?.clauses_found || extractedData.clauses_found || extractedData.bad_clauses_found;

    if (!clausesFound || !Array.isArray(clausesFound)) {
        return [];
    }

    return clausesFound.map((clause: any) => {
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

        let notificationData = null;
        if (clause.notification) {
            notificationData = {
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
        }


        return { clauseData, notificationData };
    });
}

/**
 * Maps driver dispatch instructions from raw data.
 */
export function mapDispatchInstructions(rateConfirmationId: string, extractedData: any, organizationId: string) {
    if (!extractedData.driver_dispatch_instructions || !Array.isArray(extractedData.driver_dispatch_instructions)) {
        return [];
    }

    return extractedData.driver_dispatch_instructions.map((instruction: any) => ({
        rate_confirmation_id: rateConfirmationId,
        organization_id: organizationId,
        title_en: instruction.title_en || null,
        title_punjab: instruction.title_punjab || null,
        description_en: instruction.description_en || null,
        description_punjab: instruction.description_punjab || null,
        trigger_type: instruction.trigger_type || null,
        deadline_iso: parseDate(instruction.deadline_iso),
        relative_minutes_offset: parseNumeric(instruction.relative_minutes_offset),
        original_clause: instruction.original_clause || null,
    }));
}
