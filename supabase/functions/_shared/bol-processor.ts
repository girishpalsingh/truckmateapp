import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
    mapBOLData,
    mapBOLItems,
    mapBOLReferences
} from './llm_response_proc/bol_parser.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

export async function processBillOfLading(
    documentId: string,
    extractedData: any,
    organizationId: string,
    loadId?: string | null
) {
    console.log(`Processing BOL for Doc ID: ${documentId}, Load: ${loadId}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Insert into bill_of_ladings
    const bolData = mapBOLData(documentId, extractedData, organizationId, loadId);

    // Inject the parsed BOL number back into the return if needed, currently just inserting.

    const { data: bol, error: bolError } = await supabase
        .from('bill_of_ladings')
        .insert(bolData)
        .select()
        .single();

    if (bolError) {
        console.error("Error inserting bill_of_ladings:", bolError);
        throw new Error(`Failed to insert BOL: ${bolError.message}`);
    }

    const bolId = bol.id;
    console.log("BOL inserted:", bolId);

    // 2. Insert Line Items
    const items = mapBOLItems(bolId, extractedData);
    if (items.length > 0) {
        const { error: itemsError } = await supabase.from('bol_line_items').insert(items);
        if (itemsError) console.error("Error inserting BOL items:", itemsError);
    }

    // 3. Insert References
    const refs = mapBOLReferences(bolId, extractedData);
    if (refs.length > 0) {
        const { error: refsError } = await supabase.from('bol_references').insert(refs);
        if (refsError) console.error("Error inserting BOL refs:", refsError);
    }

    // 4. Validation (if Load ID exists)
    if (loadId) {
        await validateBOL(supabase, bolId, loadId, bol, extractedData);
    }

    return bol;
}

async function validateBOL(supabase: any, bolId: string, loadId: string, bol: any, extractedData: any) {
    console.log(`Validating BOL ${bolId} against Load ${loadId}...`);

    // Fetch Load Data
    const { data: load, error: loadError } = await supabase
        .from('loads')
        .select('*')
        .eq('id', loadId)
        .single();

    if (loadError || !load) {
        console.error("Failed to fetch load for validation:", loadError);
        return;
    }

    // Perform Comparisons
    const reasons: string[] = [];
    let locationScore = 100; // Start perfect
    let scoreDeduction = 0;

    // 1. Location Match (Shipper City/State vs Pickup, Consignee City/State vs Delivery)
    // Load has pickup_address (JSONB) and delivery_address (JSONB)
    // Structure: { city, state, address, ... } or similar standard address object

    const pickup = load.pickup_address || {};
    const delivery = load.delivery_address || {};

    const bolShipperCity = (bol.shipper_city || "").toLowerCase();
    const bolShipperState = (bol.shipper_state || "").toLowerCase();
    // Helper to extract city/state safely from JSONB which might be object or string or null
    const getAddressPart = (addr: any, part: 'city' | 'state') => {
        if (!addr) return "";
        if (typeof addr === 'string') {
            // Very basic parsing or just return empty if we can't be sure
            // If it's a string, we might not be able to validate city match easily without parsing.
            // For now, assume if it's a string, we assume match or skip this specific check.
            return "";
        }
        return (addr[part] || "").toLowerCase();
    };

    const loadPickupCity = getAddressPart(pickup, 'city');
    const loadPickupState = getAddressPart(pickup, 'state');

    // Only compare if we successfully extracted city/state from Load
    if (bolShipperCity && loadPickupCity && bolShipperCity !== loadPickupCity) {
        scoreDeduction += 25;
        reasons.push(`Pickup City Mismatch: ${bol.shipper_city} vs ${loadPickupCity}`);
    }
    if (bolShipperState && loadPickupState && bolShipperState !== loadPickupState) {
        scoreDeduction += 25;
        reasons.push(`Pickup State Mismatch`);
    }

    const bolConsigneeCity = (bol.consignee_city || "").toLowerCase();
    const bolConsigneeState = (bol.consignee_state || "").toLowerCase();

    const loadDeliveryCity = getAddressPart(delivery, 'city');
    const loadDeliveryState = getAddressPart(delivery, 'state');

    if (bolConsigneeCity && loadDeliveryCity && bolConsigneeCity !== loadDeliveryCity) {
        scoreDeduction += 25;
        reasons.push(`Delivery City Mismatch: ${bol.consignee_city} vs ${loadDeliveryCity}`);
    }
    if (bolConsigneeState && loadDeliveryState && bolConsigneeState !== loadDeliveryState) {
        scoreDeduction += 25;
        reasons.push(`Delivery State Mismatch`);
    }

    locationScore = Math.max(0, 100 - scoreDeduction);


    // 2. Weight Variance
    const loadWeight = Number(load.weight_lbs || 0);
    const bolWeight = Number(bol.total_weight_lbs || 0);
    let weightVariancePct = 0;

    if (loadWeight > 0 && bolWeight > 0) {
        const diff = Math.abs(loadWeight - bolWeight);
        weightVariancePct = (diff / loadWeight) * 100;

        if (weightVariancePct > 10) { // >10% variance is warning
            reasons.push(`Weight Variance ${weightVariancePct.toFixed(1)}%`);
        }
    }

    // 3. Hazmat Mismatch
    // Load might not have hazmat flag directly? 
    // Usually defined in commodity_type or notes, or stored in specific hazmat column if exists.
    // The `loads` table doesn't have `is_hazmat` column in schema I saw.
    // Assuming for now we check if load says "HAZMAT" in notes or commodity.
    // Or simpler: If BOL says Hazmat but we don't expect it (default no).
    // Or assume passed validation if load doesn't specify.
    // But user requirement: "has_hazmat_mismatch BOOLEAN, -- RateCon=No, BOL=Yes (CRITICAL)"
    // Since we don't have explicit RateCon data linked here easily (unless we fetch RateCon via Load), 
    // we can check if Load Notes mention Hazmat.
    // If not, and BOL is hazmat -> Mismatch.
    const loadHasHazmat = (JSON.stringify(load).toLowerCase().includes('hazmat'));
    const bolHasHazmat = bol.is_hazmat_detected || false;
    const hasHazmatMismatch = (bolHasHazmat && !loadHasHazmat);

    if (hasHazmatMismatch) reasons.push("CRITICAL: Hazmat detected on BOL but not on Load");

    // 4. PO Number Mismatch
    // User: "has_po_mismatch BOOLEAN, -- RateCon PO missing from BOL"
    // Load usually stores broker_load_id (Load #) but Rate Con might have PO.
    // We extracted POs from BOL into `bol_references`.
    // We need to compare with expected POs. 
    // Where are expected POs? In `loads.broker_load_id`? Or `rate_confirmations`?
    // Let's assume `broker_load_id` is the main reference we have on Load.
    // Use `bol_number` and `bol_references` to check against `broker_load_id`.

    let hasPoMismatch = false;
    // Implementation: If Load has a broker ID, is it in BOL refs or BOL number?
    const expectedRef = load.broker_load_id;
    if (expectedRef) {
        const refs = mapBOLReferences(bolId, extractedData);
        const refValues = refs.map(r => r.ref_value);
        const allBolRefs = [bol.bol_number, bol.pro_number, ...refValues].filter(Boolean);

        // Loose check
        const match = allBolRefs.some(r => r?.includes(expectedRef) || expectedRef.includes(r));
        if (!match) {
            hasPoMismatch = true; // or just warning
            reasons.push(`Missing Reference: ${expectedRef}`);
        }
    }

    // 5. Determine Status
    let status = 'PASSED';
    if (hasHazmatMismatch) status = 'FAILED';
    else if (locationScore < 80 || weightVariancePct > 10 || hasPoMismatch) status = 'WARNING';
    else if (reasons.length > 0) status = 'WARNING'; // Any other reasons?

    // Insert Validation Record
    const validationData = {
        load_id: loadId,
        bol_id: bolId,
        location_match_score: locationScore,
        weight_variance_pct: weightVariancePct,
        has_hazmat_mismatch: hasHazmatMismatch,
        has_po_mismatch: hasPoMismatch,
        validation_status: status,
        failure_reasons: reasons
    };

    const { error: valError } = await supabase.from('bol_validations').insert(validationData);
    if (valError) console.error("Error inserting BOL validation:", valError);
    else console.log("BOL Validation completed:", status);
}
