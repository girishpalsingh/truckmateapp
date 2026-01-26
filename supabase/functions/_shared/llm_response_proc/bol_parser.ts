import { parseNumeric, parseDate } from '../utils.ts';

/**
 * Maps raw Gemini LLM response to Bill of Lading database object.
 */
export function mapBOLData(documentId: string, extractedData: any, organizationId: string, loadId?: string | null) {
    const parties = extractedData.parties || {};
    const summary = extractedData.freight_summary || {};
    const signatures = extractedData.signatures || {};
    const terms = extractedData.billing_terms || {};

    return {
        // ID is auto-generated in DB
        organization_id: organizationId,
        load_id: loadId || null,

        // Document Identification
        bol_number: extractedData.bol_number || null,
        pro_number: extractedData.references?.pro_number || null,
        document_date: parseDate(extractedData.pickup_date || extractedData.dates?.ship_date),

        // Parties
        shipper_name: parties.shipper?.name || null,
        shipper_address_raw: parties.shipper?.address_raw || null,
        shipper_city: parties.shipper?.city || null,
        shipper_state: parties.shipper?.state || null,
        shipper_zip: parties.shipper?.zip || null,

        consignee_name: parties.consignee?.name || null,
        consignee_address_raw: parties.consignee?.address_raw || null,
        consignee_city: parties.consignee?.city || null,
        consignee_state: parties.consignee?.state || null,
        consignee_zip: parties.consignee?.zip || null,

        bill_to_name: parties.bill_to?.name || null,
        bill_to_address_raw: parties.bill_to?.address_raw || null,

        carrier_name: parties.carrier?.name || null,
        carrier_scac: parties.carrier?.scac || null,

        // Totals & Flags
        total_handling_units: parseNumeric(summary.total_handling_units),
        total_weight_lbs: parseNumeric(summary.total_weight_lbs),
        is_hazmat_detected: summary.is_hazmat_detected || false,
        declared_value: parseNumeric(summary.declared_value),

        // Billing Terms
        payment_terms: terms.payment_method || null,

        // Signatures
        is_shipper_signed: signatures.shipper_signed || false,
        is_carrier_signed: signatures.carrier_signed || false,
        is_receiver_signed: signatures.receiver_signed || false,
        special_notes: signatures.notes || null,
    };
}

/**
 * Maps line items from raw data.
 */
export function mapBOLItems(bolId: string, extractedData: any) {
    if (!extractedData.freight_line_items || !Array.isArray(extractedData.freight_line_items)) {
        return [];
    }

    return extractedData.freight_line_items.map((item: any, index: number) => ({
        bol_id: bolId,
        sequence_number: index + 1,
        description: item.description || null,
        quantity: parseNumeric(item.qty),
        unit_type: item.unit_type || null,
        weight_lbs: parseNumeric(item.weight_lbs),
        nmfc_code: item.nmfc_code || null,
        freight_class: item.freight_class || null,
        is_hazmat: item.is_hazmat || false
    }));
}

/**
 * Maps reference numbers from raw data.
 */
export function mapBOLReferences(bolId: string, extractedData: any) {
    const refs: any[] = [];
    const references = extractedData.references || {};

    if (references.po_numbers && Array.isArray(references.po_numbers)) {
        references.po_numbers.forEach((po: string) => {
            refs.push({ bol_id: bolId, ref_type: 'PO', ref_value: po });
        });
    }

    if (references.seal_numbers && Array.isArray(references.seal_numbers)) {
        references.seal_numbers.forEach((seal: string) => {
            refs.push({ bol_id: bolId, ref_type: 'SEAL', ref_value: seal });
        });
    }

    if (references.customer_reference_numbers && Array.isArray(references.customer_reference_numbers)) {
        references.customer_reference_numbers.forEach((cr: string) => {
            refs.push({ bol_id: bolId, ref_type: 'CUSTOMER_REF', ref_value: cr });
        });
    }

    // Pro number is already in main table but can be added here too if needed, 
    // but usually user just wants indexed search -> bol_references.
    // User requested "load_id ... bol_references ( ref_id PRIMARY KEY, bol_id ... ref_value VARCHAR(100) NOT NULL )"
    // I'll stick to the list fields found in JSON so far.

    return refs;
}

/**
 * Perform validation logic locally or map fields if LLM did it.
 * The prompt does NOT output a validation object like `bol_validations`.
 * It outputs raw data.
 * The logic "Bol validation table should be filled by comparing fields in corresponding rate con and bol"
 * implies we need to fetch the Rate Con data and compare.
 * 
 * Ideally, this comparison logic should happen in the processor, not just mapping.
 * So I will not export a map function for validation here, but handle it in the processor.
 */
