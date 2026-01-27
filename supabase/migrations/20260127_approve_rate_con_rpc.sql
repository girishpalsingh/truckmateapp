CREATE OR REPLACE FUNCTION public.approve_rate_con_transaction(
    p_rate_con_id UUID,
    p_edits JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rc_record RECORD;
    v_new_load_id UUID;
    v_load_data JSONB;
BEGIN
    -- 1. Lock the rate confirmation row
    SELECT * INTO v_rc_record
    FROM public.rate_confirmations
    WHERE id = p_rate_con_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rate confirmation not found';
    END IF;

    -- 2. Apply edits if any
    IF p_edits IS NOT NULL THEN
        UPDATE public.rate_confirmations
        SET 
            broker_name = COALESCE((p_edits->>'broker_name')::TEXT, broker_name),
            broker_mc = COALESCE((p_edits->>'broker_mc')::TEXT, broker_mc),
            broker_address = COALESCE((p_edits->>'broker_address')::TEXT, broker_address),
            broker_phone = COALESCE((p_edits->>'broker_phone')::TEXT, broker_phone),
            broker_email = COALESCE((p_edits->>'broker_email')::TEXT, broker_email),
            carrier_name = COALESCE((p_edits->>'carrier_name')::TEXT, carrier_name),
            carrier_dot = COALESCE((p_edits->>'carrier_dot')::TEXT, carrier_dot),
            total_rate = COALESCE((p_edits->>'total_rate')::NUMERIC, total_rate),
            payment_terms = COALESCE((p_edits->>'payment_terms')::TEXT, payment_terms),
            status = 'approved',
            updated_at = NOW()
        WHERE id = p_rate_con_id;
    ELSE
        UPDATE public.rate_confirmations
        SET status = 'approved', updated_at = NOW()
        WHERE id = p_rate_con_id;
    END IF;

    -- Refresh record to get updated values
    SELECT * INTO v_rc_record
    FROM public.rate_confirmations
    WHERE id = p_rate_con_id;

    -- 3. Create Load
    INSERT INTO public.loads (
        organization_id,
        active_rate_con_id,
        broker_name,
        broker_load_id,
        primary_rate,
        total_rate,
        status,
        dispatcher_id,
        created_at,
        updated_at
    ) VALUES (
        v_rc_record.organization_id,
        v_rc_record.rc_id,
        v_rc_record.broker_name,
        v_rc_record.load_id,
        v_rc_record.total_rate,
        v_rc_record.total_rate,
        'created',
        p_user_id,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_new_load_id;

    -- 4. Return result
    RETURN jsonb_build_object(
        'load_id', v_new_load_id,
        'message', 'Rate confirmation approved and Load created'
    );
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;
