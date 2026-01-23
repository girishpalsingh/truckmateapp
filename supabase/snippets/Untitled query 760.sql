CREATE OR REPLACE FUNCTION approve_rate_con_and_create_load(
    rate_con_uuid UUID,
    edits JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rc RECORD;
    new_load_id UUID;
BEGIN
    -- 1. Get the rate confirmation details
    SELECT * INTO rc FROM rate_confirmations WHERE id = rate_con_uuid;
    
    IF rc IS NULL THEN
        RAISE EXCEPTION 'Rate confirmation not found';
    END IF;

    -- 2. Update status to approved
    UPDATE rate_confirmations 
    SET status = 'approved', updated_at = NOW()
    WHERE id = rate_con_uuid;

    -- 3. Create the Load
    INSERT INTO loads (
        organization_id,
        broker_name,
        broker_mc_number,
        broker_load_id,
        primary_rate,
        payment_terms,
        commodity_type,
        weight_lbs,
        status,
        created_at,
        updated_at
    ) VALUES (
        rc.organization_id,
        rc.broker_name,
        rc.broker_mc_number,
        rc.rate_con_id,
        rc.total_rate_amount,  -- FIXED: Changed from total_amount to total_rate_amount
        rc.payment_terms,
        rc.commodity_name,
        rc.commodity_weight,
        'assigned',
        NOW(),
        NOW()
    )
    RETURNING id INTO new_load_id;
    
    RETURN new_load_id;
END;
$$;