-- Create a stored procedure to handle load assignment safely
-- usage: supabase.rpc('assign_load_to_driver', { ... })

CREATE OR REPLACE FUNCTION public.assign_load_to_driver(
    p_load_id UUID,
    p_organization_id UUID,
    p_driver_id UUID,
    p_truck_id UUID,
    p_trailer_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as owner (postgres, which has BYPASSRLS)
SET search_path = public
AS $$
DECLARE
    v_uploader_id UUID;
    v_user_role public.user_role;
    v_active_rc_id INT;
BEGIN
    -- Get current user role
    SELECT role INTO v_user_role FROM profiles WHERE id = auth.uid();
    
    -- Check if user is allowed (Manager, Dispatcher, OrgAdmin OR Uploader)
    IF v_user_role IN ('owner', 'manager', 'dispatcher', 'orgadmin') THEN
        -- Allow
    ELSE
        -- Helper logic for Driver Uploader
        SELECT active_rate_con_id INTO v_active_rc_id FROM loads WHERE id = p_load_id;
        
        -- If no active RC, deny
        IF v_active_rc_id IS NULL THEN
             RAISE EXCEPTION 'Access Denied: No active rate confirmation found.';
        END IF;

        SELECT created_by INTO v_uploader_id 
        FROM rate_confirmations 
        WHERE rc_id = v_active_rc_id;
        
        IF v_uploader_id IS DISTINCT FROM auth.uid() THEN
            RAISE EXCEPTION 'Access Denied: You are not authorized to assign this load. Only the uploader or a manager can assign it.';
        END IF;
    END IF;

    -- Perform logic: Cancel old active assignments
    UPDATE dispatch_assignments 
    SET status = 'CANCELLED' 
    WHERE load_id = p_load_id AND status = 'ACTIVE';

    -- Insert new assignment
    INSERT INTO dispatch_assignments (
        load_id, organization_id, driver_id, truck_id, trailer_id, status
    ) VALUES (
        p_load_id, p_organization_id, p_driver_id, p_truck_id, p_trailer_id, 'ACTIVE'
    );
    
    -- Update Load status and FKs
    UPDATE loads 
    SET status = 'assigned',
        driver_id = p_driver_id,
        truck_id = p_truck_id,
        trailer_id = p_trailer_id
    WHERE id = p_load_id;
    
END;
$$;
