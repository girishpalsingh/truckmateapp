-- Function to approve a rate confirmation and automatically create a corresponding load
-- Returns the ID of the newly created load

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
    pickup_addr JSONB;
    delivery_addr JSONB;
BEGIN
    -- 1. Get the rate confirmation details
    SELECT * INTO rc FROM rate_confirmations WHERE id = rate_con_uuid;
    
    IF rc IS NULL THEN
        RAISE EXCEPTION 'Rate confirmation not found';
    END IF;

    -- 2. Update status to approved (and apply any pending edits if needed - simplistic approach here)
    -- In a real scenario, we might want to apply the edits JSONB to the rc record first.
    -- For now, we assume the client handles individual edits before approval or we just mark approved.
    
    UPDATE rate_confirmations 
    SET status = 'approved', updated_at = NOW()
    WHERE id = rate_con_uuid;

    -- 3. Create the Load
    -- Extract simple address info (first pickup, last delivery) if stops exist
     -- This logic is simplified; improved logic would query the 'stops' table.
     -- We'll leave address fields null or minimal for now and rely on the UI/Trip to populate details.
    
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
        rc.rate_con_id, -- Using the visible ID as the broker load ref
        rc.total_amount,
        rc.payment_terms,
        rc.commodity_name,
        rc.commodity_weight,
        'assigned',
        NOW(),
        NOW()
    )
    RETURNING id INTO new_load_id;
    
    -- 4. Link the rate confirmation to the load? 
    -- The schema doesn't have a 'load_id' on rate_confirmations or vice versa.
    -- It might be good to add one, but we can return the ID for the trip to use.
    
    RETURN new_load_id;
END;
$$;
